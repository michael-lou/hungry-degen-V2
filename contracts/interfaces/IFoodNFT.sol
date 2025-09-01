// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IFoodNFT {
    struct Food {
        uint8 rarity;
        string name;
        uint256 value;
        uint256 exp;
    }

    function transferFrom(address from, address to, uint256 tokenId) external;
    function mint(address to, uint256 id) external returns (uint256);
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external;
    function burn(address from, uint256 id) external;
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external;
    function getRarity(uint256 tokenId) external view returns (uint8);
    function getName(uint256 tokenId) external view returns (string memory);
    function getValue(uint256 tokenId) external view returns (uint256);
    function getExp(uint256 tokenId) external view returns (uint256);
    function getFoodInfo(uint256 tokenId) external view returns (Food memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account, uint256 id ) external view returns (uint256);
}