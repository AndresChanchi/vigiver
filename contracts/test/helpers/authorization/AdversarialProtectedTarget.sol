// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

import {IProtectedTarget} from "../../../src/authorization/interfaces/IProtectedTarget.sol";

/// @dev Deliberately adversarial test double. Never deploy as a protected target.
contract AdversarialProtectedTarget is IProtectedTarget {
    enum Mode {
        Normal,
        RevertExecution,
        IgnoreParameter,
        ChangeOwner,
        Reenter
    }

    error UnauthorizedOwner();
    error IntentionalTargetFailure();
    error UnexpectedSuccessfulReentry();

    address public override owner;
    uint256 public override parameter;

    Mode public mode;

    address private s_reentryController;
    bytes private s_reentryCalldata;

    constructor(uint256 initialParameter) {
        owner = msg.sender;
        parameter = initialParameter;
    }

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert UnauthorizedOwner();

        owner = newOwner;
    }

    /// @dev Unrestricted configuration exists only for local adversarial testing.
    function setMode(Mode newMode) external {
        mode = newMode;
    }

    function configureReentry(address controller, bytes calldata callData) external {
        s_reentryController = controller;
        s_reentryCalldata = callData;
    }

    /// @dev Simulates an unexpected external state change.
    function forceParameter(uint256 newValue) external {
        parameter = newValue;
    }

    /// @dev Simulates loss of target ownership.
    function forceOwner(address newOwner) external {
        owner = newOwner;
    }

    function setParameter(uint256 newValue) external override {
        if (msg.sender != owner) revert UnauthorizedOwner();

        if (mode == Mode.RevertExecution) {
            revert IntentionalTargetFailure();
        }

        if (mode == Mode.IgnoreParameter) {
            return;
        }

        if (mode == Mode.ChangeOwner) {
            parameter = newValue;
            owner = address(0xBAD);
            return;
        }

        if (mode == Mode.Reenter) {
            (bool success, bytes memory response) = s_reentryController.call(s_reentryCalldata);

            if (success) revert UnexpectedSuccessfulReentry();

            // Propagate the controller's exact rejection.
            assembly ("memory-safe") {
                revert(add(response, 0x20), mload(response))
            }
        }

        parameter = newValue;
    }
}
