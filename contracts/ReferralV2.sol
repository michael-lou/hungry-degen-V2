// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IReferral.sol";
import "./interfaces/IDUSTToken.sol";
import "./tokens/GoldDXPToken.sol";
import "./tokens/SilverDXPToken.sol";

/**
 * @title ReferralV2
 * @dev Enhanced referral system with multi-currency rewards and detailed tracking
 */
contract ReferralV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    
    // 产品类型枚举
    enum ProductType {
        FOOD_PACK,           // 0.25% ETH
        CORE_PACK,           // 5% DUST
        FLEX_PACK,           // 5% ETH
        FLEX_PACK_DUST,      // 5% DUST (用DUST购买的Flex Pack)
        CHARACTER_NFT,       // Gold DXP (不发放ETH)
        BLACKGHOST_NFT       // Silver DXP (不发放ETH)
    }
    
    // 推荐人详细统计数据
    struct ReferrerStats {
        uint256 ethFromCharacterNFT;
        uint256 ethFromBlackGhostNFT;
        uint256 ethFromFoodPacks;
        uint256 ethFromFlexPacks;
        uint256 dustFromCorePacks;
        uint256 dustFromFlexPackDust;
        uint256 goldDXPEarned;
        uint256 silverDXPEarned;
        
        // 待提取奖励
        uint256 pendingETH;
        uint256 pendingDUST;
        uint256 pendingGoldDXP;
        uint256 pendingSilverDXP;
    }
    
    // 白名单信息
    struct WhitelistInfo {
        bool isWhitelisted;
        uint256 nftCommissionRate; // 12% or 20%
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
    
    // 奖励计算结果
    struct RewardCalculation {
        uint256 ethAmount;
        uint256 dustAmount;
        uint256 goldDXPAmount;
        uint256 silverDXPAmount;
    }
    
    // 状态变量
    IReferral public legacyReferral; // 兼容旧系统
    IDUSTToken public dustToken;
    GoldDXPToken public goldDXPToken;
    SilverDXPToken public silverDXPToken;
    address payable public treasury;
    
    // 推荐关系（兼容原系统）
    mapping(address => address) public referrers;
    mapping(address => uint256) public referralCount;
    // 注意：移除了 isPlayer 映射，任何用户都可以作为推荐人
    
    // 详细统计数据
    mapping(address => ReferrerStats) public referrerStats;
    
    // 白名单信息
    mapping(address => WhitelistInfo) public whitelistInfo;
    
    // 授权的marketplace合约
    mapping(address => bool) public authorizedMarketplaces;
    
    // 各产品的佣金率配置 (basis points, 10000 = 100%)
    mapping(ProductType => uint256) public commissionRates;
    
    // DXP奖励比例配置 (basis points, 10000 = 100%)
    mapping(ProductType => uint256) public dxpRewardRates;
    
    // 系统启用状态
    bool public systemEnabled;
    
    // 事件
    event ReferralRegistered(address indexed user, address indexed referrer);
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
    event WhitelistUpdated(address indexed user, bool status, uint256 commissionRate);
    event MarketplaceAuthorized(address indexed marketplace, bool authorized);
    event CommissionRateUpdated(ProductType productType, uint256 rate);
    event DXPRewardRateUpdated(ProductType productType, uint256 rate);
    event SystemEnabledUpdated(bool enabled);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    
    modifier onlyAuthorizedMarketplace() {
        require(authorizedMarketplaces[msg.sender], "ReferralV2: Not authorized marketplace");
        _;
    }
    
    modifier onlyWhenEnabled() {
        require(systemEnabled, "ReferralV2: System disabled");
        _;
    }
    
    function initialize(
        address _owner,
        address _dustToken,
        address payable _goldDXPToken,
        address payable _silverDXPToken,
        address _legacyReferral,
        address payable _treasury
    ) public initializer {
        __Ownable_init(_owner);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        legacyReferral = IReferral(_legacyReferral);
        dustToken = IDUSTToken(_dustToken);
        goldDXPToken = GoldDXPToken(_goldDXPToken);
        silverDXPToken = SilverDXPToken(_silverDXPToken);
        treasury = _treasury;
        
        systemEnabled = true;
        
        // 设置默认佣金率
        commissionRates[ProductType.FOOD_PACK] = 25;      // 0.25%
        commissionRates[ProductType.CORE_PACK] = 500;     // 5%
        commissionRates[ProductType.FLEX_PACK] = 500;     // 5%
        commissionRates[ProductType.FLEX_PACK_DUST] = 500; // 5%
        commissionRates[ProductType.CHARACTER_NFT] = 1200; // 12%
        commissionRates[ProductType.BLACKGHOST_NFT] = 1200; // 12%
        
        // 设置默认DXP奖励率
        dxpRewardRates[ProductType.CHARACTER_NFT] = 1000;   // 10% 的销售额转为Gold DXP
        dxpRewardRates[ProductType.BLACKGHOST_NFT] = 1000;  // 10% 的销售额转为Silver DXP
    }
    
    // ======== 管理员配置功能 ========
    
    function setMarketplaceAuthorization(address marketplace, bool authorized) external onlyOwner {
        require(marketplace != address(0), "ReferralV2: Invalid marketplace address");
        authorizedMarketplaces[marketplace] = authorized;
        emit MarketplaceAuthorized(marketplace, authorized);
    }
    
    function setCommissionRate(ProductType productType, uint256 rate) external onlyOwner {
        require(rate <= 3000, "ReferralV2: Commission rate too high"); // 最大30%
        commissionRates[productType] = rate;
        emit CommissionRateUpdated(productType, rate);
    }
    
    function setDXPRewardRate(ProductType productType, uint256 rate) external onlyOwner {
        require(rate <= 2000, "ReferralV2: DXP reward rate too high"); // 最大20%
        dxpRewardRates[productType] = rate;
        emit DXPRewardRateUpdated(productType, rate);
    }
    
    function setWhitelist(address user, bool status, uint256 nftCommissionRate) external onlyOwner {
        require(user != address(0), "ReferralV2: Invalid user address");
        require(nftCommissionRate <= 3000, "ReferralV2: Commission rate too high");
        
        whitelistInfo[user] = WhitelistInfo({
            isWhitelisted: status,
            nftCommissionRate: nftCommissionRate
        });
        
        emit WhitelistUpdated(user, status, nftCommissionRate);
    }
    
    function setSystemEnabled(bool enabled) external onlyOwner {
        systemEnabled = enabled;
        emit SystemEnabledUpdated(enabled);
    }
    
    function setTreasury(address payable _treasury) external onlyOwner {
        require(_treasury != address(0), "ReferralV2: Invalid treasury address");
        address oldTreasury = treasury;
        treasury = _treasury;
        emit TreasuryUpdated(oldTreasury, _treasury);
    }
    
    // ======== 推荐关系管理 ========
    
    function registerReferral(address user, address referrer) external onlyAuthorizedMarketplace {
        require(user != address(0), "ReferralV2: Invalid user address");
        require(referrer != address(0), "ReferralV2: Invalid referrer address");
        require(user != referrer, "ReferralV2: Self-referral not allowed");
        require(referrers[user] == address(0), "ReferralV2: User already has referrer");
        
        referrers[user] = referrer;
        referralCount[referrer]++;
        
        emit ReferralRegistered(user, referrer);
    }
    
    // ======== 奖励分发核心功能 ========
    
    function recordSaleAndDistributeRewards(
        address buyer,
        address referrer,
        ProductType productType,
        uint256 amount
    ) external onlyAuthorizedMarketplace onlyWhenEnabled nonReentrant returns (bool) {
        if (referrer == address(0) || referrer == buyer) {
            return false;
        }
        
        // 计算奖励
        RewardCalculation memory rewards = _calculateRewards(productType, amount, referrer);
        
        // 分发奖励
        _distributeRewards(buyer, referrer, rewards);
        
        // 记录详细统计数据
        _recordDetailedStats(referrer, productType, amount, rewards);
        
        // 更新推荐关系（如果是新关系）
        if (referrers[buyer] == address(0)) {
            referrers[buyer] = referrer;
            referralCount[referrer]++;
            emit ReferralRegistered(buyer, referrer);
        }
        
        emit RewardsDistributed(
            referrer,
            buyer,
            productType,
            rewards.ethAmount,
            rewards.dustAmount,
            rewards.goldDXPAmount,
            rewards.silverDXPAmount
        );
        
        return true;
    }
    
    // ======== 内部奖励计算和分发功能 ========
    
    function _calculateRewards(
        ProductType productType,
        uint256 amount,
        address referrer
    ) internal view returns (RewardCalculation memory rewards) {
        uint256 baseRate = commissionRates[productType];
        
        // 检查是否为NFT类型且用户在白名单中
        if ((productType == ProductType.CHARACTER_NFT || productType == ProductType.BLACKGHOST_NFT) 
            && whitelistInfo[referrer].isWhitelisted) {
            baseRate = whitelistInfo[referrer].nftCommissionRate;
        }
        
        if (productType == ProductType.FOOD_PACK || 
            productType == ProductType.FLEX_PACK) {
            // ETH奖励
            rewards.ethAmount = (amount * baseRate) / 10000;
        } else if (productType == ProductType.CORE_PACK || 
                   productType == ProductType.FLEX_PACK_DUST) {
            // DUST奖励
            rewards.dustAmount = (amount * baseRate) / 10000;
        } else if (productType == ProductType.CHARACTER_NFT) {
            // 仅 Gold DXP奖励 (不发放ETH)
            rewards.goldDXPAmount = (amount * dxpRewardRates[productType]) / 10000;
        } else if (productType == ProductType.BLACKGHOST_NFT) {
            // 仅 Silver DXP奖励 (不发放ETH)
            rewards.silverDXPAmount = (amount * dxpRewardRates[productType]) / 10000;
        }
        
        return rewards;
    }
    
    function _distributeRewards(
        address /* buyer */,
        address referrer,
        RewardCalculation memory rewards
    ) internal {
        // 分发ETH奖励
        if (rewards.ethAmount > 0) {
            referrerStats[referrer].pendingETH += rewards.ethAmount;
        }
        
        // 分发DUST奖励
        if (rewards.dustAmount > 0) {
            referrerStats[referrer].pendingDUST += rewards.dustAmount;
        }
        
        // 铸造并分发Gold DXP
        if (rewards.goldDXPAmount > 0) {
            goldDXPToken.mint(address(this), rewards.goldDXPAmount);
            referrerStats[referrer].pendingGoldDXP += rewards.goldDXPAmount;
        }
        
        // 铸造并分发Silver DXP
        if (rewards.silverDXPAmount > 0) {
            silverDXPToken.mint(address(this), rewards.silverDXPAmount);
            referrerStats[referrer].pendingSilverDXP += rewards.silverDXPAmount;
        }
    }
    
    function _recordDetailedStats(
        address referrer,
        ProductType productType,
        uint256 /* amount */,
        RewardCalculation memory rewards
    ) internal {
        ReferrerStats storage stats = referrerStats[referrer];
        
        // 根据产品类型记录对应的收入
        if (productType == ProductType.CHARACTER_NFT) {
            // 仅记录 Gold DXP 奖励 (不记录ETH)
            stats.goldDXPEarned += rewards.goldDXPAmount;
        } else if (productType == ProductType.BLACKGHOST_NFT) {
            // 仅记录 Silver DXP 奖励 (不记录ETH)
            stats.silverDXPEarned += rewards.silverDXPAmount;
        } else if (productType == ProductType.FOOD_PACK) {
            stats.ethFromFoodPacks += rewards.ethAmount;
        } else if (productType == ProductType.FLEX_PACK) {
            stats.ethFromFlexPacks += rewards.ethAmount;
        } else if (productType == ProductType.CORE_PACK) {
            stats.dustFromCorePacks += rewards.dustAmount;
        } else if (productType == ProductType.FLEX_PACK_DUST) {
            stats.dustFromFlexPackDust += rewards.dustAmount;
        }
    }
    
    // ======== 奖励提取功能 ========
    
    function claimRewards() external nonReentrant {
        ReferrerStats storage stats = referrerStats[msg.sender];
        
        uint256 ethAmount = stats.pendingETH;
        uint256 dustAmount = stats.pendingDUST;
        uint256 goldDXPAmount = stats.pendingGoldDXP;
        uint256 silverDXPAmount = stats.pendingSilverDXP;
        
        require(ethAmount > 0 || dustAmount > 0 || goldDXPAmount > 0 || silverDXPAmount > 0,
                "ReferralV2: No rewards to claim");
        
        // 清零待提取奖励
        stats.pendingETH = 0;
        stats.pendingDUST = 0;
        stats.pendingGoldDXP = 0;
        stats.pendingSilverDXP = 0;
        
        // 发放ETH
        if (ethAmount > 0) {
            require(address(this).balance >= ethAmount, "ReferralV2: Insufficient ETH balance");
            (bool success, ) = payable(msg.sender).call{ value: ethAmount }("");
            require(success, "ReferralV2: ETH transfer failed");
        }
        
        // 发放DUST
        if (dustAmount > 0) {
            require(dustToken.balanceOf(address(this)) >= dustAmount, "ReferralV2: Insufficient DUST balance");
            require(dustToken.transfer(msg.sender, dustAmount), "ReferralV2: DUST transfer failed");
        }
        
        // 发放Gold DXP
        if (goldDXPAmount > 0) {
            require(goldDXPToken.balanceOf(address(this)) >= goldDXPAmount, "ReferralV2: Insufficient Gold DXP balance");
            require(goldDXPToken.transfer(msg.sender, goldDXPAmount), "ReferralV2: Gold DXP transfer failed");
        }
        
        // 发放Silver DXP
        if (silverDXPAmount > 0) {
            require(silverDXPToken.balanceOf(address(this)) >= silverDXPAmount, "ReferralV2: Insufficient Silver DXP balance");
            require(silverDXPToken.transfer(msg.sender, silverDXPAmount), "ReferralV2: Silver DXP transfer failed");
        }
        
        emit RewardsClaimed(msg.sender, ethAmount, dustAmount, goldDXPAmount, silverDXPAmount);
    }
    
    // ======== 查询功能 ========
    
    function getUserReferralSummary(address user) external view returns (UserReferralSummary memory summary) {
        // 获取基础推荐数据
        summary.referrer = referrers[user];
        summary.totalReferrals = referralCount[user];
        
        // 获取详细收入数据
        ReferrerStats storage stats = referrerStats[user];
        summary.totalETHEarned = stats.ethFromCharacterNFT + 
                               stats.ethFromBlackGhostNFT + 
                               stats.ethFromFoodPacks + 
                               stats.ethFromFlexPacks;
        
        summary.totalDUSTEarned = stats.dustFromCorePacks + 
                                stats.dustFromFlexPackDust;
        
        // 分类收入
        summary.ethFromCharacterNFT = stats.ethFromCharacterNFT;
        summary.ethFromBlackGhostNFT = stats.ethFromBlackGhostNFT;
        summary.ethFromFoodPacks = stats.ethFromFoodPacks;
        summary.ethFromFlexPacks = stats.ethFromFlexPacks;
        summary.dustFromCorePacks = stats.dustFromCorePacks;
        summary.dustFromFlexPackDust = stats.dustFromFlexPackDust;
        
        // DXP数据
        summary.goldDXPEarned = stats.goldDXPEarned;
        summary.silverDXPEarned = stats.silverDXPEarned;
        summary.goldDXPBalance = goldDXPToken.balanceOf(user);
        summary.silverDXPBalance = silverDXPToken.balanceOf(user);
        
        // 白名单状态
        WhitelistInfo storage whitelist = whitelistInfo[user];
        summary.isWhitelisted = whitelist.isWhitelisted;
        summary.nftCommissionRate = whitelist.nftCommissionRate;
        
        return summary;
    }
    
    function getClaimableRewards(address user) external view returns (
        uint256 ethAmount,
        uint256 dustAmount,
        uint256 goldDXPAmount,
        uint256 silverDXPAmount
    ) {
        ReferrerStats storage stats = referrerStats[user];
        return (
            stats.pendingETH,
            stats.pendingDUST,
            stats.pendingGoldDXP,
            stats.pendingSilverDXP
        );
    }
    
    function getReferrer(address user) external view returns (address) {
        return referrers[user];
    }
    
    function getReferralCount(address referrer) external view returns (uint256) {
        return referralCount[referrer];
    }
    
    function checkIsPlayer(address addr) external pure returns (bool) {
        // 由于移除了 player 概念，任何地址都被视为有效用户
        return addr != address(0);
    }
    
    function isWhitelisted(address user) external view returns (bool, uint256) {
        WhitelistInfo storage info = whitelistInfo[user];
        return (info.isWhitelisted, info.nftCommissionRate);
    }
    
    // ======== 数据迁移功能 ========
    
    function migrateLegacyData(address[] calldata users) external onlyOwner {
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            
            // 迁移推荐关系
            address legacyReferrer = legacyReferral.getReferrer(user);
            if (legacyReferrer != address(0) && referrers[user] == address(0)) {
                referrers[user] = legacyReferrer;
            }
            
            // 迁移推荐数量
            uint256 legacyCount = legacyReferral.getReferralCount(user);
            if (legacyCount > referralCount[user]) {
                referralCount[user] = legacyCount;
            }
            
            // 注意：不再迁移 player 状态，因为任何用户都可以参与推荐系统
        }
    }
    
    // ======== 紧急功能 ========
    
    function emergencyWithdraw() external onlyOwner {
        // 提取ETH
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            (bool success, ) = payable(owner()).call{ value: ethBalance }("");
            require(success, "ReferralV2: ETH withdrawal failed");
        }
        
        // 提取DUST
        uint256 dustBalance = dustToken.balanceOf(address(this));
        if (dustBalance > 0) {
            require(dustToken.transfer(owner(), dustBalance), "ReferralV2: DUST withdrawal failed");
        }
        
        // 提取Gold DXP
        uint256 goldDXPBalance = goldDXPToken.balanceOf(address(this));
        if (goldDXPBalance > 0) {
            require(goldDXPToken.transfer(owner(), goldDXPBalance), "ReferralV2: Gold DXP withdrawal failed");
        }
        
        // 提取Silver DXP
        uint256 silverDXPBalance = silverDXPToken.balanceOf(address(this));
        if (silverDXPBalance > 0) {
            require(silverDXPToken.transfer(owner(), silverDXPBalance), "ReferralV2: Silver DXP withdrawal failed");
        }
    }
    
    // ======== UUPS升级 ========
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // 接收ETH
    receive() external payable {}
}