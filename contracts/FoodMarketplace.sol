// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseMarketplaceNoVRF.sol";
import "./interfaces/IFoodNFT.sol";
import "./interfaces/IReferralV2.sol";
import "./interfaces/IUserBalanceManager.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/EIP712Upgradeable.sol";

contract FoodMarketplace is BaseMarketplaceNoVRF, EIP712Upgradeable {
    using ECDSA for bytes32;
    
    // EIP-712 类型哈希
    bytes32 private constant RELAYER_MINT_TYPEHASH = 
        keccak256("RelayerMintData(address to,uint256 tokenId,uint256 nonce,uint256 deadline)");
    
    IFoodNFT public foodNFT;
    IReferralV2 public referralV2;
    IUserBalanceManager public balanceManager;
    address public payoutAddress; // 用于支付的地址
    uint256 public foodHDPrice;

    // Relayer签名mint相关状态变量
    address public relayerAddress;                    // 授权的relayer地址
    mapping(address => uint256) public nonces;        // 用户nonce映射
    mapping(bytes32 => bool) public usedSignatures;  // 已使用的签名哈希

    // 用户最后打开的食物信息
    struct FoodInfo {
        uint256 tokenId;
        uint8 rarity;
        string name;
        uint256 value;
        uint256 exp;
    }

    // Relayer签名mint数据结构
    struct RelayerMintData {
        address to;        // 接收者地址
        uint256 tokenId;   // 要mint的食物ID
        uint256 nonce;     // 防重放攻击的nonce
        uint256 deadline;  // 签名过期时间
    }

    mapping(address => FoodInfo[]) public userLastOpenedFood;

    // 预设的token ID序列
    uint256[] public tokenSequence;
    uint256 public currentSequenceIndex; // 当前序列位置

    event FoodPurchased(address indexed buyer, uint256 amount);
    event FoodOpened(address indexed opener, uint256[] tokenIds, uint8[] rarities);
    event FoodRecycled(address indexed owner, uint256[] foodIds, uint256 refundAmount);
    event PriceUpdated(uint256 price);
    event FoodBalanceAdded(address indexed user, uint256 amount);
    event AdminMint(address indexed user, uint256 tokenId);
    event RelayerMint(address indexed to, uint256 indexed tokenId, uint256 nonce);
    event RelayerAddressUpdated(address indexed oldRelayer, address indexed newRelayer);
    event TokenSequenceInitialized(uint256 expectedTotalLength);
    event TokenSequenceAppended(uint256 appendedCount, uint256 totalLength);
    event TokenSequenceFinalized(uint256 finalLength);

    function initialize(
        address _foodNFT,
        address payable _treasury,
        address _balanceManager
    ) public initializer {
        __BaseMarketplaceNoVRF_init(_treasury);
        __EIP712_init("FoodMarketplace", "1");
        foodNFT = IFoodNFT(_foodNFT);
        balanceManager = IUserBalanceManager(_balanceManager);
    }

    function updatePrice(uint256 price) external onlyOwner {
        require(price > 0, "FoodMarketplace: Price must be greater than 0");
        foodHDPrice = price;
        emit PriceUpdated(price);
    }

    function setFoodNFT(address _foodNFT) external onlyOwner {
        require(_foodNFT != address(0), "FoodMarketplace: Invalid address");
        foodNFT = IFoodNFT(_foodNFT);
    }

    function setReferralV2(address _referralV2) external onlyOwner {
        require(_referralV2 != address(0), "FoodMarketplace: Invalid referralV2 address");
        referralV2 = IReferralV2(_referralV2);
    }

    function setPayoutAddress(address _payoutAddress) external onlyOwner {
        require(_payoutAddress != address(0), "FoodMarketplace: Invalid payout address");
        payoutAddress = _payoutAddress;
    }

    function setRelayerAddress(address _relayerAddress) external onlyOwner {
        address oldRelayer = relayerAddress;
        relayerAddress = _relayerAddress;
        emit RelayerAddressUpdated(oldRelayer, _relayerAddress);
    }

    function buyFood(uint256 amount, address referrerAddress) external payable nonReentrant {
        require(amount > 0, "FoodMarketplace: Amount must be greater than 0");
        uint256 totalPrice = foodHDPrice * amount;
        require(msg.value >= totalPrice, "FoodMarketplace: Insufficient ETH sent");

        // 使用ReferralV2系统处理推荐奖励
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }
            
            referralV2.recordSaleAndDistributeRewards(
                msg.sender, 
                currentReferrer, 
                IReferralV2.ProductType.FOOD_PACK, 
                totalPrice
            );
            
            // 计算并转账给treasury（扣除推荐奖励后）
            uint256 treasuryAmount = totalPrice;
            if (currentReferrer != address(0)) {
                // FOOD_PACK的标准佣金率是0.25% = 25 basis points
                uint256 referralReward = (totalPrice * 25) / 10000;
                treasuryAmount = totalPrice - referralReward;
            }
            
            if (treasuryAmount > 0) {
                (bool treasurySuccess, ) = payable(treasury).call{ value: treasuryAmount }("");
                require(treasurySuccess, "FoodMarketplace: Treasury transfer failed");
            }
        } else {
            // 如果没有设置ReferralV2，直接转给treasury
            (bool success, ) = payable(treasury).call{ value: totalPrice }("");
            require(success, "FoodMarketplace: Treasury transfer failed");
        }

        // 如果发送的ETH超过所需金额，退还多余的部分
        if (msg.value > totalPrice) {
            (bool success, ) = payable(msg.sender).call{ value: msg.value - totalPrice }("");
            require(success, "FoodMarketplace: ETH refund failed");
        }

        // 增加用户食物盒子余额
        balanceManager.increaseFoodBoxBalance(msg.sender, amount);

        emit FoodPurchased(msg.sender, amount);
    }

    function openFood(uint256 amount) external nonReentrant {
        require(amount > 0, "FoodMarketplace: Amount must be greater than 0");
        require(balanceManager.getFoodBoxBalance(msg.sender) >= amount, "FoodMarketplace: Insufficient food balance");
        require(tokenSequence.length > 0, "FoodMarketplace: Token sequence not set");

        // 验证序列中的所有token ID都已初始化
        _validateTokenSequence();

        // 扣除用户食物盒子余额
        balanceManager.decreaseFoodBoxBalance(msg.sender, amount);

        // 清除用户上次打开的食物记录
        delete userLastOpenedFood[msg.sender];

        // 生成并铸造食物
        uint256[] memory tokenIds = new uint256[](amount);
        uint8[] memory rarities = new uint8[](amount);

        // 原子性预分配序列索引范围，避免竞态条件
        uint256 startIndex = currentSequenceIndex;
        currentSequenceIndex = (currentSequenceIndex + amount) % tokenSequence.length;

        for (uint256 i = 0; i < amount; i++) {
            // 计算当前应该使用的索引
            uint256 sequenceIndex = (startIndex + i) % tokenSequence.length;
            uint256 tokenId = tokenSequence[sequenceIndex];
            
            tokenIds[i] = tokenId;

            // mint food NFT
            foodNFT.mint(msg.sender, tokenId);

            // 获取稀有度并记录
            uint8 rarity = foodNFT.getRarity(tokenId);
            rarities[i] = rarity;

            // 记录用户最后打开的食物
            userLastOpenedFood[msg.sender].push(
                FoodInfo({
                    tokenId: tokenId,
                    rarity: rarity,
                    name: foodNFT.getName(tokenId),
                    value: foodNFT.getValue(tokenId),
                    exp: foodNFT.getExp(tokenId)
                })
            );
        }

        emit FoodOpened(msg.sender, tokenIds, rarities);
    }

    function recycleFood(uint256[] memory foodIds, uint256[] memory amounts) external nonReentrant {
        require(foodIds.length == amounts.length, "FoodMarketplace: Mismatched lengths");

        uint256 refundAmount = 0;
        for (uint256 i = 0; i < foodIds.length; i++) {
            require(amounts[i] > 0, "FoodMarketplace: Invalid amount");
            require(foodNFT.balanceOf(msg.sender, foodIds[i]) >= amounts[i], "FoodMarketplace: Insufficient balance");

            uint256 recyclePrice = foodNFT.getValue(foodIds[i]); // 使用食物的value作为回收价格
            refundAmount += recyclePrice * amounts[i];
        }
        
        // 销毁食物NFT
        foodNFT.burnBatch(_msgSender(), foodIds, amounts);

        // 只有当退款金额大于0时才进行ETH转账
        if (refundAmount > 0) {
            // 检查合约是否有足够的ETH进行退款
            require(address(this).balance >= refundAmount, "FoodMarketplace: Insufficient contract balance for refund");
            
            // 退还ETH给用户
            (bool success, ) = payable(msg.sender).call{ value: refundAmount }("");
            require(success, "FoodMarketplace: ETH refund failed");
        }

        emit FoodRecycled(msg.sender, foodIds, refundAmount);
    }

    // 设置token序列
    function setTokenSequence(uint256[] memory _tokenSequence) external onlyOwner {
        require(_tokenSequence.length > 0, "FoodMarketplace: Empty sequence");
        tokenSequence = _tokenSequence;
        currentSequenceIndex = 0; // 重置序列索引
    }

    // 分批设置token序列 - 初始化模式
    function initializeTokenSequence(uint256 expectedTotalLength) external onlyOwner {
        require(expectedTotalLength > 0, "FoodMarketplace: Invalid total length");
        delete tokenSequence; // 清空现有序列
        currentSequenceIndex = 0;
        
        emit TokenSequenceInitialized(expectedTotalLength);
    }

    // 分批设置token序列 - 追加模式
    function appendTokenSequence(uint256[] memory _tokens) external onlyOwner {
        require(_tokens.length > 0, "FoodMarketplace: Empty tokens array");
        
        for (uint256 i = 0; i < _tokens.length; i++) {
            tokenSequence.push(_tokens[i]);
        }
        
        emit TokenSequenceAppended(_tokens.length, tokenSequence.length);
    }

    // 分批设置token序列 - 完成设置
    function finalizeTokenSequence() external onlyOwner {
        require(tokenSequence.length > 0, "FoodMarketplace: No tokens in sequence");
        currentSequenceIndex = 0; // 重置索引
        
        emit TokenSequenceFinalized(tokenSequence.length);
    }

    // 获取序列设置进度
    function getSequenceProgress() external view returns (uint256 currentLength) {
        return tokenSequence.length;
    }

    // 重置序列索引
    function resetSequenceIndex() external onlyOwner {
        currentSequenceIndex = 0;
    }

    // 管理员为用户增加食物盒子余额
    function addFoodBalance(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "FoodMarketplace: Invalid user address");
        require(amount > 0, "FoodMarketplace: Amount must be greater than 0");
        
        balanceManager.increaseFoodBoxBalance(user, amount);
        
        emit FoodBalanceAdded(user, amount);
    }

    // 管理员直接为用户mint指定的食物NFT
    function adminMint(address user, uint256 tokenId) external onlyOwner {
        require(user != address(0), "FoodMarketplace: Invalid user address");
        
        // 直接mint指定的食物NFT
        foodNFT.mint(user, tokenId);
        
        emit AdminMint(user, tokenId);
    }

    function milestonenMint(address user, uint256 tokenId) external onlyOwner {
        require(msg.sender == address(referralV2), "FoodMarketplace: Only ReferralV2 can call this function");
        require(user != address(0), "FoodMarketplace: Invalid user address");
        // 直接mint指定的食物NFT
        foodNFT.mint(user, tokenId);
        
        emit AdminMint(user, tokenId);
    }

    // 基于Relayer签名的mint方法
    function relayerMint(
        RelayerMintData memory mintData,
        bytes memory signature
    ) external nonReentrant {
        require(relayerAddress != address(0), "FoodMarketplace: Relayer address not set");
        require(mintData.to != address(0), "FoodMarketplace: Invalid recipient address");
        require(mintData.deadline >= block.timestamp, "FoodMarketplace: Signature expired");
        require(mintData.nonce == nonces[mintData.to], "FoodMarketplace: Invalid nonce");

        // 构造 EIP-712 签名消息
        bytes32 structHash = _getRelayerMintHash(mintData);
        bytes32 messageHash = _hashTypedDataV4(structHash);
        
        // 检查签名是否已被使用
        require(!usedSignatures[messageHash], "FoodMarketplace: Signature already used");
        
        // 验证签名
        address recoveredSigner = ECDSA.recover(messageHash, signature);
        require(recoveredSigner == relayerAddress, "FoodMarketplace: Invalid signature");

        // 标记签名为已使用并增加nonce
        usedSignatures[messageHash] = true;
        nonces[mintData.to]++;

        // mint食物NFT
        foodNFT.mint(mintData.to, mintData.tokenId);

        emit RelayerMint(mintData.to, mintData.tokenId, mintData.nonce);
    }

    // 管理员提取合约中的ETH（用于回收退款储备金管理）
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount > 0, "FoodMarketplace: Amount must be greater than 0");
        require(address(this).balance >= amount, "FoodMarketplace: Insufficient contract balance");
        
        (bool success, ) = payable(owner()).call{ value: amount }("");
        require(success, "FoodMarketplace: ETH withdrawal failed");
    }

    // 管理员向合约存入ETH（用于回收退款储备金）
    function depositETH() external payable onlyOwner {
        require(msg.value > 0, "FoodMarketplace: Must send ETH");
    }

    // 获取当前token序列
    function getTokenSequence() external view returns (uint256[] memory) {
        return tokenSequence;
    }

    // 获取当前序列索引
    function getCurrentSequenceIndex() external view returns (uint256) {
        return currentSequenceIndex;
    }

    // 获取用户食物盒子余额
    function getUserFoodBalance(address user) external view returns (uint256) {
        return balanceManager.getFoodBoxBalance(user);
    }

    // 获取用户最后打开的食物
    function getUserLastOpenedFood(address user) external view returns (FoodInfo[] memory) {
        return userLastOpenedFood[user];
    }

    // 获取食物价格
    function getFoodPrice() external view returns (uint256) {
        return foodHDPrice;
    }

    // 获取用户当前nonce
    function getUserNonce(address user) external view returns (uint256) {
        return nonces[user];
    }

    // 检查签名是否已被使用
    function isSignatureUsed(bytes32 messageHash) external view returns (bool) {
        return usedSignatures[messageHash];
    }

    // 获取Relayer地址
    function getRelayerAddress() external view returns (address) {
        return relayerAddress;
    }

    // 获取 EIP-712 域分隔符
    function getDomainSeparator() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    // 获取 RelayerMintData 类型哈希
    function getRelayerMintTypeHash() external pure returns (bytes32) {
        return RELAYER_MINT_TYPEHASH;
    }

    // 内部函数：验证token序列的有效性
    function _validateTokenSequence() internal view {
        // 简单验证：检查序列不为空即可，具体的food存在性在mint时验证
        require(tokenSequence.length > 0, "FoodMarketplace: Empty token sequence");
    }

    // 内部函数：生成 EIP-712 结构哈希
    function _getRelayerMintHash(RelayerMintData memory mintData) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(
                RELAYER_MINT_TYPEHASH,
                mintData.to,
                mintData.tokenId,
                mintData.nonce,
                mintData.deadline
            )
        );
    }

    // ======== 管理函数 ========
    
    /**
     * @dev 设置UserBalanceManager合约地址
     */
    function setBalanceManager(address _balanceManager) external onlyOwner {
        require(_balanceManager != address(0), "FoodMarketplace: Invalid balance manager address");
        balanceManager = IUserBalanceManager(_balanceManager);
    }

    // 接收ETH的函数，用于运营充值回收资金池
    receive() external payable override {
        // 允许合约接收ETH作为回收退款资金池
    }

    // UUPS升级所需函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
