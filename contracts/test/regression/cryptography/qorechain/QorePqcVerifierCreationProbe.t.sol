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

import {
    QorePqcVerifierCreationProbe
} from "../../../helpers/cryptography/qorechain/QorePqcVerifierCreationProbe.sol";

contract QorePqcVerifierCreationProbeTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant PQC_PRECOMPILE = address(0x0A01);

    uint256 private constant PUBLIC_KEY_LENGTH = 2592;
    uint256 private constant SIGNATURE_LENGTH = 4627;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    QorePqcVerifierHarness private s_harness;

    bytes private s_publicKey;
    bytes private s_signature;
    bytes private s_message;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        s_harness = new QorePqcVerifierHarness();

        // Synthetic inputs exercise the adapter and creation boundary.
        // They are not real cryptographic test vectors.
        s_publicKey = new bytes(PUBLIC_KEY_LENGTH);
        s_signature = new bytes(SIGNATURE_LENGTH);

        s_publicKey[0] = 0x01;
        s_signature[0] = 0x02;

        s_message = bytes("Deployless verification boundary");

        // Unexpected calls return empty data.
        vm.etch(PQC_PRECOMPILE, hex"60006000f3");
    }

    /*//////////////////////////////////////////////////////////////
                          SUCCESSFUL EXECUTION
    //////////////////////////////////////////////////////////////*/

    function testCreationReturnsCanonicalTrue() public {
        bytes memory calldata_ = _verificationCalldata(s_message);

        vm.mockCall(PQC_PRECOMPILE, calldata_, abi.encode(true));
        vm.expectCall(PQC_PRECOMPILE, calldata_);

        QorePqcVerifierCreationProbe probe =
            new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);

        assertEq(address(probe).code.length, 32);
        assertEq(address(probe).code, abi.encode(true));
    }

    function testCreationReturnsCanonicalFalse() public {
        bytes memory calldata_ = _verificationCalldata(s_message);

        vm.mockCall(PQC_PRECOMPILE, calldata_, abi.encode(false));
        vm.expectCall(PQC_PRECOMPILE, calldata_);

        QorePqcVerifierCreationProbe probe =
            new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);

        assertEq(address(probe).code.length, 32);
        assertEq(address(probe).code, abi.encode(false));
    }

    /*//////////////////////////////////////////////////////////////
                          INPUT VALIDATION
    //////////////////////////////////////////////////////////////*/

    function testCreationRejectsInvalidPublicKeyLength() public {
        _rejectUnexpectedVerificationCalls();

        bytes memory invalidKey = new bytes(PUBLIC_KEY_LENGTH - 1);

        QorePqcVerifierCreationProbe probe =
            new QorePqcVerifierCreationProbe(invalidKey, s_signature, s_message);

        assertEq(address(probe).code, abi.encode(false));
    }

    function testCreationRejectsInvalidSignatureLength() public {
        _rejectUnexpectedVerificationCalls();

        bytes memory invalidSignature = new bytes(SIGNATURE_LENGTH - 1);

        QorePqcVerifierCreationProbe probe =
            new QorePqcVerifierCreationProbe(s_publicKey, invalidSignature, s_message);

        assertEq(address(probe).code, abi.encode(false));
    }

    /*//////////////////////////////////////////////////////////////
                          INFRASTRUCTURE FAILURES
    //////////////////////////////////////////////////////////////*/

    function testCreationRevertsOnFailedPrecompileCall() public {
        vm.mockCallRevert(PQC_PRECOMPILE, _verificationCalldata(s_message), hex"");

        vm.expectRevert(QorePqcVerifier.PqcCallFailed.selector);

        new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);
    }

    function testCreationRevertsOnEmptyResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(s_message), hex"");

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);
    }

    function testCreationRevertsOnMalformedResponse() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(s_message), hex"01");

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);
    }

    function testCreationRevertsOnNonCanonicalBoolean() public {
        vm.mockCall(PQC_PRECOMPILE, _verificationCalldata(s_message), abi.encode(uint256(2)));

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        new QorePqcVerifierCreationProbe(s_publicKey, s_signature, s_message);
    }

    /*//////////////////////////////////////////////////////////////
                            FUZZ PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzzCreationPreservesAdapterResult(bytes memory message, bool expected) public {
        bytes memory calldata_ = _verificationCalldata(message);

        vm.mockCall(PQC_PRECOMPILE, calldata_, abi.encode(expected));

        bool runtimeResult = s_harness.verify(s_publicKey, s_signature, message);

        QorePqcVerifierCreationProbe probe =
            new QorePqcVerifierCreationProbe(s_publicKey, s_signature, message);

        assertEq(runtimeResult, expected);
        assertEq(address(probe).code.length, 32);
        assertEq(address(probe).code, abi.encode(runtimeResult));
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _verificationCalldata(bytes memory message) internal view returns (bytes memory) {
        return
            abi.encodeWithSignature(
                "pqcVerify(bytes,bytes,bytes)", s_publicKey, s_signature, message
            );
    }

    function _rejectUnexpectedVerificationCalls() internal {
        vm.mockCallRevert(
            PQC_PRECOMPILE, abi.encodePacked(IQorePqcVerifyPrecompile.pqcVerify.selector), hex""
        );
    }
}
