// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

/// @title QorePqcVerifier
/// @notice Verifies ML-DSA-87 signatures through QoreChain's native precompile.
/// @dev This library validates signatures, not signing authority.
///      Registered-key checks, replay protection, and authorization policies
///      belong to separate components.
/// @custom:security-contact See SECURITY.md in the repository root.
library QorePqcVerifier {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The native verification call failed.
    error PqcCallFailed();

    /// @notice The native response is empty or incorrectly encoded.
    error InvalidPqcResponse();

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant PQC_VERIFY_PRECOMPILE = address(0x0A01);

    uint256 internal constant PUBLIC_KEY_LENGTH = 2592;
    uint256 internal constant SIGNATURE_LENGTH = 4627;
    uint256 internal constant RESPONSE_LENGTH = 32;

    bytes4 internal constant VERIFY_SELECTOR = bytes4(keccak256("pqcVerify(bytes,bytes,bytes)"));

    /*//////////////////////////////////////////////////////////////
                            SIGNATURE VERIFICATION
    //////////////////////////////////////////////////////////////*/

    /// @notice Verifies an ML-DSA-87 signature.
    /// @param publicKey The encoded ML-DSA-87 public key.
    /// @param signature The encoded ML-DSA-87 signature.
    /// @param message The exact bytes signed by the signer.
    /// @return valid Whether the signature is cryptographically valid.
    /// @dev Invalid input lengths return false.
    ///      Infrastructure failures revert instead of granting authority.
    function verify(bytes memory publicKey, bytes memory signature, bytes memory message)
        internal
        view
        returns (bool valid)
    {
        if (publicKey.length != PUBLIC_KEY_LENGTH || signature.length != SIGNATURE_LENGTH) {
            return false;
        }

        bytes memory callData =
            abi.encodeWithSelector(VERIFY_SELECTOR, publicKey, signature, message);

        (bool success, bytes memory response) = PQC_VERIFY_PRECOMPILE.staticcall(callData);

        if (!success) {
            revert PqcCallFailed();
        }

        if (response.length != RESPONSE_LENGTH) {
            revert InvalidPqcResponse();
        }

        uint256 result = abi.decode(response, (uint256));

        if (result > 1) {
            revert InvalidPqcResponse();
        }

        return result == 1;
    }
}
