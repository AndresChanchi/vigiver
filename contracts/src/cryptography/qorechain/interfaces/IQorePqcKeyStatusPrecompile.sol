// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

/// @title IQorePqcKeyStatusPrecompile
/// @notice ABI interface for QoreChain's registered PQC key status precompile.
interface IQorePqcKeyStatusPrecompile {
    /// @notice Retrieves the registered PQC key status of a native account.
    /// @param authority The native account represented as a 20-byte address.
    /// @return registered Whether a PQC key is registered.
    /// @return algorithmId The registered cryptographic algorithm identifier.
    /// @return publicKey The registered public key.
    /// @return possessionProven Whether the registration has proven possession.
    function pqcKeyStatus(address authority)
        external
        view
        returns (bool registered, uint8 algorithmId, bytes memory publicKey, bool possessionProven);
}
