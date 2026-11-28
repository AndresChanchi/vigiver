// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {QorePqcKeyRegistry} from "../../../../src/cryptography/qorechain/QorePqcKeyRegistry.sol";

/// @dev Exposes the internal registered-key library for testing.
contract QorePqcKeyRegistryHarness {
    function getStatus(address authority)
        external
        view
        returns (QorePqcKeyRegistry.KeyStatus memory)
    {
        return QorePqcKeyRegistry.getStatus(authority);
    }

    function requireEligibleKey(address authority)
        external
        view
        returns (bytes memory publicKey, bytes32 keyHash)
    {
        return QorePqcKeyRegistry.requireEligibleKey(authority);
    }

    function requireMatchingKey(address authority, bytes32 expectedKeyHash)
        external
        view
        returns (bytes memory publicKey)
    {
        return QorePqcKeyRegistry.requireMatchingKey(authority, expectedKeyHash);
    }
}
