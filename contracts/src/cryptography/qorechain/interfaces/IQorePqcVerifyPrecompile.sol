// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

/// @title IQorePqcVerifyPrecompile
/// @notice ABI interface for QoreChain's native PQC verification precompile.
/// @dev Declares the external interface without implementing cryptography.
interface IQorePqcVerifyPrecompile {
    /// @notice Verifies a post-quantum signature.
    /// @param publicKey The encoded public key.
    /// @param signature The encoded signature.
    /// @param message The exact signed message.
    /// @return valid Whether the signature is valid.
    function pqcVerify(bytes calldata publicKey, bytes calldata signature, bytes calldata message)
        external
        view
        returns (bool valid);
}

