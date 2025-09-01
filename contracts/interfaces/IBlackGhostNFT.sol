// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IBlackGhostNFT {
    function updateLevelAndExp(uint256 tokenId, uint8 newLevel, uint256 newExp) external;
    function getExp(uint256 tokenId) external view returns (uint256);
    function getLevel(uint256 tokenId) external view returns (uint8);
    function ownerOf(uint256 tokenId) external view returns (address);
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function transferFrom(address from, address to, uint256 tokenId) external;
    function totalSupply() external view returns (uint256);
    function mint(
        address to,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external returns (uint256);
    
    function adminMint(
        address to,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external returns (uint256);
    
    function batchAdminMint(
        address to,
        uint256 quantity,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external returns (uint256[] memory);
}
