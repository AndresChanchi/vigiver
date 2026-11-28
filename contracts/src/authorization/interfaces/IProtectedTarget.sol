// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity 0.8.39;

/// @title IProtectedTarget
/// @notice Supported administrative target for Vigiver Authorization v1.
/// @dev The interface alone does not establish target security or compatibility.
interface IProtectedTarget {
    function owner() external view returns (address);

    function parameter() external view returns (uint256);

    function setParameter(uint256 newValue) external;
}
