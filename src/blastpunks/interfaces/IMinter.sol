// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

interface IMinter {
    /// @notice Thrown when the merkle proof provided is not valid.
    error Forbidden();

    /// @notice Thrown when the minting limit is exceeded.
    error LimitExceeded();

    /// @notice Thrown when the minting time is invalid.
    error InvalidPeriod();

    /// @notice Thrown when the minting price is lower than the required minting price.
    error InvalidPrice();

    /// @notice A enum representing the minting tiers.
    enum Tier {
        Original,
        Whitelist,
        Public
    }

    /// @notice Returns the launch timestamp.
    function LAUNCH() external view returns (uint256);

    /// @notice Returns the address of Blastpunks.
    function blastpunks() external view returns (address);

    /// @notice Returns the minting merkle root.
    function root() external view returns (bytes32);

    /// @notice Returns the amount available for minting.
    function available() external view returns (uint256);

    /// @notice Mints Blastpunks.
    /// @param tier The minting tier.
    /// @param amount The amount to mint.
    /// @param proof The minting merkle proof.
    function mint(Tier tier, uint256 amount, bytes32[] memory proof) external payable;

    /// @notice Transfers ownership of Blastpunks' contract.
    function ownership(address owner) external;

    /// @notice Transfers collected funds to the contract owner's address.
    function withdraw() external;
}
