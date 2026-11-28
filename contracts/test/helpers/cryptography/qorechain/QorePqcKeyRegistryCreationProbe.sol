// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {QorePqcKeyRegistry} from "../../../../src/cryptography/qorechain/QorePqcKeyRegistry.sol";

/// @title QorePqcKeyRegistryCreationProbe
/// @notice Executes registered-key validation during simulated creation.
/// @dev Testing helper only. Returns ABI data rather than executable runtime
///      bytecode. Never broadcast this creation bytecode as a deployment.
contract QorePqcKeyRegistryCreationProbe {
    constructor(address authority) {
        QorePqcKeyRegistry.KeyStatus memory status = QorePqcKeyRegistry.getStatus(authority);

        bytes32 keyHash = status.registered ? sha256(status.publicKey) : bytes32(0);

        bytes memory result = abi.encode(
            status.registered,
            status.algorithmId,
            status.publicKey.length,
            keyHash,
            status.possessionProven
        );

        assembly ("memory-safe") {
            return(add(result, 0x20), mload(result))
        }
    }
}
