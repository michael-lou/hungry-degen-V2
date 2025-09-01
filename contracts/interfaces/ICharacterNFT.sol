// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ICoreNFT.sol";
import "./IFlexNFT.sol";

interface ICharacterNFT {
    struct Character {
        uint8 character;
        uint8 rarity; // 0=Common, 1=Uncommon, 2=Rare, 3=Epic, 4=Legendary, 5=Mythic
        uint8 level; // 1-10
        uint256 exp; // 经验值
        ICoreNFT.Core[] accessories; // 装备的配饰
        IFlexNFT.Flex[] flexes; // 装备的道具
        bytes attributes;
        string metadataUri; // 元数据URI
    }

    function ownerOf(uint256 tokenId) external view returns (address);

    function transferFrom(address from, address to, uint256 tokenId) external;

    function safeTransferFrom(address from, address to, uint256 tokenId) external;

    function mint(
        address to,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external returns (uint256);

    function getLevel(uint256 tokenId) external view returns (uint8);

    function getExp(uint256 tokenId) external view returns (uint256);

    function getRarity(uint256 tokenId) external view returns (uint8);

    function getEquippedAccessories(uint256 tokenId) external view returns (uint256[] memory);

    function getEquippedFlexes(uint256 tokenId) external view returns (uint256[] memory);

    function updateLevelAndExp(uint256 tokenId, uint8 newLevel, uint256 newExp) external;

    function equipCore(uint256 tokenId, uint256 coreId) external;

    function equipFlex(uint256 tokenId, uint256 flexId) external;

    function unequipCore(uint256 tokenId, uint256 coreId) external;

    function unequipFlex(uint256 tokenId, uint256 flexId) external;

    function getCharacterInfo(uint256 tokenId) external view returns (Character memory, ICoreNFT.Core[] memory, IFlexNFT.Flex[] memory);

    function totalSupply() external view returns (uint256);

    function openedBoxes(uint256 tokenId) external view returns (bool);

    function getCharacterType(uint256 tokenId) external view returns (uint8);
    
    function getOwnedTokens(address _owner) external view returns (uint256[] memory);
}
