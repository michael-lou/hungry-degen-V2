// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./BaseMarketplaceNoVRF.sol";
import "./interfaces/ICoreNFT.sol";
import "./interfaces/IFlexNFT.sol";
import "./interfaces/IReferralV2.sol";
import "./interfaces/IUserBalanceManager.sol";
import "./RarityManager.sol";
import "./GoldDustToken.sol";

contract PackMarketplace is BaseMarketplaceNoVRF {
    uint8 public constant TYPE_CORE = 0;
    uint8 public constant TYPE_FLEX = 1;

    ICoreNFT public coreNFT;
    IFlexNFT public flexNFT;
    IReferralV2 public referralV2;
    RarityManager public rarityManager;
    IUserBalanceManager public balanceManager;

    mapping(uint8 => mapping(uint8 => uint256)) public packPrice;
    
    // Flex Pack的DUST价格 (packType=1时使用)
    mapping(uint8 => uint256) public flexPackDustPrice;
    
    // Gold Dust Token for Gold Pack purchases
    GoldDustToken public goldDustToken;
    
    // Gold Pack prices (pack type -> character type -> gold dust price)
    mapping(uint8 => mapping(uint8 => uint256)) public goldPackPrice;

    struct PackInfo{
        uint256 packType; // 0: Core, 1: Flex
        uint256 tokenId;
        uint8 characterType;
        uint8 rarity;
        string metadataUri;
    }

    mapping(address => PackInfo[]) public userLastOpenedPacks;
    
    // VIP 授权合约
    mapping(address => bool) public authorizedVIPContracts;

    // 事件
    event BoxPurchased(address indexed buyer, uint8 packType, uint8 characterType, uint256 amount);
    event BoxOpened(
        address indexed owner,
        uint256 tokenId,
        uint8 characterType,
        uint8 rarity,
        uint8 packType
    );
    event PriceUpdated(uint8 packType, uint8 characterType, uint256 price);
    event FlexPackDustPriceUpdated(uint8 characterType, uint256 price);
    event VIPContractAuthorized(address indexed vipContract, bool authorized);
    event BoxBalanceAdded(address indexed user, uint8 packType, uint8 characterType, uint256 amount);
    event AdminMint(address indexed user, uint8 packType, uint8 characterType, uint8 rarity, uint256 tokenId);
    event GoldPackPurchased(address indexed buyer, uint8 packType, uint8 characterType, uint256 amount, uint256 goldDustCost);
    event GoldPackOpened(address indexed owner, uint256 tokenId, uint8 packType, uint8 characterType, uint8 rarity);
    event GoldPackPriceUpdated(uint8 packType, uint8 characterType, uint256 price);

    function initialize(
        address _coreNFT,
        address _flexNFT,
        address _rarityManager,
        address _referralV2,
        address _balanceManager,
        address payable _treasury
    ) public initializer {
        __BaseMarketplaceNoVRF_init(_treasury);

        coreNFT = ICoreNFT(_coreNFT);
        flexNFT = IFlexNFT(_flexNFT);
        referralV2 = IReferralV2(_referralV2);
        rarityManager = RarityManager(_rarityManager);
        balanceManager = IUserBalanceManager(_balanceManager);

        // 设置默认价格
        packPrice[0][0] = 5000 ether; // Mixed Core Pack
        packPrice[0][1] = 8000 ether; // Airdrop Andy Core Pack
        packPrice[0][2] = 8000 ether; // Scammed Steve Core Pack
        packPrice[0][3] = 8000 ether; // Dustbag Danny Core Pack
        packPrice[0][4] = 8000 ether; // Leverage Larry Core Pack
        packPrice[0][5] = 6500 ether; // Trenches Ghost Core Pack

        packPrice[1][0] = 0.01 ether; // Mixed Flex Pack
        packPrice[1][1] = 0.02 ether; // Airdrop Andy Flex Pack
        packPrice[1][2] = 0.02 ether; // Scammed Steve Flex Pack
        packPrice[1][3] = 0.02 ether; // Dustbag Danny Flex Pack
        packPrice[1][4] = 0.02 ether; // Leverage Larry Flex Pack
        packPrice[1][5] = 0.015 ether; // Trenches Ghost Flex Pack
        
        // 设置默认Flex Pack DUST价格
        flexPackDustPrice[0] = 1000 ether; // Mixed Flex Pack
        flexPackDustPrice[1] = 2000 ether; // Airdrop Andy Flex Pack
        flexPackDustPrice[2] = 2000 ether; // Scammed Steve Flex Pack
        flexPackDustPrice[3] = 2000 ether; // Dustbag Danny Flex Pack
        flexPackDustPrice[4] = 2000 ether; // Leverage Larry Flex Pack
        flexPackDustPrice[5] = 1500 ether; // Trenches Ghost Flex Pack
        
        // 设置默认Gold Core Pack价格（Gold Dust）
        goldPackPrice[TYPE_CORE][0] = 3000 ether; // Mixed Gold Core Pack
        goldPackPrice[TYPE_CORE][1] = 5000 ether; // Airdrop Andy Gold Core Pack
        goldPackPrice[TYPE_CORE][2] = 5000 ether; // Scammed Steve Gold Core Pack
        goldPackPrice[TYPE_CORE][3] = 5000 ether; // Dustbag Danny Gold Core Pack
        goldPackPrice[TYPE_CORE][4] = 5000 ether; // Leverage Larry Gold Core Pack
        goldPackPrice[TYPE_CORE][5] = 4000 ether; // Trenches Ghost Gold Core Pack
        
        // 设置默认Gold Flex Pack价格（Gold Dust）
        goldPackPrice[TYPE_FLEX][0] = 2000 ether; // Mixed Gold Flex Pack
        goldPackPrice[TYPE_FLEX][1] = 3000 ether; // Airdrop Andy Gold Flex Pack
        goldPackPrice[TYPE_FLEX][2] = 3000 ether; // Scammed Steve Gold Flex Pack
        goldPackPrice[TYPE_FLEX][3] = 3000 ether; // Dustbag Danny Gold Flex Pack
        goldPackPrice[TYPE_FLEX][4] = 3000 ether; // Leverage Larry Gold Flex Pack
        goldPackPrice[TYPE_FLEX][5] = 2500 ether; // Trenches Ghost Gold Flex Pack
    }

    // 更新包价格
    function updatePrice(uint8 packType, uint8 characterType, uint256 price) external onlyOwner {
        packPrice[packType][characterType] = price;
        emit PriceUpdated(packType, characterType, price);
    }
    
    // 更新Flex Pack DUST价格
    function updateFlexPackDustPrice(uint8 characterType, uint256 price) external onlyOwner {
        require(characterType <= 5, "Invalid character type");
        flexPackDustPrice[characterType] = price;
        emit FlexPackDustPriceUpdated(characterType, price);
    }
    
    // 设置Gold Dust Token合约
    function setGoldDustToken(address _goldDustToken) external onlyOwner {
        require(_goldDustToken != address(0), "Invalid Gold Dust token address");
        goldDustToken = GoldDustToken(_goldDustToken);
    }
    
    // 更新Gold Pack价格
    function updateGoldPackPrice(uint8 packType, uint8 characterType, uint256 price) external onlyOwner {
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        goldPackPrice[packType][characterType] = price;
        emit GoldPackPriceUpdated(packType, characterType, price);
    }

    // 设置合约引用
    function setContracts(
        address _coreNFT,
        address _flexNFT,
        address _rarityManager
    ) external onlyOwner {
        if (_coreNFT != address(0)) coreNFT = ICoreNFT(_coreNFT);
        if (_flexNFT != address(0)) flexNFT = IFlexNFT(_flexNFT);
        if (_rarityManager != address(0)) rarityManager = RarityManager(_rarityManager);
    }

    function setReferralV2(address _referralV2) external onlyOwner {
        require(_referralV2 != address(0), "PackMarketplace: Invalid referralV2 address");
        referralV2 = IReferralV2(_referralV2);
    }

    // 设置VIP合约授权
    function setVIPContractAuthorization(address vipContract, bool authorized) external onlyOwner {
        require(vipContract != address(0), "Invalid VIP contract address");
        authorizedVIPContracts[vipContract] = authorized;
        emit VIPContractAuthorized(vipContract, authorized);
    }

    // VIP专用开包函数 - 只能由授权的VIP合约调用
    function openVIPReward(address user, uint8 packType, uint8 characterType) external nonReentrant returns (uint256 tokenId, uint8 finalCharacterType, uint8 rarity) {
        require(authorizedVIPContracts[msg.sender], "Only authorized VIP contracts");
        require(user != address(0), "Invalid user address");
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");

        // 生成随机种子
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            block.coinbase,
            user,
            packType,
            characterType,
            "VIP_REWARD"
        )));

        // 调用内部开包逻辑
        (tokenId, finalCharacterType, rarity) = _openVIPBox(user, packType, characterType, seed);
        
        return (tokenId, finalCharacterType, rarity);
    }

    // 内部VIP开包函数
    function _openVIPBox(address user, uint8 packType, uint8 characterType, uint256 seed) internal returns (uint256 tokenId, uint8 finalCharacterType, uint8 rarity) {
        // 生成随机数
        uint256 baseRandomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            block.coinbase,
            seed,
            user
        )));

        finalCharacterType = characterType;
        if (characterType == 0) {
            // 混合包，随机选择角色
            finalCharacterType = rarityManager.getRandomCharacterType(baseRandomNumber);
        }

        // 确定稀有度
        rarity = rarityManager.determineRarityBySequence(packType, finalCharacterType);

        string memory uri;

        if (packType == TYPE_CORE) {
            (tokenId, uri) = coreNFT.mint(user, finalCharacterType, rarity);
        } else if (packType == TYPE_FLEX) {
            (tokenId, uri) = flexNFT.mint(user, finalCharacterType, rarity);
        }

        emit BoxOpened(user, tokenId, finalCharacterType, rarity, packType);
        
        return (tokenId, finalCharacterType, rarity);
    }

    // 购买NFT
    function buyPack(uint8 characterType, uint8 packType, uint256 amount, address referrerAddress) external payable nonReentrant {
        require(characterType <= 5, "Invalid character type");
        require(packType <= 1, "Invalid pack type");

        if (packType == TYPE_FLEX) {
             require(msg.value >=(packPrice[packType][characterType] * amount), "Insufficient ETH");
        }

        uint256 totalPrice = packPrice[packType][characterType] * amount;
        
        // 使用ReferralV2系统处理推荐奖励
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }
            
            if (packType == TYPE_CORE) {
                // Core Pack: 5% DUST奖励
                referralV2.recordSaleAndDistributeRewards(
                    msg.sender, 
                    currentReferrer, 
                    IReferralV2.ProductType.CORE_PACK, 
                    totalPrice
                );
            } else if (packType == TYPE_FLEX) {
                // Flex Pack: 5% ETH奖励
                referralV2.recordSaleAndDistributeRewards(
                    msg.sender, 
                    currentReferrer, 
                    IReferralV2.ProductType.FLEX_PACK, 
                    totalPrice
                );
            }
        } else {
            // 如果没有设置ReferralV2，直接转给treasury
            if (packType == TYPE_CORE) {
                dustToken.transferFrom(msg.sender, treasury, totalPrice);
            } else if (packType == TYPE_FLEX) {
                (bool success, ) = payable(treasury).call{ value: totalPrice }("");
                require(success, "PackMarketplace: Treasury transfer failed");
            }
        }

        // 如果是Flex pack 后返回多余的ETH
        if (packType == TYPE_FLEX) {
            uint256 excess = msg.value - totalPrice;
            if (excess > 0) {
                (bool success, ) = msg.sender.call{ value: excess }("");
                require(success, "Failed to send excess ETH");
            }
        }
        balanceManager.increaseBoxBalance(msg.sender, packType, characterType, amount);

        emit BoxPurchased(msg.sender, packType, characterType, amount);
    }
    
    // 使用DUST购买Flex Pack
    function buyFlexPackWithDust(uint8 characterType, uint256 amount, address referrerAddress) external nonReentrant {
        require(characterType <= 5, "Invalid character type");
        require(amount > 0, "Amount must be greater than 0");
        
        uint256 totalCost = flexPackDustPrice[characterType] * amount;
        require(totalCost > 0, "Flex pack price not set");
        
        // 先从用户转账到treasury
        dustToken.transferFrom(msg.sender, treasury, totalCost);
        
        // 使用ReferralV2系统处理推荐奖励
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }
            
            // 使用新的推荐系统 (5% DUST奖励，用DUST购买的Flex Pack)
            referralV2.recordSaleAndDistributeRewards(
                msg.sender, 
                currentReferrer, 
                IReferralV2.ProductType.FLEX_PACK_DUST, 
                totalCost
            );
        }
        
        // 增加用户的Flex Pack余额
        balanceManager.increaseBoxBalance(msg.sender, TYPE_FLEX, characterType, amount);
        
        emit BoxPurchased(msg.sender, TYPE_FLEX, characterType, amount);
    }
    
    // 管理员为用户增加包装余额
    function addBoxBalance(
        address user, 
        uint8 packType, 
        uint8 characterType, 
        uint256 amount
    ) external onlyOwner {
        require(user != address(0), "Invalid user address");
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        require(amount > 0, "Amount must be greater than 0");
        
        balanceManager.increaseBoxBalance(user, packType, characterType, amount);
        
        emit BoxBalanceAdded(user, packType, characterType, amount);
    }
    
    // 管理员为用户Mint指定装备
    function adminMint(
        address user,
        uint8 packType,
        uint8 characterType,
        uint8 rarity
    ) external onlyOwner returns (uint256 tokenId) {
        require(user != address(0), "Invalid user address");
        require(packType <= 1, "Invalid pack type");
        require(characterType >= 1 && characterType <= 5, "Invalid character type");
        require(rarity >= 1 && rarity <= 6, "Invalid rarity");
        
        string memory uri;
        
        if (packType == TYPE_CORE) {
            (tokenId, uri) = coreNFT.mint(user, characterType, rarity);
        } else if (packType == TYPE_FLEX) {
            (tokenId, uri) = flexNFT.mint(user, characterType, rarity);
        }
        
        emit AdminMint(user, packType, characterType, rarity, tokenId);
        
        return tokenId;
    }

    // 打开盲盒
    function openBox( uint8 packType, uint8 characterType, uint256 amount) external nonReentrant {
        require(balanceManager.getBoxBalance(msg.sender, packType, characterType) >= amount, "Not enough boxes to open");

        // 删除userLastOpenedPacks的数据
        delete userLastOpenedPacks[msg.sender];

        for (uint256 i = 0; i < amount; i++) {
            uint256 seed = uint256(keccak256(abi.encodePacked(block.timestamp, block.prevrandao, msg.sender, i)));
            _openBox(packType, characterType, seed);
        }
    }

    // 内部函数：打开盲盒
    function _openBox(uint8 packType, uint8 characterType, uint256 seed) internal {

        // 生成随机数
        uint256 baseRandomNumber = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            block.coinbase,
            seed,
            msg.sender
        )));

        uint8 finalCharacterType = characterType;
        if (characterType == 0) {
            // 混合包，随机选择角色
            finalCharacterType = rarityManager.getRandomCharacterType(baseRandomNumber);
        }

        // 确定稀有度
        uint8 rarity = rarityManager.determineRarityBySequence(packType, finalCharacterType);


        uint256 tokenId;
        string memory uri;

        balanceManager.decreaseBoxBalance(msg.sender, packType, characterType, 1);

        if (packType == TYPE_CORE) {
            (tokenId, uri) = coreNFT.mint(msg.sender, finalCharacterType, rarity);
        } else if (packType == TYPE_FLEX) {
            (tokenId,uri) = flexNFT.mint(msg.sender, finalCharacterType, rarity);
        }

        userLastOpenedPacks[msg.sender].push(
            PackInfo({
                packType: packType,
                tokenId: tokenId,
                characterType: finalCharacterType,
                rarity: rarity,
                metadataUri: uri
            })
        );
        emit BoxOpened(msg.sender, tokenId, finalCharacterType, rarity, packType);
    }

    function getUserLastOpenedPacks(address user)
        external
        view
        returns (PackInfo[] memory)
    {
        return userLastOpenedPacks[user];
    }

    function getUserBoxBalance(address user)
        external
        view
        returns (uint256[2][6] memory)
    {
        uint256[2][6] memory balances;
        for (uint8 packType = 0; packType < 2; packType++) {
            for (uint8 characterType = 0; characterType < 6; characterType++) {
                balances[characterType][packType] = balanceManager.getBoxBalance(user, packType, characterType);
            }
        }
        return balances;
    }

    function getAllPackPrices()
        external
        view
        returns (uint256[6] memory corePrices, uint256[6] memory flexPrices)
    {
        for (uint8 i = 0; i < 6; i++) {
            corePrices[i] = packPrice[0][i];
            flexPrices[i] = packPrice[1][i];
        }
    }
    
    // 获取Flex Pack DUST价格
    function getFlexPackDustPrices() external view returns (uint256[6] memory dustPrices) {
        for (uint8 i = 0; i < 6; i++) {
            dustPrices[i] = flexPackDustPrice[i];
        }
    }
    
    // 获取单个Flex Pack DUST价格
    function getFlexPackDustPrice(uint8 characterType) external view returns (uint256) {
        require(characterType <= 5, "Invalid character type");
        return flexPackDustPrice[characterType];
    }
    
    // ============ Gold Pack Functions ============
    
    /**
     * @dev 购买Gold Pack (分离的 Core 或 Flex)
     */
    function buyGoldPack(uint8 packType, uint8 characterType, uint256 amount) external nonReentrant {
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        require(amount > 0, "Amount must be greater than 0");
        require(address(goldDustToken) != address(0), "Gold Dust token not set");
        
        uint256 totalCost = goldPackPrice[packType][characterType] * amount;
        require(totalCost > 0, "Gold pack price not set");
        
        // 从用户账户转移Gold Dust到treasury
        require(
            goldDustToken.transferFrom(msg.sender, treasury, totalCost),
            "Gold Dust transfer failed"
        );
        
        // 增加用户的Gold Pack余额
        balanceManager.increaseGoldPackBalance(msg.sender, packType, characterType, amount);
        
        emit GoldPackPurchased(msg.sender, packType, characterType, amount, totalCost);
    }
    
    /**
     * @dev 开Gold Pack（只出R级以上装备）
     */
    function openGoldPack(uint8 packType, uint8 characterType, uint256 amount) external nonReentrant {
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        require(amount > 0, "Amount must be greater than 0");
        require(balanceManager.getGoldPackBalance(msg.sender, packType, characterType) >= amount, "Insufficient Gold Pack balance");
        
        // 减少用户Gold Pack余额
        balanceManager.decreaseGoldPackBalance(msg.sender, packType, characterType, amount);
        
        for (uint256 i = 0; i < amount; i++) {
            _openGoldPack(packType, characterType);
        }
    }
    
    /**
     * @dev 内部函数：开单个Gold Pack
     */
    function _openGoldPack(uint8 packType, uint8 characterType) internal {
        // 生成随机种子
        uint256 seed = uint256(keccak256(abi.encodePacked(
            block.timestamp,
            block.prevrandao,
            block.coinbase,
            msg.sender,
            packType,
            characterType,
            "GOLD_PACK"
        )));
        
        uint8 finalCharacterType = characterType;
        if (characterType == 0) {
            // Mixed Gold Pack - 随机选择角色类型
            finalCharacterType = uint8((seed % 5) + 1);
        }
        
        if (packType == TYPE_CORE) {
            // Gold Core Pack - 只生成Core NFT，确保稀有度 >= R级(3)
            uint8 coreRarity;
            uint256 attempts = 0;
            uint256 maxAttempts = 100; // 防止无限循环
            
            do {
                coreRarity = rarityManager.determineRarityBySequence(packType, finalCharacterType);
                attempts++;
            } while (coreRarity < 3 && attempts < maxAttempts);
            
            // 如果经过多次尝试仍未获得R级以上，强制设为R级
            if (coreRarity < 3) {
                coreRarity = 3; // 强制设为R级
            }
            
            (uint256 coreTokenId, ) = coreNFT.mint(msg.sender, finalCharacterType, coreRarity);
            
            emit GoldPackOpened(msg.sender, coreTokenId, packType, finalCharacterType, coreRarity);
        } else {
            // Gold Flex Pack - 只生成Flex NFT，确保稀有度 >= R级(3)
            uint8 flexRarity;
            uint256 attempts = 0;
            uint256 maxAttempts = 100; // 防止无限循环
            
            do {
                flexRarity = rarityManager.determineRarityBySequence(packType, finalCharacterType);
                attempts++;
            } while (flexRarity < 3 && attempts < maxAttempts);
            
            // 如果经过多次尝试仍未获得R级以上，强制设为R级
            if (flexRarity < 3) {
                flexRarity = 3; // 强制设为R级
            }
            
            (uint256 flexTokenId, ) = flexNFT.mint(msg.sender, finalCharacterType, flexRarity);
            
            emit GoldPackOpened(msg.sender, flexTokenId, packType, finalCharacterType, flexRarity);
        }
    }
    
    // ============ Gold Pack Query Functions ============
    
    /**
     * @dev 获取用户Gold Pack余额 (按packType和characterType)
     */
    function getUserGoldPackBalance(address user, uint8 packType) external view returns (uint256[6] memory) {
        require(packType <= 1, "Invalid pack type");
        uint256[6] memory balances;
        for (uint8 i = 0; i < 6; i++) {
            balances[i] = balanceManager.getGoldPackBalance(user, packType, i);
        }
        return balances;
    }
    
    /**
     * @dev 获取用户特定Gold Pack余额
     */
    function getUserGoldPackBalanceSpecific(address user, uint8 packType, uint8 characterType) external view returns (uint256) {
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        return balanceManager.getGoldPackBalance(user, packType, characterType);
    }
    
    /**
     * @dev 获取Gold Pack价格 (按packType)
     */
    function getGoldPackPrices(uint8 packType) external view returns (uint256[6] memory) {
        require(packType <= 1, "Invalid pack type");
        uint256[6] memory prices;
        for (uint8 i = 0; i < 6; i++) {
            prices[i] = goldPackPrice[packType][i];
        }
        return prices;
    }
    
    /**
     * @dev 获取单个Gold Pack价格
     */
    function getGoldPackPrice(uint8 packType, uint8 characterType) external view returns (uint256) {
        require(packType <= 1, "Invalid pack type");
        require(characterType <= 5, "Invalid character type");
        return goldPackPrice[packType][characterType];
    }
    
    // ============ Management Functions ============
    
    /**
     * @dev 设置UserBalanceManager合约地址
     */
    function setBalanceManager(address _balanceManager) external onlyOwner {
        require(_balanceManager != address(0), "Invalid balance manager address");
        balanceManager = IUserBalanceManager(_balanceManager);
    }
    
    // UUPS升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
