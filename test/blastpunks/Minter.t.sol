// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Merkle} from "murky/src/Merkle.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import {IMinter} from "../../src/blastpunks/interfaces/IMinter.sol";
import {Minter} from "../../src/blastpunks/Minter.sol";
import {Blastpunks} from "../../src/blastpunks/Blastpunks.sol";

contract MinterTest is Test {
    using EnumerableSet for EnumerableSet.AddressSet;

    Blastpunks blastpunks = new Blastpunks(address(1));
    EnumerableSet.AddressSet internal set;

    function setUp() public {}

    function testChunk(address deployer, bytes32 root) public returns (Minter minter) {
        vm.assume(deployer != address(0));
        vm.startPrank(deployer);
        minter = new Minter(address(blastpunks), address(deployer), root);
        minter.chunk(0, 3000);
        vm.stopPrank();
    }

    function testAvailable() public {
        Minter minter = testChunk(address(1), bytes32(0));
        assertEq(minter.available(), 3000);
    }

    function testMerkle(address[16] memory addresses) public returns (bytes32, address[] memory, bytes32[] memory) {
        for (uint256 i = 0; i < addresses.length; i++) {
            if (addresses[i] == address(0) || addresses[i] == address(1)) continue;
            set.add(addresses[i]);
        }

        address[] memory values = set.values();
        bytes32[] memory leaves = new bytes32[](values.length);

        for (uint256 i = 0; i < values.length; i++) {
            IMinter.Tier tier = IMinter.Tier(uint256(keccak256(abi.encode(values[i]))) % 3);
            leaves[i] = keccak256(abi.encode(values[i], tier));
        }

        Merkle tree = new Merkle();
        bytes32 root = tree.getRoot(leaves);

        for (uint256 i = 0; i < leaves.length; i++) {
            bytes32[] memory proof = tree.getProof(leaves, i);
            MerkleProof.verify(proof, root, leaves[i]);
        }

        return (root, values, leaves);
    }

    function testMintSetup(address[16] memory addresses, uint256 entropy)
        public
        returns (Minter, IMinter.Tier, address, bytes32[] memory)
    {
        (bytes32 root, address[] memory values, bytes32[] memory leaves) = testMerkle(addresses);
        Minter minter = testChunk(address(1), root);
        blastpunks.transferOwnership(address(minter));

        uint256 index = entropy % values.length;
        address caller = values[index];
        bytes32[] memory proof = new Merkle().getProof(leaves, index);
        IMinter.Tier tier = IMinter.Tier(uint256(keccak256(abi.encode(caller))) % 3);

        return (minter, tier, caller, proof);
    }

    function testMint(address[16] memory addresses, uint8 amount, uint256 entropy) public {
        (Minter minter, IMinter.Tier tier, address caller, bytes32[] memory proof) = testMintSetup(addresses, entropy);
        (uint256 timestamp, uint256 price) = (1711242000, 15000000 gwei);
        if (tier == IMinter.Tier.Whitelist) (timestamp, price) = (timestamp + 1 hours, 20000000 gwei);
        if (tier == IMinter.Tier.Public) (timestamp, price) = (timestamp + 2 hours, 25000000 gwei);
        amount = uint8(bound(amount, 1, 5));

        vm.deal(caller, 1 ether);
        vm.startPrank(caller);
        vm.warp(timestamp);

        minter.mint{value: price * amount}(tier, amount, proof);
        assertEq(blastpunks.balanceOf(caller), amount);
        assertEq(address(minter).balance, price * amount);
    }

    function testMintForbidden(address[16] memory addresses, uint256 entropy) public {
        (Minter minter, IMinter.Tier tier,, bytes32[] memory proof) = testMintSetup(addresses, entropy);
        if (tier == IMinter.Tier.Public) return;

        vm.startPrank(address(0));
        vm.expectRevert(IMinter.Forbidden.selector);
        minter.mint{value: 0}(tier, 1, proof);
    }

    function testMintLimitExceeded(address[16] memory addresses, uint8 amount, uint256 entropy) public {
        (Minter minter, IMinter.Tier tier, address caller, bytes32[] memory proof) = testMintSetup(addresses, entropy);
        if (tier == IMinter.Tier.Public) return;
        amount = uint8(bound(amount, 6, type(uint8).max));

        vm.startPrank(caller);
        vm.expectRevert(IMinter.LimitExceeded.selector);
        minter.mint{value: 0}(tier, amount, proof);
    }

    function testMintInvalidPeriod(address[16] memory addresses, uint8 amount, uint248 timestamp, uint256 entropy)
        public
    {
        (Minter minter, IMinter.Tier tier, address caller, bytes32[] memory proof) = testMintSetup(addresses, entropy);
        (uint256 min, uint256 max, uint256 price) = (1711242000, 1711242000 + 1 hours, 15000000 gwei);
        if (tier == IMinter.Tier.Whitelist) (min, max, price) = (min + 1 hours, max + 1 hours, 20000000 gwei);
        if (tier == IMinter.Tier.Public) (min, max, price) = (min + 2 hours, type(uint248).max, 25000000 gwei);
        amount = uint8(bound(amount, 1, 5));

        uint256 invalidTimestamp = entropy % 1 == 0
            ? bound(timestamp, 0, min - 1)
            : (tier == IMinter.Tier.Public ? 0 : bound(timestamp, max + 1, type(uint256).max));

        vm.startPrank(caller);
        vm.warp(invalidTimestamp);
        vm.expectRevert(IMinter.InvalidPeriod.selector);
        minter.mint{value: 0}(tier, amount, proof);
    }

    function testMintInvalidPrice(address[16] memory addresses, uint8 amount, uint256 entropy) public {
        (Minter minter, IMinter.Tier tier, address caller, bytes32[] memory proof) = testMintSetup(addresses, entropy);
        (uint256 timestamp, uint256 price) = (1711242000, 15000000 gwei);
        if (tier == IMinter.Tier.Whitelist) (timestamp, price) = (timestamp + 1 hours, 20000000 gwei);
        if (tier == IMinter.Tier.Public) (timestamp, price) = (timestamp + 2 hours, 25000000 gwei);
        amount = uint8(bound(amount, 1, 5));

        vm.deal(caller, 1 ether);
        vm.startPrank(caller);
        vm.warp(timestamp);
        vm.expectRevert(IMinter.InvalidPrice.selector);
        minter.mint{value: price * amount - 1}(tier, amount, proof);
    }

    function testOwnership(address treasury, address newOwner) public {
        vm.assume(treasury != address(0) && newOwner != address(0));
        Minter minter = testChunk(treasury, bytes32(0));
        blastpunks.transferOwnership(address(minter));
        vm.startPrank(treasury);
        minter.ownership(newOwner);
        assertEq(newOwner, blastpunks.owner());
    }

    function testWithdraw(address treasury, uint128 amount) public {
        vm.assume(treasury != address(0));
        Minter minter = testChunk(treasury, bytes32(0));
        vm.assume(payable(treasury).send(0));
        blastpunks.transferOwnership(address(minter));
        vm.deal(address(minter), amount);
        vm.startPrank(treasury);
        minter.withdraw();
        assertEq(treasury.balance, amount);
    }
}
