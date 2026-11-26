// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {QorePqcVerifier} from "../../../../src/cryptography/qorechain/QorePqcVerifier.sol";

/// @dev Exposes the internal verification library for testing.
contract QorePqcVerifierHarness {
    function verify(bytes calldata publicKey, bytes calldata signature, bytes calldata message)
        external
        view
        returns (bool)
    {
        return QorePqcVerifier.verify(publicKey, signature, message);
    }
}
