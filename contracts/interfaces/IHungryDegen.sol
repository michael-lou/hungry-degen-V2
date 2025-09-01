// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IHungryDegen {
    struct StakeInfo {
        uint256 startBlock;
        uint256 lastClaimBlock;
    }

    function stakedCharacters(uint256 characterId) external view returns (StakeInfo memory);
    function stakedCharactersByOwner(address owner, uint256 index) external view returns (uint256);
    function totalStakedCharacters() external view returns (uint256);
    function totalWeight() external view returns (uint256);
    function authorizedCallers(address) external view returns (bool);
    function stake(uint256 characterId) external;
    function unstake(uint256 characterId) external;
    function claimRewards(uint256 characterId) external;
    function claimAllRewards() external;
    function isStaked(uint256 characterId) external view returns (bool);
    function wasStakedByUser(address user, uint256 characterId) external view returns (bool);
    function getStakedCharacters(address user) external view returns (uint256[] memory);
    function updateAccumulatorAndRewardDebt(uint256 characterId) external;
    function updateTotalWeight(uint256 oldWeight, uint256 newWeight) external;
}