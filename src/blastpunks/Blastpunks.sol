// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Royalty} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Royalty.sol";
import {ERC721Consecutive} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Consecutive.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IBlast} from "./interfaces/IBlast.sol";

contract Blastpunks is ERC721, ERC721Consecutive, ERC721Royalty, Ownable {
    constructor(address treasury) ERC721("Blastpunks", "BP") Ownable(msg.sender) {
        _mintConsecutive(treasury, 5000);
        _mintConsecutive(treasury, 2000);
        _setDefaultRoyalty(treasury, 200);
    }

    function configure(address treasury) external onlyOwner {
        IBlast(0x4300000000000000000000000000000000000002).configureGovernor(treasury);
    }

    function mint(address to, uint256 tokenId) external onlyOwner {
        _safeMint(to, tokenId);
    }

    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://bafybeifn6ixki6ce7no7b2eso2kkuzqyhkh4v577juefxt6kciwa3mvtky/";
    }

    function _firstConsecutiveId() internal pure override returns (uint96) {
        return 3000;
    }

    function _ownerOf(uint256 tokenId) internal view override(ERC721, ERC721Consecutive) returns (address) {
        return super._ownerOf(tokenId);
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721, ERC721Consecutive)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC721Royalty) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
