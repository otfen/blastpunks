// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IBlast {
    /// @notice Configures the governor of the contract.
    function configureGovernor(address _governor) external;
}
