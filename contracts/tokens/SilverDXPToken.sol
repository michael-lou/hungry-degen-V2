// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DXPToken.sol";

/**
 * @title SilverDXPToken
 * @dev Silver DXP token earned from BlackGhost NFT sales
 * Can be used to upgrade specific character NFTs
 */
contract SilverDXPToken is DXPToken {
    
    function initialize() public initializer {
        __DXPToken_init(
            "Silver DXP",
            "SDXP",
            1500 ether, // 1 ETH = 1500 SDXP (初始汇率，比Gold DXP稍低)
            800          // 8% 白名单奖励
        );
    }
    
    /**
     * @dev 获取代币类型信息
     */
    function getTokenInfo() external pure returns (string memory tokenType, string memory description) {
        return (
            "Silver DXP",
            "Earned from BlackGhost NFT sales. Can upgrade specific characters."
        );
    }
}
