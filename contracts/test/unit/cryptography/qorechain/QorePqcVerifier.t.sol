// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";
import {
    IQorePqcVerifyPrecompile
} from "../../../../src/cryptography/qorechain/interfaces/IQorePqcVerifyPrecompile.sol";
import {QorePqcVerifier} from "../../../../src/cryptography/qorechain/QorePqcVerifier.sol";
import {
    QorePqcVerifierHarness
} from "../../../helpers/cryptography/qorechain/QorePqcVerifierHarness.sol";

contract QorePqcVerifierTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant PQC_PRECOMPILE = address(0x0A01);

    uint256 private constant PUBLIC_KEY_LENGTH = 2592;
    uint256 private constant SIGNATURE_LENGTH = 4627;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    QorePqcVerifierHarness private s_verifier;

    bytes private s_publicKey;
    bytes private s_signature;
    bytes private s_message;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        s_verifier = new QorePqcVerifierHarness();

        // Synthetic inputs test adapter behavior, not real cryptography.
        s_publicKey = new bytes(PUBLIC_KEY_LENGTH);
        s_signature = new bytes(SIGNATURE_LENGTH);

        s_publicKey[0] = 0x01;
        s_signature[0] = 0x02;

        s_message = bytes("Post-quantum verification boundary");

        // Simulate an endpoint returning empty data by default.
        // PUSH1 0x00, PUSH1 0x00, RETURN.
        vm.etch(PQC_PRECOMPILE, hex"60006000f3");
    }

    /*//////////////////////////////////////////////////////////////
                         SIGNATURE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    function testAcceptsValidSignatureResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), abi.encode(true));

        assertTrue(s_verifier.verify(s_publicKey, s_signature, s_message));
    }

    function testRejectsInvalidSignatureResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), abi.encode(false));

        assertFalse(s_verifier.verify(s_publicKey, s_signature, s_message));
    }

    /*//////////////////////////////////////////////////////////////
                           INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testRejectsShortPublicKey() public {
        _mockUnexpectedPrecompileCall();

        bytes memory invalidPublicKey = new bytes(PUBLIC_KEY_LENGTH - 1);

        assertFalse(s_verifier.verify(invalidPublicKey, s_signature, s_message));
    }

    function testRejectsOversizedPublicKey() public {
        _mockUnexpectedPrecompileCall();

        bytes memory invalidPublicKey = new bytes(PUBLIC_KEY_LENGTH + 1);

        assertFalse(s_verifier.verify(invalidPublicKey, s_signature, s_message));
    }

    function testRejectsShortSignature() public {
        _mockUnexpectedPrecompileCall();

        bytes memory invalidSignature = new bytes(SIGNATURE_LENGTH - 1);

        assertFalse(s_verifier.verify(s_publicKey, invalidSignature, s_message));
    }

    function testRejectsOversizedSignature() public {
        _mockUnexpectedPrecompileCall();

        bytes memory invalidSignature = new bytes(SIGNATURE_LENGTH + 1);

        assertFalse(s_verifier.verify(s_publicKey, invalidSignature, s_message));
    }

    /*//////////////////////////////////////////////////////////////
                          RESPONSE VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testRevertsOnEmptyResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), hex"");

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    function testRevertsOnTruncatedResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), hex"01");

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    function testRevertsOnOversizedResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), abi.encode(true, uint256(0)));

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    function testRevertsOnNonCanonicalBoolean() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(), abi.encode(uint256(2)));

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    /*//////////////////////////////////////////////////////////////
                         INFRASTRUCTURE FAILURES
    //////////////////////////////////////////////////////////////*/

    function testRevertsOnFailedPrecompileCall() public {
        vm.mockCallRevert(PQC_PRECOMPILE, _verificationCalldata(), hex"");

        vm.expectRevert(QorePqcVerifier.PqcCallFailed.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    function testRevertsWhenPrecompileIsUnavailable() public {
        vm.etch(PQC_PRECOMPILE, hex"");

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(s_publicKey, s_signature, s_message);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verificationCalldata() internal view returns (bytes memory) {
        return abi.encodeWithSignature(
            "pqcVerify(bytes,bytes,bytes)", s_publicKey, s_signature, s_message
        );
    }

    function _mockUnexpectedPrecompileCall() internal {
        vm.mockCallRevert(
            PQC_PRECOMPILE, abi.encodePacked(IQorePqcVerifyPrecompile.pqcVerify.selector), hex""
        );
    }
}
