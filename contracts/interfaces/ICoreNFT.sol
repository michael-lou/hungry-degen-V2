// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ICoreNFT {
    struct Core {
        uint8 characterType;
        uint8 rarity;
        uint8 level;
        uint8 wear;
        uint8 part;
        uint8 set;
        bytes attributes;
        string metadataUri;
    }

    function mint(address to, uint8 characterType, uint8 rarity) external returns (uint256, string memory);

    function getCoreInfo(uint256 tokenId) external view returns (Core memory);

    function ownerOf(uint256 tokenId) external view returns (address);

    function updateLevel(uint256 tokenId, uint8 newLevel) external;

    function updateWear(uint256 tokenId, uint8 newWear) external;

    function burn(uint256 tokenId) external;

    function transferFrom(address from, address to, uint256 tokenId) external;

    function getLevel(uint256 tokenId) external view returns (uint8);

    function getWear(uint256 tokenId) external view returns (uint8);

    function getRarity(uint256 tokenId) external view returns (uint8);
}
