// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IConfigCenter {
    function TOTAL_REWARD_PER_BLOCK() external view returns (uint256);
    function characterBaseWeight(uint8 level, uint8 rarity) external view returns (uint256);
    function multiplier(uint8 rarity, uint8 level) external view returns (uint256);
    function baseWearPerClaim() external view returns (uint8);
    function wearReductionByRarity() external view returns (uint8);
    function wearReductionByLevel() external view returns (uint8);
    function expRequiredForLevel(uint8 level) external view returns (uint256);
    function repairCostByRarityAndLevel(uint8 rarity, uint8 level) external view returns (uint256);
    function repairETHCostByRarityAndLevel(uint8 rarity, uint8 level) external view returns (uint256);
    function getExpForLevel(uint8 level) external view returns (uint256);
    function calculateLevel(uint256 exp) external view returns (uint8);
    function calculateWearIncrease(uint8 rarity, uint8 level) external view returns (uint8);
    function getRepairCost(uint8 rarity, uint8 level, uint8 wear) external view returns (uint256);
    function authorizedCallers(address) external view returns (bool);
    function getRewarder() external view returns (address);
    function getCharacterTypeMultiplier(uint8 characterType) external view returns (uint256);
    function repairByEth() external view returns (bool);
    function equipmentUpgradeMaterialAmount(uint8 rarity, uint8 level) external view returns (uint256);
    function calculateMaterialAmountToLevel(uint8 rarity, uint256 materialAmount) external view returns (uint8 ,uint256);

}