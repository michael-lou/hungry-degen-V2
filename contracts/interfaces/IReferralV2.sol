// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title IReferralV2
 * @dev Interface for the enhanced referral system
 */
interface IReferralV2 {
    
    // 产品类型枚举
    enum ProductType {
        FOOD_PACK,           // 0.25% ETH
        CORE_PACK,           // 5% DUST
        FLEX_PACK,           // 5% ETH
        FLEX_PACK_DUST,      // 5% DUST (用DUST购买的Flex Pack)
        CHARACTER_NFT,       // 12%/20% ETH + Gold DXP
        BLACKGHOST_NFT       // 12%/20% ETH + Silver DXP
    }
    
    // 用户推荐统计概览
    struct UserReferralSummary {
        // 基础数据
        uint256 totalReferrals;
        uint256 totalETHEarned;
        uint256 totalDUSTEarned;
        address referrer; // 谁推荐了这个用户
        
        // 详细收入分类
        uint256 ethFromCharacterNFT;    // Character NFT销售ETH奖励
        uint256 ethFromBlackGhostNFT;   // BlackGhost NFT销售ETH奖励
        uint256 ethFromFoodPacks;       // Food Pack销售ETH奖励
        uint256 ethFromFlexPacks;       // Flex Pack销售ETH奖励
        uint256 dustFromCorePacks;      // Core Pack销售DUST奖励
        uint256 dustFromFlexPackDust;   // Flex Pack(DUST支付)销售DUST奖励
        
        // DXP积分数据
        uint256 goldDXPEarned;
        uint256 silverDXPEarned;
        uint256 goldDXPBalance;         // 当前余额
        uint256 silverDXPBalance;       // 当前余额
        
        // 白名单状态
        bool isWhitelisted;
        uint256 nftCommissionRate;      // 12% or 20%
    }
    
    // ======== 核心功能 ========
    
    /**
     * @dev 记录销售并分发奖励
     * @param buyer 购买者地址
     * @param referrer 推荐人地址
     * @param productType 产品类型
     * @param amount 销售金额
     * @return success 是否成功分发奖励
     */
    function recordSaleAndDistributeRewards(
        address buyer,
        address referrer,
        ProductType productType,
        uint256 amount
    ) external returns (bool success);
    
    /**
     * @dev 注册推荐关系
     * @param user 用户地址
     * @param referrer 推荐人地址
     */
    function registerReferral(address user, address referrer) external;
    
    // ======== 查询功能 ========
    
    /**
     * @dev 获取用户完整的推荐统计信息
     * @param user 用户地址
     * @return summary 用户推荐统计概览
     */
    function getUserReferralSummary(address user) external view returns (UserReferralSummary memory summary);
    
    /**
     * @dev 获取用户可提取的奖励
     * @param user 用户地址
     * @return ethAmount 可提取的ETH数量
     * @return dustAmount 可提取的DUST数量
     * @return goldDXPAmount 可提取的Gold DXP数量
     * @return silverDXPAmount 可提取的Silver DXP数量
     */
    function getClaimableRewards(address user) external view returns (
        uint256 ethAmount,
        uint256 dustAmount,
        uint256 goldDXPAmount,
        uint256 silverDXPAmount
    );
    
    /**
     * @dev 获取推荐人
     * @param user 用户地址
     * @return referrer 推荐人地址
     */
    function getReferrer(address user) external view returns (address referrer);
    
    /**
     * @dev 获取推荐数量
     * @param referrer 推荐人地址
     * @return count 推荐数量
     */
    function getReferralCount(address referrer) external view returns (uint256 count);
    
    /**
     * @dev 检查是否为玩家
     * @param addr 地址
     * @return isPlayer 是否为玩家
     */
    function checkIsPlayer(address addr) external view returns (bool isPlayer);
    
    /**
     * @dev 检查是否在白名单中
     * @param user 用户地址
     * @return isWhitelisted 是否在白名单中
     * @return commissionRate 佣金率
     */
    function isWhitelisted(address user) external view returns (bool isWhitelisted, uint256 commissionRate);
    
    // ======== 用户功能 ========
    
    /**
     * @dev 提取奖励
     */
    function claimRewards() external;
    
    // ======== 事件 ========
    
    event ReferralRegistered(address indexed user, address indexed referrer);
    event PlayerRegistered(address indexed player);
    event RewardsDistributed(
        address indexed referrer,
        address indexed buyer,
        ProductType indexed productType,
        uint256 ethAmount,
        uint256 dustAmount,
        uint256 goldDXPAmount,
        uint256 silverDXPAmount
    );
    event RewardsClaimed(
        address indexed referrer,
        uint256 ethAmount,
        uint256 dustAmount,
        uint256 goldDXPAmount,
        uint256 silverDXPAmount
    );
}
