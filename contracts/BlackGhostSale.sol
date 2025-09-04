// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./BlackGhostNFT.sol";
import "./interfaces/IReferralV2.sol";

contract BlackGhostSale is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    BlackGhostNFT public blackGhostNFT;

    // 销售阶段枚举
    enum SalePhase {
        EARLY_BIRD,
        PUBLIC_SALE
    }

    // Black Ghost 配置
    uint8 public constant BLACK_GHOST_CHARACTER_TYPE = 6;
    uint8 public constant BLACK_GHOST_RARITY = 1;
    string public blackGhostMetadataUri;

    // 销售配置
    uint256 public price;
    uint256 public maxSupply;
    uint256 public currentSupply;
    address public treasury; // Treasury 钱包地址

    // 阶段管理
    SalePhase public currentPhase;
    uint256 public phase2StartTime; // 第二阶段开始时间

    uint256 public EarlyBirdPurchaseLimit;
    // 第一阶段折扣配置 (基于 10000，例如 1000 = 10%, 8000 = 80%)
    uint256 public characterHolderDiscount; // Character NFT holder 1折优惠
    uint256 public generalEarlyDiscount; // 普通用户8折优惠
    mapping(address => uint256) public whitelistDiscounts; // 白名单地址的折扣
    mapping(address => bool) public phase1Purchased; // 第一阶段购买记录

    // 第二阶段配置
    uint256 public maxPerWalletPhase2; // 每个钱包最多购买数量
    mapping(address => uint256) public phase2PurchaseCount; // 第二阶段购买计数
    uint256 public resetCostInDust; // 重置费用(DUST代币)

    // 相关合约地址
    address public characterNFT; // Character NFT 合约地址
    address public dustToken; // DUST 代币合约地址
    IReferralV2 public referralV2; // 推荐系统合约

    // 事件
    event BlackGhostPurchased(address indexed buyer, uint256[] tokenId, uint256 price, SalePhase phase);
    event SaleConfigUpdated(uint256 price, uint256 maxSupply);
    event MetadataUpdated(string newMetadataUri);
    event TreasuryUpdated(address indexed newTreasury);
    event PhaseChanged(SalePhase newPhase);
    event Phase2StartTimeUpdated(uint256 newStartTime);
    event DiscountConfigUpdated(uint256 characterHolderDiscount, uint256 generalEarlyDiscount);
    event WhitelistUpdated(address indexed user, uint256 discount);
    event PurchaseLimitReset(address indexed user);
    event characterNFTUpdated(address indexed newCharacterNFT);
    event DustTokenUpdated(address indexed newDustToken);
    event ReferralV2Updated(address indexed newReferralV2);

    modifier onlySaleActive() {
        require(currentSupply < maxSupply, "BlackGhostSale: Sold out");
        _;
    }

    modifier autoPhaseUpdate() {
        _updatePhase();
        _;
    }

    function initialize(
        address _blackGhostNFT,
        string memory _blackGhostMetadataUri,
        uint256 _price,
        uint256 _maxSupply,
        address _treasury,
        uint256 _phase2StartTime
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        require(_blackGhostNFT != address(0), "BlackGhostSale: Invalid BlackGhostNFT address");
        require(_maxSupply > 0, "BlackGhostSale: Invalid max supply");
        require(_price > 0, "BlackGhostSale: Invalid price");
        require(_treasury != address(0), "BlackGhostSale: Invalid treasury address");
        require(_phase2StartTime > block.timestamp, "BlackGhostSale: Phase2 start time must be in future");

        blackGhostNFT = BlackGhostNFT(_blackGhostNFT);
        blackGhostMetadataUri = _blackGhostMetadataUri;
        price = _price;
        maxSupply = _maxSupply;
        treasury = _treasury;
        currentSupply = 0;

        EarlyBirdPurchaseLimit = 1;

        // 设置阶段和时间
        currentPhase = SalePhase.EARLY_BIRD;
        phase2StartTime = _phase2StartTime;

        // 设置默认折扣
        characterHolderDiscount = 1000; // 10% (1折)
        generalEarlyDiscount = 8000; // 80% (8折)
        maxPerWalletPhase2 = 3; // 第二阶段每个钱包最多3只
        resetCostInDust = 1000 * 10 ** 18; // 1000 DUST (假设18位小数)
    }

    // 第一阶段购买函数
    function purchaseEarlyBird(
        uint256 quantity,
        address referrerAddress
    ) external payable nonReentrant whenNotPaused onlySaleActive autoPhaseUpdate {
        require(currentPhase == SalePhase.EARLY_BIRD, "BlackGhostSale: Not in early bird phase");
        require(!phase1Purchased[msg.sender], "BlackGhostSale: Already purchased in early bird phase");
        require(quantity <= EarlyBirdPurchaseLimit, "BlackGhostSale: Exceeds early bird purchase limit");
        require(currentSupply + quantity <= maxSupply, "BlackGhostSale: Exceeds max supply");

        uint256 discount = _getUserDiscount(msg.sender);
        uint256 discountedPrice = (price * discount) / 10000;
        uint256 totalPrice = discountedPrice * quantity;

        require(msg.value >= totalPrice, "BlackGhostSale: Insufficient payment");

        currentSupply++;
        phase1Purchased[msg.sender] = true;

        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = blackGhostNFT.mint(
                msg.sender,
                BLACK_GHOST_CHARACTER_TYPE,
                BLACK_GHOST_RARITY,
                "",
                blackGhostMetadataUri
            );
            tokenIds[i] = tokenId;
        }

        // 处理推荐奖励 - 使用新的ReferralV2系统
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }

            // 使用新的推荐系统 (Silver DXP奖励，不再发放ETH)
            referralV2.recordSaleAndDistributeRewards(
                msg.sender,
                currentReferrer,
                IReferralV2.ProductType.BLACKGHOST_NFT,
                totalPrice
            );
        }

        emit BlackGhostPurchased(msg.sender, tokenIds, totalPrice, SalePhase.EARLY_BIRD);

        // 将支付金额发送到 treasury
        (bool success, ) = payable(treasury).call{ value: totalPrice }("");
        require(success, "BlackGhostSale: Treasury transfer failed");

        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{ value: msg.value - totalPrice }("");
            require(refundSuccess, "BlackGhostSale: ETH refund failed");
        }
    }

    // 第二阶段购买函数
    function purchasePublic(
        uint256 quantity,
        address referrerAddress
    ) external payable nonReentrant whenNotPaused onlySaleActive autoPhaseUpdate {
        require(currentPhase == SalePhase.PUBLIC_SALE, "BlackGhostSale: Not in public phase");
        require(quantity > 0, "BlackGhostSale: Quantity must be greater than 0");
        require(
            phase2PurchaseCount[msg.sender] + quantity <= maxPerWalletPhase2,
            "BlackGhostSale: Exceeds max purchase limit"
        );
        require(currentSupply + quantity <= maxSupply, "BlackGhostSale: Exceeds max supply");

        uint256 totalPrice = price * quantity;
        require(msg.value >= totalPrice, "BlackGhostSale: Insufficient payment");

        currentSupply += quantity;
        phase2PurchaseCount[msg.sender] += quantity;

        // 批量铸造 NFT
        uint256[] memory tokenIds = new uint256[](quantity);
        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = blackGhostNFT.mint(
                msg.sender,
                BLACK_GHOST_CHARACTER_TYPE,
                BLACK_GHOST_RARITY,
                "",
                blackGhostMetadataUri
            );
            tokenIds[i] = tokenId;
        }

        // 处理推荐奖励 - 使用新的ReferralV2系统
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }

            // 使用新的推荐系统 (Silver DXP奖励，不再发放ETH)
            referralV2.recordSaleAndDistributeRewards(
                msg.sender,
                currentReferrer,
                IReferralV2.ProductType.BLACKGHOST_NFT,
                totalPrice
            );
        }

        emit BlackGhostPurchased(msg.sender, tokenIds, totalPrice, SalePhase.PUBLIC_SALE);

        // 将支付金额发送到 treasury
        (bool success, ) = payable(treasury).call{ value: totalPrice }("");
        require(success, "BlackGhostSale: Treasury transfer failed");

        // 退还多余的 ETH
        if (msg.value > totalPrice) {
            (bool refundSuccess, ) = payable(msg.sender).call{ value: msg.value - totalPrice }("");
            require(refundSuccess, "BlackGhostSale: ETH refund failed");
        }
    }

    // 重置第二阶段购买限额
    function resetPurchaseLimit() external nonReentrant autoPhaseUpdate {
        require(currentPhase == SalePhase.PUBLIC_SALE, "BlackGhostSale: Not in public sale phase");
        require(phase2PurchaseCount[msg.sender] > 0, "BlackGhostSale: Nothing to reset");

        IERC20(dustToken).transferFrom(msg.sender, treasury, resetCostInDust);
        phase2PurchaseCount[msg.sender] = 0;

        emit PurchaseLimitReset(msg.sender);
    }

    // 管理函数 - 更新销售配置
    function setCharacterNFT(address _characterNFT) external onlyOwner {
        require(_characterNFT != address(0), "BlackGhostSale: Invalid characterNFT address");
        characterNFT = _characterNFT;
        emit characterNFTUpdated(_characterNFT);
    }

    function setDustToken(address _dustToken) external onlyOwner {
        require(_dustToken != address(0), "BlackGhostSale: Invalid dustToken address");
        dustToken = _dustToken;
        emit DustTokenUpdated(_dustToken);
    }

    function setEarlyBirdPurchaseLimit(uint256 _limit) external onlyOwner {
        require(_limit > 0, "BlackGhostSale: Invalid limit");
        EarlyBirdPurchaseLimit = _limit;
    }

    function updateSaleConfig(uint256 _price, uint256 _maxSupply) external onlyOwner {
        require(_price > 0, "BlackGhostSale: Invalid price");
        require(_maxSupply >= currentSupply, "BlackGhostSale: Max supply cannot be less than current supply");

        price = _price;
        maxSupply = _maxSupply;

        emit SaleConfigUpdated(_price, _maxSupply);
    }

    // 设置第二阶段开始时间
    function setPhase2StartTime(uint256 _timestamp) external onlyOwner {
        require(_timestamp > block.timestamp, "BlackGhostSale: Time must be in future");
        phase2StartTime = _timestamp;
        emit Phase2StartTimeUpdated(_timestamp);
    }

    // 手动切换到第二阶段
    function switchToPhase2() external onlyOwner {
        require(currentPhase == SalePhase.EARLY_BIRD, "BlackGhostSale: Already in phase 2");
        currentPhase = SalePhase.PUBLIC_SALE;
        emit PhaseChanged(SalePhase.PUBLIC_SALE);
    }

    // 更新折扣配置
    function updateDiscountConfig(uint256 _characterHolderDiscount, uint256 _generalEarlyDiscount) external onlyOwner {
        require(_characterHolderDiscount <= 10000, "BlackGhostSale: Invalid character holder discount");
        require(_generalEarlyDiscount <= 10000, "BlackGhostSale: Invalid general early discount");

        characterHolderDiscount = _characterHolderDiscount;
        generalEarlyDiscount = _generalEarlyDiscount;

        emit DiscountConfigUpdated(_characterHolderDiscount, _generalEarlyDiscount);
    }

    // 批量设置白名单
    function setWhitelist(address[] calldata addresses, uint256[] calldata discounts) external onlyOwner {
        require(addresses.length == discounts.length, "BlackGhostSale: Arrays length mismatch");

        for (uint256 i = 0; i < addresses.length; i++) {
            require(discounts[i] <= 10000, "BlackGhostSale: Invalid discount");
            whitelistDiscounts[addresses[i]] = discounts[i];
            emit WhitelistUpdated(addresses[i], discounts[i]);
        }
    }

    // 移除白名单
    function removeFromWhitelist(address user) external onlyOwner {
        whitelistDiscounts[user] = 0;
        emit WhitelistUpdated(user, 0);
    }

    // 更新第二阶段配置
    function updatePhase2Config(uint256 _maxPerWallet, uint256 _resetCost) external onlyOwner {
        require(_maxPerWallet > 0, "BlackGhostSale: Invalid max per wallet");

        maxPerWalletPhase2 = _maxPerWallet;
        resetCostInDust = _resetCost;
    }

    /**
     * @dev 设置新的推荐系统合约地址
     * @param _referralV2 新的推荐系统合约地址
     */
    function setReferralV2(address _referralV2) external onlyOwner {
        referralV2 = IReferralV2(_referralV2);
        emit ReferralV2Updated(_referralV2);
    }

    // 内部函数 - 更新阶段
    function _updatePhase() internal {
        if (currentPhase == SalePhase.EARLY_BIRD && block.timestamp >= phase2StartTime) {
            currentPhase = SalePhase.PUBLIC_SALE;
            emit PhaseChanged(SalePhase.PUBLIC_SALE);
        }
    }

    // 内部函数 - 获取用户折扣
    function _getUserDiscount(address user) internal view returns (uint256) {
        // 检查是否为Character NFT holder (最大优惠)
        if (_isCharacterHolder(user)) {
            return characterHolderDiscount; // 1000 = 10%
        }

        // 检查白名单折扣
        uint256 whitelistDiscount = whitelistDiscounts[user];
        if (whitelistDiscount > 0) {
            return whitelistDiscount;
        }

        // 普通用户8折
        return generalEarlyDiscount; // 8000 = 80%
    }

    // 内部函数 - 检查是否为Character NFT holder
    function _isCharacterHolder(address user) internal view returns (bool) {
        if (characterNFT == address(0)) {
            return false;
        }
        return IERC721(characterNFT).balanceOf(user) > 0;
    }

    // 更新元数据URI
    function updateMetadataUri(string memory _newMetadataUri) external onlyOwner {
        blackGhostMetadataUri = _newMetadataUri;
        emit MetadataUpdated(_newMetadataUri);
    }

    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "BlackGhostSale: Invalid treasury address");
        treasury = _newTreasury;
        emit TreasuryUpdated(_newTreasury);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function adminMint(address to, uint256 quantity) external onlyOwner {
        require(to != address(0), "BlackGhostSale: Invalid recipient");
        require(quantity > 0 && quantity <= 100, "BlackGhostSale: Invalid quantity");
        require(currentSupply + quantity <= maxSupply, "BlackGhostSale: Exceeds max supply");

        currentSupply += quantity;

        for (uint256 i = 0; i < quantity; i++) {
            blackGhostNFT.mint(
                to,
                BLACK_GHOST_CHARACTER_TYPE,
                BLACK_GHOST_RARITY,
                "",
                blackGhostMetadataUri
            );
        }
    }

    function isSaleActive() external view returns (bool) {
        return currentSupply < maxSupply && !paused();
    }

    function getAvailableSupply() external view returns (uint256) {
        return maxSupply - currentSupply;
    }

    // 查询函数
    function hasUserPurchasedPhase1(address user) external view returns (bool) {
        return phase1Purchased[user];
    }

    function getUserPhase2PurchaseCount(address user) external view returns (uint256) {
        return phase2PurchaseCount[user];
    }

    function getUserDiscount(address user) external view returns (uint256) {
        return _getUserDiscount(user);
    }

    function getCurrentPhase() external view returns (SalePhase) {
        // 模拟阶段更新但不修改状态
        if (currentPhase == SalePhase.EARLY_BIRD && block.timestamp >= phase2StartTime) {
            return SalePhase.PUBLIC_SALE;
        }
        return currentPhase;
    }

    function getPhaseInfo()
        external
        view
        returns (
            SalePhase _currentPhase,
            uint256 _phase2StartTime,
            uint256 _characterHolderDiscount,
            uint256 _generalEarlyDiscount,
            uint256 _maxPerWalletPhase2,
            uint256 _resetCostInDust
        )
    {
        return (
            this.getCurrentPhase(),
            phase2StartTime,
            characterHolderDiscount,
            generalEarlyDiscount,
            maxPerWalletPhase2,
            resetCostInDust
        );
    }

    function getSaleStats()
        external
        view
        returns (uint256 _currentSupply, uint256 _maxSupply, uint256 _price, bool _isActive)
    {
        return (currentSupply, maxSupply, price, this.isSaleActive());
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
