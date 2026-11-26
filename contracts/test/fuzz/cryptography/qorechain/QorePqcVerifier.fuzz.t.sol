// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {Test} from "forge-std/Test.sol";

import {QorePqcVerifier} from "../../../../src/cryptography/qorechain/QorePqcVerifier.sol";

import {
    IQorePqcVerifyPrecompile
} from "../../../../src/cryptography/qorechain/interfaces/IQorePqcVerifyPrecompile.sol";

import {
    QorePqcVerifierHarness
} from "../../../helpers/cryptography/qorechain/QorePqcVerifierHarness.sol";

contract QorePqcVerifierFuzzTest is Test {
    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address private constant PQC_PRECOMPILE = address(0x0A01);

    uint256 private constant PUBLIC_KEY_LENGTH = 2592;
    uint256 private constant SIGNATURE_LENGTH = 4627;
    uint256 private constant RESPONSE_LENGTH = 32;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    QorePqcVerifierHarness private s_verifier;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() public {
        s_verifier = new QorePqcVerifierHarness();

        // Unmatched calls return empty data and cannot authorize anything.
        vm.etch(PQC_PRECOMPILE, hex"60006000f3");
    }

    /*//////////////////////////////////////////////////////////////
                           INPUT PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzzRejectsIncorrectPublicKeyLength(uint256 rawLength) public {
        uint256 length = _incorrectLength(rawLength, PUBLIC_KEY_LENGTH, PUBLIC_KEY_LENGTH * 2);

        _rejectUnexpectedPrecompileCalls();

        assertFalse(
            s_verifier.verify(new bytes(length), new bytes(SIGNATURE_LENGTH), bytes("message"))
        );
    }

    function testFuzzRejectsIncorrectSignatureLength(uint256 rawLength) public {
        uint256 length = _incorrectLength(rawLength, SIGNATURE_LENGTH, SIGNATURE_LENGTH * 2);

        _rejectUnexpectedPrecompileCalls();

        assertFalse(
            s_verifier.verify(new bytes(PUBLIC_KEY_LENGTH), new bytes(length), bytes("message"))
        );
    }

    /*//////////////////////////////////////////////////////////////
                          RESPONSE PROPERTIES
    //////////////////////////////////////////////////////////////*/

    function testFuzzRejectsIncorrectResponseLength(uint256 rawLength) public {
        uint256 length = _incorrectLength(rawLength, RESPONSE_LENGTH, 1024);

        bytes memory publicKey = new bytes(PUBLIC_KEY_LENGTH);
        bytes memory signature = new bytes(SIGNATURE_LENGTH);
        bytes memory message = bytes("message");

        vm.mockCall(
            PQC_PRECOMPILE, _verificationCalldata(publicKey, signature, message), new bytes(length)
        );

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(publicKey, signature, message);
    }

    function testFuzzRejectsNonCanonicalBoolean(uint256 responseWord) public {
        responseWord = bound(responseWord, 2, type(uint256).max);

        bytes memory publicKey = new bytes(PUBLIC_KEY_LENGTH);
        bytes memory signature = new bytes(SIGNATURE_LENGTH);
        bytes memory message = bytes("message");

        vm.mockCall(
            PQC_PRECOMPILE,
            _verificationCalldata(publicKey, signature, message),
            abi.encode(responseWord)
        );

        vm.expectRevert(QorePqcVerifier.InvalidPqcResponse.selector);

        s_verifier.verify(publicKey, signature, message);
    }

    function testFuzzPreservesVerificationResult(bytes memory message, bool expected) public {
        bytes memory publicKey = new bytes(PUBLIC_KEY_LENGTH);
        bytes memory signature = new bytes(SIGNATURE_LENGTH);

        publicKey[0] = 0x01;
        signature[0] = 0x02;

        bytes memory expectedCalldata = _verificationCalldata(publicKey, signature, message);

        vm.mockCall(PQC_PRECOMPILE, expectedCalldata, abi.encode(expected));

        vm.expectCall(PQC_PRECOMPILE, expectedCalldata);

        assertEq(s_verifier.verify(publicKey, signature, message), expected);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _incorrectLength(uint256 rawLength, uint256 expectedLength, uint256 maximumLength)
        internal
        pure
        returns (uint256)
    {
        uint256 length = bound(rawLength, 0, maximumLength - 1);

        return length >= expectedLength ? length + 1 : length;
    }

    function _rejectUnexpectedPrecompileCalls() internal {
        vm.mockCallRevert(
            PQC_PRECOMPILE, abi.encodePacked(IQorePqcVerifyPrecompile.pqcVerify.selector), hex""
        );
    }

    function _verificationCalldata(
        bytes memory publicKey,
        bytes memory signature,
        bytes memory message
    ) internal pure returns (bytes memory) {
        return abi.encodeWithSignature(
            "pqcVerify(bytes,bytes,bytes)", publicKey, signature, message
        );
    }
}
