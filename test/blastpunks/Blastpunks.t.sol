// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Blastpunks} from "../../src/blastpunks/Blastpunks.sol";

contract BlastpunksTest is Test {
    function testMetadata() public {
        Blastpunks blastpunks = new Blastpunks(address(1));

        assertEq(blastpunks.name(), "Blastpunks");
        assertEq(blastpunks.symbol(), "BP");
    }

    function testTreasuryMint(address treasury, uint256 id) public {
        vm.assume(treasury != address(0));
        id = bound(id, 3000, 9999);

        Blastpunks blastpunks = new Blastpunks(treasury);
        assertEq(blastpunks.balanceOf(treasury), 7000);
        assertEq(blastpunks.ownerOf(id), treasury);
    }

    function testMint(uint256 id) public {
        id = bound(id, 0, 999);

        Blastpunks blastpunks = new Blastpunks(address(1));
        blastpunks.mint(address(2), id);
        assertEq(blastpunks.ownerOf(id), address(2));
    }

    function testMintExisting(uint256 id) public {
        id = bound(id, 3000, 9999);

        Blastpunks blastpunks = new Blastpunks(address(1));
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721InvalidSender.selector, address(0)));
        blastpunks.mint(address(2), id);
    }

    function testURI(uint256 id) public {
        id = bound(id, 3000, 9999);

        Blastpunks blastpunks = new Blastpunks(address(1));
        assertEq(
            blastpunks.tokenURI(id),
            string.concat("ipfs://bafybeifn6ixki6ce7no7b2eso2kkuzqyhkh4v577juefxt6kciwa3mvtky/", Strings.toString(id))
        );
    }

    function testRoyalty(address treasury, uint256 id, uint248 amount) public {
        vm.assume(treasury != address(0));
        id = bound(id, 3000, 9999);

        Blastpunks blastpunks = new Blastpunks(treasury);
        (address receiver, uint256 fee) = blastpunks.royaltyInfo(id, amount);
        assertEq(receiver, treasury);
        assertEq(fee, uint256(amount) / 50);
    }
}
