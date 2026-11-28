// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {IQorePqcKeyStatusPrecompile} from "./interfaces/IQorePqcKeyStatusPrecompile.sol";

/// @title QorePqcKeyRegistry
/// @notice Retrieves and validates registered ML-DSA-87 public keys.
/// @dev Registration and possession checks establish key eligibility,
///      not authorization of an application operation.
/// @custom:security-contact See SECURITY.md in the repository root.
library QorePqcKeyRegistry {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct KeyStatus {
        bool registered;
        uint8 algorithmId;
        bytes publicKey;
        bool possessionProven;
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    /// @notice The requested native authority is the zero address.
    error InvalidAuthority();

    /// @notice The native registered-key query failed.
    error PqcKeyStatusCallFailed();

    /// @notice The response is malformed or semantically inconsistent.
    error InvalidPqcKeyStatusResponse();

    /// @notice The registered algorithm is not supported by this adapter.
    error UnsupportedAlgorithm(uint256 algorithmId);

    /// @notice The authority does not have a registered PQC key.
    error KeyNotRegistered();

    /// @notice The registered key does not have proven possession.
    error PossessionNotProven();

    /// @notice The registered public key does not match the expected commitment.
    error KeyCommitmentMismatch(bytes32 expected, bytes32 actual);

    /*//////////////////////////////////////////////////////////////
                               CONSTANTS
    //////////////////////////////////////////////////////////////*/

    address internal constant PQC_KEY_STATUS_PRECOMPILE = address(0x0A02);

    uint8 internal constant ML_DSA_87_ALGORITHM_ID = 1;

    uint256 internal constant PUBLIC_KEY_LENGTH = 2592;

    // Four ABI head words followed by the dynamic bytes length.
    uint256 internal constant CANONICAL_DYNAMIC_OFFSET = 128;
    uint256 internal constant EMPTY_RESPONSE_LENGTH = 160;

    // ML-DSA-87 public keys require no additional ABI padding.
    uint256 internal constant REGISTERED_RESPONSE_LENGTH = EMPTY_RESPONSE_LENGTH
        + PUBLIC_KEY_LENGTH;

    /*//////////////////////////////////////////////////////////////
                           REGISTERED KEY STATUS
    //////////////////////////////////////////////////////////////*/

    /// @notice Retrieves the canonical registered-key status.
    /// @param authority The native account represented as a 20-byte address.
    /// @return status The validated registered-key response.
    /// @dev An unregistered account or legacy registration without possession
    ///      is a valid diagnostic result, but not an eligible authority.
    ///      Only the observed ML-DSA-87 registration format is supported.
    function getStatus(address authority) internal view returns (KeyStatus memory status) {
        if (authority == address(0)) {
            revert InvalidAuthority();
        }

        bytes memory callData =
            abi.encodeCall(IQorePqcKeyStatusPrecompile.pqcKeyStatus, (authority));

        (bool success, bytes memory response) = PQC_KEY_STATUS_PRECOMPILE.staticcall(callData);

        if (!success) {
            revert PqcKeyStatusCallFailed();
        }

        _validateResponse(response);

        (status.registered, status.algorithmId, status.publicKey, status.possessionProven) =
            abi.decode(response, (bool, uint8, bytes, bool));
    }

    /*//////////////////////////////////////////////////////////////
                             KEY ELIGIBILITY
    //////////////////////////////////////////////////////////////*/

    /// @notice Requires a registered ML-DSA-87 key with proven possession.
    /// @param authority The native account whose key must be eligible.
    /// @return publicKey The recognized registered public key.
    /// @return keyHash The SHA-256 commitment of the public key.
    function requireEligibleKey(address authority)
        internal
        view
        returns (bytes memory publicKey, bytes32 keyHash)
    {
        KeyStatus memory status = getStatus(authority);

        if (!status.registered) {
            revert KeyNotRegistered();
        }

        if (!status.possessionProven) {
            revert PossessionNotProven();
        }

        publicKey = status.publicKey;
        keyHash = sha256(publicKey);
    }

    /// @notice Requires an eligible key matching the admitted commitment.
    /// @param authority The recognized native account.
    /// @param expectedKeyHash The commitment admitted by application policy.
    /// @return publicKey The eligible registered public key.
    function requireMatchingKey(address authority, bytes32 expectedKeyHash)
        internal
        view
        returns (bytes memory publicKey)
    {
        bytes32 actualKeyHash;

        (publicKey, actualKeyHash) = requireEligibleKey(authority);

        if (actualKeyHash != expectedKeyHash) {
            revert KeyCommitmentMismatch(expectedKeyHash, actualKeyHash);
        }
    }

    /*//////////////////////////////////////////////////////////////
                          RESPONSE VALIDATION
    //////////////////////////////////////////////////////////////*/

    /// @dev Checks the static header before dynamic ABI decoding.
    function _validateResponse(bytes memory response) private pure {
        uint256 responseLength = response.length;

        if (responseLength != EMPTY_RESPONSE_LENGTH && responseLength != REGISTERED_RESPONSE_LENGTH)
        {
            revert InvalidPqcKeyStatusResponse();
        }

        // Decode only fixed-width words at this stage.
        // The supplied dynamic offset is not followed.
        (
            uint256 registered,
            uint256 algorithmId,
            uint256 dynamicOffset,
            uint256 possessionProven,
            uint256 publicKeyLength
        ) = abi.decode(response, (uint256, uint256, uint256, uint256, uint256));

        if (
            registered > 1 || possessionProven > 1 || algorithmId > type(uint8).max
                || dynamicOffset != CANONICAL_DYNAMIC_OFFSET
        ) {
            revert InvalidPqcKeyStatusResponse();
        }

        if (registered == 0) {
            if (
                algorithmId != 0 || possessionProven != 0 || publicKeyLength != 0
                    || responseLength != EMPTY_RESPONSE_LENGTH
            ) {
                revert InvalidPqcKeyStatusResponse();
            }

            return;
        }

        if (algorithmId != ML_DSA_87_ALGORITHM_ID) {
            revert UnsupportedAlgorithm(algorithmId);
        }

        if (publicKeyLength != PUBLIC_KEY_LENGTH || responseLength != REGISTERED_RESPONSE_LENGTH) {
            revert InvalidPqcKeyStatusResponse();
        }
    }
}
