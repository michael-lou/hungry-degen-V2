// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DXPToken.sol";

/**
 * @title GoldDXPToken
 * @dev Gold DXP token earned from Character NFT sales
 * Can be used to upgrade all character NFTs (except BlackGhost)
 */
contract GoldDXPToken is DXPToken {
    
    function initialize() public initializer {
        __DXPToken_init(
            "Gold DXP",
            "GDXP",
            2000 ether, // 1 ETH = 2000 GDXP (初始汇率)
            1000         // 10% 白名单奖励
        );
    }
    
    /**
     * @dev 获取代币类型信息
     */
    function getTokenInfo() external pure returns (string memory tokenType, string memory description) {
        return (
            "Gold DXP",
            "Earned from Character NFT sales. Can upgrade all characters except BlackGhost."
        );
    }
}
