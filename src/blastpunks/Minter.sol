// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IMinter} from "./interfaces/IMinter.sol";
import {Blastpunks} from "./Blastpunks.sol";

contract Minter is IMinter, Ownable {
    uint256 public constant LAUNCH = 1711242000;
    address public immutable blastpunks;
    bytes32 public immutable root;

    uint256[] internal availableToMint;
    mapping(bytes32 => uint256) internal mints;

    constructor(address _blastpunks, address treasury, bytes32 _root) Ownable(treasury) {
        blastpunks = _blastpunks;
        root = _root;

        for (uint256 i = 0; i < 3000; i++) {
            availableToMint.push(i);
        }
    }

    function available() external view returns (uint256) {
        return availableToMint.length;
    }

    function mint(Tier tier, uint256 amount, bytes32[] memory proof) external payable {
        if (tier != Tier.Public) {
            bytes32 leaf = keccak256(abi.encode(msg.sender, tier));
            mints[leaf] += amount;
            if (!MerkleProof.verify(proof, root, leaf)) revert Forbidden();
            if (mints[leaf] > 5) revert LimitExceeded();
        }

        uint256 minTime = LAUNCH + 2 hours;
        uint256 maxTime = type(uint256).max;
        uint256 price = 25000000 gwei;

        if (tier == Tier.Original) (minTime, maxTime, price) = (LAUNCH, LAUNCH + 1 hours, 15000000 gwei);
        if (tier == Tier.Whitelist) (minTime, maxTime, price) = (LAUNCH + 1 hours, LAUNCH + 2 hours, 20000000 gwei);
        if (block.timestamp < minTime || block.timestamp > maxTime) revert InvalidPeriod();
        if (msg.value < price * amount) revert InvalidPrice();

        for (uint256 i = 0; i < amount; i++) {
            uint256 index = uint256(keccak256(abi.encode(block.prevrandao))) % availableToMint.length;
            uint256 id = availableToMint[index];
            availableToMint[index] = availableToMint[availableToMint.length - 1];
            availableToMint.pop();

            Blastpunks(blastpunks).mint(msg.sender, id);
        }
    }

    function ownership(address owner) external onlyOwner {
        Blastpunks(blastpunks).transferOwnership(owner);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
}
