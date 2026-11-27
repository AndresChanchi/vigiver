// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {QorePqcVerifier} from "../../../../src/cryptography/qorechain/QorePqcVerifier.sol";

/// @title QorePqcVerifierCreationProbe
/// @notice Executes the native PQC verification adapter during contract creation.
/// @dev Research and testing helper only. Its creation output is an ABI boolean,
///      not executable application runtime bytecode.
///      Intended for eth_call without a destination or state overrides.
///      Never broadcast its creation bytecode as a deployment transaction.
contract QorePqcVerifierCreationProbe {
    constructor(bytes memory publicKey, bytes memory signature, bytes memory message) {
        bool valid = QorePqcVerifier.verify(publicKey, signature, message);

        // Return the canonical ABI boolean as creation output.
        // A deployless eth_call exposes this output without persisting code.
        assembly ("memory-safe") {
            mstore(0x00, valid)
            return(0x00, 0x20)
        }
    }
}
