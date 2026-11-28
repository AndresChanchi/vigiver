// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";

import {QorePqcKeyRegistry} from "../../../../src/cryptography/qorechain/QorePqcKeyRegistry.sol";

import {
    QorePqcKeyRegistryHarness
} from "../../../helpers/cryptography/qorechain/QorePqcKeyRegistryHarness.sol";

import {
    QorePqcKeyRegistryCreationProbe
} from "../../../helpers/cryptography/qorechain/QorePqcKeyRegistryCreationProbe.sol";

contract QorePqcKeyRegistryFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant PQC_KEY_STATUS_PRECOMPILE = address(0x0A02);

    address private constant AUTHORITY = address(0xA11CE);

    uint256 private constant PUBLIC_KEY_LENGTH = 2592;
    uint256 private constant EMPTY_RESPONSE_LENGTH = 160;
    uint256 private constant REGISTERED_RESPONSE_LENGTH = 2752;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    QorePqcKeyRegistryHarness private s_registry;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        s_registry = new QorePqcKeyRegistryHarness();

        vm.etch(PQC_KEY_STATUS_PRECOMPILE, hex"60006000f3");
    }

    /*//////////////////////////////////////////////////////////////
                           VALID RESPONSES
    //////////////////////////////////////////////////////////////*/

    function testFuzzPreservesRegisteredStatus(
        address authority,
        bytes32 seed,
        bool possessionProven
    ) public {
        vm.assume(authority != address(0));

        bytes memory publicKey = _syntheticKey(seed);

        _mockResponse(authority, abi.encode(true, uint8(1), publicKey, possessionProven));

        QorePqcKeyRegistry.KeyStatus memory status = s_registry.getStatus(authority);

        assertTrue(status.registered);
        assertEq(status.algorithmId, 1);
        assertEq(status.publicKey, publicKey);
        assertEq(status.possessionProven, possessionProven);

        if (possessionProven) {
            (bytes memory eligibleKey, bytes32 keyHash) = s_registry.requireEligibleKey(authority);

            assertEq(eligibleKey, publicKey);
            assertEq(keyHash, sha256(publicKey));

            assertEq(s_registry.requireMatchingKey(authority, keyHash), publicKey);
        } else {
            vm.expectRevert(QorePqcKeyRegistry.PossessionNotProven.selector);

            s_registry.requireEligibleKey(authority);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          KEY COMMITMENTS
    //////////////////////////////////////////////////////////////*/

    function testFuzzRejectsAnyDifferentKeyCommitment(bytes32 seed, uint256 mutation) public {
        mutation = bound(mutation, 1, type(uint256).max);

        bytes memory publicKey = _syntheticKey(seed);

        _mockResponse(AUTHORITY, abi.encode(true, uint8(1), publicKey, true));

        bytes32 actual = sha256(publicKey);
        bytes32 expected = actual ^ bytes32(mutation);

        vm.expectRevert(
            abi.encodeWithSelector(
                QorePqcKeyRegistry.KeyCommitmentMismatch.selector, expected, actual
            )
        );

        s_registry.requireMatchingKey(AUTHORITY, expected);
    }

    /*//////////////////////////////////////////////////////////////
                         RESPONSE VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testFuzzRejectsIncorrectResponseLength(uint256 rawLength) public {
        uint256 length = bound(rawLength, 0, 4096);

        if (length == EMPTY_RESPONSE_LENGTH || length == REGISTERED_RESPONSE_LENGTH) {
            length += 1;
        }

        _mockResponse(AUTHORITY, new bytes(length));

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testFuzzRejectsMalformedHeader(uint256 rawValue, uint8 rawField, bytes32 seed) public {
        uint256 field = bound(uint256(rawField), 0, 4);

        uint256[5] memory words =
            [uint256(1), uint256(1), uint256(128), uint256(1), PUBLIC_KEY_LENGTH];

        if (field == 0 || field == 3) {
            // Boolean words must contain exactly zero or one.
            words[field] = bound(rawValue, 2, type(uint256).max);
        } else if (field == 1) {
            // The algorithm identifier must fit in uint8.
            words[field] = bound(rawValue, 256, type(uint256).max);
        } else if (field == 2) {
            // Every offset except the canonical 128 is invalid.
            words[field] = rawValue == 128 ? 129 : rawValue;
        } else {
            // Every noncanonical declared key length is invalid.
            words[field] = rawValue == PUBLIC_KEY_LENGTH ? PUBLIC_KEY_LENGTH + 1 : rawValue;
        }

        bytes memory response = bytes.concat(abi.encode(words), _syntheticKey(seed));

        assertEq(response.length, REGISTERED_RESPONSE_LENGTH);

        _mockResponse(AUTHORITY, response);

        _expectInvalidResponse();

        s_registry.getStatus(AUTHORITY);
    }

    function testFuzzRejectsUnsupportedAlgorithms(uint8 rawAlgorithm, bytes32 seed) public {
        uint8 algorithmId = uint8(bound(uint256(rawAlgorithm), 2, type(uint8).max));

        _mockResponse(AUTHORITY, abi.encode(true, algorithmId, _syntheticKey(seed), true));

        vm.expectRevert(
            abi.encodeWithSelector(
                QorePqcKeyRegistry.UnsupportedAlgorithm.selector, uint256(algorithmId)
            )
        );

        s_registry.getStatus(AUTHORITY);
    }

    /*//////////////////////////////////////////////////////////////
                          DEPLOYLESS PARITY
    //////////////////////////////////////////////////////////////*/

    function testFuzzCreationPreservesStatusSummary(
        bytes32 seed,
        bool registered,
        bool possessionProven
    ) public {
        bytes memory publicKey;
        uint8 algorithmId;

        if (registered) {
            publicKey = _syntheticKey(seed);
            algorithmId = 1;
        } else {
            publicKey = new bytes(0);
            algorithmId = 0;
            possessionProven = false;
        }

        _mockResponse(AUTHORITY, abi.encode(registered, algorithmId, publicKey, possessionProven));

        QorePqcKeyRegistryCreationProbe probe = new QorePqcKeyRegistryCreationProbe(AUTHORITY);

        bytes32 expectedHash = registered ? sha256(publicKey) : bytes32(0);

        bytes memory expected =
            abi.encode(registered, algorithmId, publicKey.length, expectedHash, possessionProven);

        assertEq(address(probe).code.length, 160);
        assertEq(address(probe).code, expected);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _syntheticKey(bytes32 seed) internal pure returns (bytes memory publicKey) {
        publicKey = new bytes(PUBLIC_KEY_LENGTH);

        for (uint256 i = 0; i < 32; i++) {
            publicKey[i] = seed[i];
        }

        publicKey[PUBLIC_KEY_LENGTH - 1] = 0xA5;
    }

    function _mockResponse(address authority, bytes memory response) internal {
        vm.mockCall(
            PQC_KEY_STATUS_PRECOMPILE,
            abi.encodeWithSignature("pqcKeyStatus(address)", authority),
            response
        );
    }

    function _expectInvalidResponse() internal {
        vm.expectRevert(QorePqcKeyRegistry.InvalidPqcKeyStatusResponse.selector);
    }
}
