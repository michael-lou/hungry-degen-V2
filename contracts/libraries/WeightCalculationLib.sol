// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library WeightCalculationLib {
    function calculateBonus(
        function(uint256) external view returns (uint8) getLevelFn,
        function(uint256) external view returns (uint8) getRarityFn,
        function(uint256) external view returns (uint8) getWearFn,
        function(uint8,uint8) external view returns (uint256) multiplier,
        uint256[] memory Ids
    ) internal view returns (uint256) {
        if (Ids.length == 0) return 1000;

        uint256 totalMultiplier = 1000;

        for (uint256 i = 0; i < Ids.length; i++) {
            uint8 level = getLevelFn(Ids[i]);
            uint8 rarity = getRarityFn(Ids[i]);
            uint8 wear = getWearFn(Ids[i]);

            uint256 equipmentMultiplier = multiplier(rarity, level);
            uint256 effectiveWear = wear > 100 ? 100 : wear;
            uint256 adjustedMultiplier = (equipmentMultiplier * (1000 - effectiveWear * 10)) / 1000;
            
            if (adjustedMultiplier == 0) adjustedMultiplier = 1;
            
            if (totalMultiplier <= type(uint256).max / adjustedMultiplier) {
                totalMultiplier = (totalMultiplier * adjustedMultiplier) / 1000;
            } else {
                totalMultiplier = type(uint256).max / 1000;
            }
        }

        return totalMultiplier;
    }
}
