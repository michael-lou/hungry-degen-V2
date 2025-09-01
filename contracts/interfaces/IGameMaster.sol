// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IGameMaster {
    function calculateCharacterWeight(uint256 characterId) external view returns (uint256);
    function feedCharacter(uint256 characterId, uint256 foodId) external;
    function composeCore(uint256 tokenId1, uint256 tokenId2) external;
    function composeFlex(uint256 tokenId1, uint256 tokenId2) external;
    function repairCore(uint256 coreId) external;
    function repairFlex(uint256 flexId) external;
    function authorizedContracts(address) external view returns (bool);
    function batchUnequip(uint256 characterId, uint256[] calldata coreIds, uint256[] calldata flexIds) external;
    function updateTotalWeight(uint256 oldWeight, uint256 newWeight) external;
    function updateAccumulatorAndRewardDebt(uint256 characterId) external;
}