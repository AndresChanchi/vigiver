// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";

import {
    IQorePqcKeyStatusPrecompile
} from "../../../../src/cryptography/qorechain/interfaces/IQorePqcKeyStatusPrecompile.sol";

import {QorePqcKeyRegistry} from "../../../../src/cryptography/qorechain/QorePqcKeyRegistry.sol";

import {
    QorePqcKeyRegistryHarness
} from "../../../helpers/cryptography/qorechain/QorePqcKeyRegistryHarness.sol";

contract QorePqcKeyRegistryTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant PQC_KEY_STATUS_PRECOMPILE = address(0x0A02);

    address private constant AUTHORITY = address(0xA11CE);
    address private constant OTHER_AUTHORITY = address(0xB0B);

    uint256 private constant PUBLIC_KEY_LENGTH = 2592;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    QorePqcKeyRegistryHarness private s_registry;
    bytes private s_publicKey;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        s_registry = new QorePqcKeyRegistryHarness();

        // Synthetic key material tests the registry boundary.
        // It does not establish cryptographic key validity.
        s_publicKey = new bytes(PUBLIC_KEY_LENGTH);
        s_publicKey[0] = 0x01;
        s_publicKey[PUBLIC_KEY_LENGTH - 1] = 0x02;

        // Unexpected calls return empty data.
        vm.etch(PQC_KEY_STATUS_PRECOMPILE, hex"60006000f3");
    }

    /*//////////////////////////////////////////////////////////////
                           ACCOUNT STATUS
    //////////////////////////////////////////////////////////////*/

    function testReturnsUnregisteredStatus() public {
        _mockResponse(abi.encode(false, uint8(0), new bytes(0), false));

        QorePqcKeyRegistry.KeyStatus memory status = s_registry.getStatus(AUTHORITY);

        assertFalse(status.registered);
        assertEq(status.algorithmId, 0);
        assertEq(status.publicKey.length, 0);
        assertFalse(status.possessionProven);
    }

    function testReturnsLegacyRegistrationWithoutPossession() public {
        _mockRegisteredKey(false);

        QorePqcKeyRegistry.KeyStatus memory status = s_registry.getStatus(AUTHORITY);

        assertTrue(status.registered);
        assertEq(status.algorithmId, 1);
        assertEq(status.publicKey, s_publicKey);
        assertFalse(status.possessionProven);
    }

    function testReturnsRegistrationWithProvenPossession() public {
        _mockRegisteredKey(true);

        vm.expectCall(PQC_KEY_STATUS_PRECOMPILE, _statusCalldata(AUTHORITY));

        QorePqcKeyRegistry.KeyStatus memory status = s_registry.getStatus(AUTHORITY);

        assertTrue(status.registered);
        assertEq(status.algorithmId, 1);
        assertEq(status.publicKey, s_publicKey);
        assertTrue(status.possessionProven);
    }

    function testQueriesTheExactRequestedAuthority() public {
        bytes memory otherPublicKey = new bytes(PUBLIC_KEY_LENGTH);
        otherPublicKey[0] = 0xAB;

        _mockRegisteredKey(true);

        vm.mockCall(
            PQC_KEY_STATUS_PRECOMPILE,
            _statusCalldata(OTHER_AUTHORITY),
            abi.encode(true, uint8(1), otherPublicKey, true)
        );

        QorePqcKeyRegistry.KeyStatus memory first = s_registry.getStatus(AUTHORITY);

        QorePqcKeyRegistry.KeyStatus memory second = s_registry.getStatus(OTHER_AUTHORITY);

        assertEq(first.publicKey, s_publicKey);
        assertEq(second.publicKey, otherPublicKey);
        assertTrue(sha256(first.publicKey) != sha256(second.publicKey));
    }

    function testRejectsZeroAuthority() public {
        vm.mockCallRevert(
            PQC_KEY_STATUS_PRECOMPILE,
            abi.encodePacked(IQorePqcKeyStatusPrecompile.pqcKeyStatus.selector),
            hex""
        );

        vm.expectRevert(QorePqcKeyRegistry.InvalidAuthority.selector);

        s_registry.getStatus(address(0));
    }

    /*//////////////////////////////////////////////////////////////
                           KEY ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    function testReturnsEligibleKeyAndCommitment() public {
        _mockRegisteredKey(true);

        (bytes memory publicKey, bytes32 keyHash) = s_registry.requireEligibleKey(AUTHORITY);

        assertEq(publicKey, s_publicKey);
        assertEq(keyHash, sha256(s_publicKey));
    }

    function testRejectsUnregisteredAuthority() public {
        _mockResponse(abi.encode(false, uint8(0), new bytes(0), false));

        vm.expectRevert(QorePqcKeyRegistry.KeyNotRegistered.selector);

        s_registry.requireEligibleKey(AUTHORITY);
    }

    function testRejectsAuthorityWithoutProvenPossession() public {
        _mockRegisteredKey(false);

        vm.expectRevert(QorePqcKeyRegistry.PossessionNotProven.selector);

        s_registry.requireEligibleKey(AUTHORITY);
    }

    function testReturnsMatchingRegisteredKey() public {
        _mockRegisteredKey(true);

        bytes memory publicKey = s_registry.requireMatchingKey(AUTHORITY, sha256(s_publicKey));

        assertEq(publicKey, s_publicKey);
    }

    function testRejectsSubstitutedKeyCommitment() public {
        _mockRegisteredKey(true);

        bytes memory otherPublicKey = new bytes(PUBLIC_KEY_LENGTH);
        otherPublicKey[0] = 0xFF;

        bytes32 expected = sha256(otherPublicKey);
        bytes32 actual = sha256(s_publicKey);

        vm.expectRevert(
            abi.encodeWithSelector(
                QorePqcKeyRegistry.KeyCommitmentMismatch.selector, expected, actual
            )
        );

        s_registry.requireMatchingKey(AUTHORITY, expected);
    }

    function testMatchingCommitmentCannotBypassPossession() public {
        _mockRegisteredKey(false);

        bytes32 expectedKeyHash = sha256(s_publicKey);

        vm.expectRevert(QorePqcKeyRegistry.PossessionNotProven.selector);

        s_registry.requireMatchingKey(AUTHORITY, expectedKeyHash);
    }

    function testMatchingCommitmentCannotBypassRegistration() public {
        _mockResponse(abi.encode(false, uint8(0), new bytes(0), false));

        bytes32 expectedKeyHash = sha256(new bytes(0));

        vm.expectRevert(QorePqcKeyRegistry.KeyNotRegistered.selector);

        s_registry.requireMatchingKey(AUTHORITY, expectedKeyHash);
    }

    /*//////////////////////////////////////////////////////////////
                        ALGORITHM VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testRejectsUnsupportedAlgorithm() public {
        _mockResponse(abi.encode(true, uint8(2), s_publicKey, true));

        vm.expectRevert(
            abi.encodeWithSelector(QorePqcKeyRegistry.UnsupportedAlgorithm.selector, uint256(2))
        );

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsRegisteredZeroAlgorithm() public {
        _mockResponse(abi.encode(true, uint8(0), s_publicKey, true));

        vm.expectRevert(
            abi.encodeWithSelector(QorePqcKeyRegistry.UnsupportedAlgorithm.selector, uint256(0))
        );

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsAlgorithmExceedingUint8() public {
        _mockResponse(_rawResponse(1, 256, 128, 1, PUBLIC_KEY_LENGTH));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    /*//////////////////////////////////////////////////////////////
                      CANONICAL ABI VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testRejectsNonCanonicalRegisteredFlag() public {
        _mockResponse(_rawResponse(2, 1, 128, 1, PUBLIC_KEY_LENGTH));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsNonCanonicalPossessionFlag() public {
        _mockResponse(_rawResponse(1, 1, 128, 2, PUBLIC_KEY_LENGTH));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsIncorrectDynamicOffset() public {
        _mockResponse(_rawResponse(1, 1, 160, 1, PUBLIC_KEY_LENGTH));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsDynamicOffsetOverflow() public {
        _mockResponse(_rawResponse(1, 1, type(uint256).max, 1, PUBLIC_KEY_LENGTH));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsIncorrectDeclaredKeyLength() public {
        _mockResponse(_rawResponse(1, 1, 128, 1, PUBLIC_KEY_LENGTH - 1));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsDeclaredKeyLengthOverflow() public {
        _mockResponse(_rawResponse(1, 1, 128, 1, type(uint256).max));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsShortRegisteredKey() public {
        _mockResponse(abi.encode(true, uint8(1), new bytes(PUBLIC_KEY_LENGTH - 1), true));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsOversizedRegisteredKey() public {
        _mockResponse(abi.encode(true, uint8(1), new bytes(PUBLIC_KEY_LENGTH + 1), true));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsRegisteredEmptyKey() public {
        _mockResponse(abi.encode(true, uint8(1), new bytes(0), true));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsTrailingResponseData() public {
        _mockResponse(bytes.concat(abi.encode(true, uint8(1), s_publicKey, true), hex"00"));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    /*//////////////////////////////////////////////////////////////
                         STATE CONSISTENCY
    //////////////////////////////////////////////////////////////*/

    function testRejectsUnregisteredAccountWithAlgorithm() public {
        _mockResponse(abi.encode(false, uint8(1), new bytes(0), false));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsUnregisteredAccountWithPublicKey() public {
        _mockResponse(abi.encode(false, uint8(0), s_publicKey, false));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRejectsUnregisteredAccountWithPossession() public {
        _mockResponse(abi.encode(false, uint8(0), new bytes(0), true));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    /*//////////////////////////////////////////////////////////////
                       INFRASTRUCTURE FAILURES
    //////////////////////////////////////////////////////////////*/

    function testRevertsOnFailedPrecompileCall() public {
        vm.mockCallRevert(PQC_KEY_STATUS_PRECOMPILE, _statusCalldata(AUTHORITY), hex"");

        vm.expectRevert(QorePqcKeyRegistry.PqcKeyStatusCallFailed.selector);

        s_registry.getStatus(AUTHORITY);
    }

    function testRevertsOnEmptyResponse() public {
        _mockResponse(hex"");

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRevertsOnTruncatedResponse() public {
        _mockResponse(new bytes(159));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testRevertsWhenPrecompileIsUnavailable() public {
        vm.etch(PQC_KEY_STATUS_PRECOMPILE, hex"");

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _statusCalldata(address authority) internal pure returns (bytes memory) {
        return abi.encodeWithSignature("pqcKeyStatus(address)", authority);
    }

    function _mockResponse(bytes memory response) internal {
        vm.mockCall(PQC_KEY_STATUS_PRECOMPILE, _statusCalldata(AUTHORITY), response);
    }

    function _mockRegisteredKey(bool possessionProven) internal {
        _mockResponse(abi.encode(true, uint8(1), s_publicKey, possessionProven));
    }

    function _rawResponse(
        uint256 registered,
        uint256 algorithmId,
        uint256 offset,
        uint256 possessionProven,
        uint256 declaredLength
    ) internal view returns (bytes memory) {
        return bytes.concat(
            abi.encode(registered, algorithmId, offset, possessionProven, declaredLength),
            s_publicKey
        );
    }

    function _expectInvalidResponse() internal {
        vm.expectRevert(QorePqcKeyRegistry.InvalidPqcKeyStatusResponse.selector);
    }
}
