// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/ICharacterNFT.sol";
import "./BlackGhostNFT.sol";
import "./tokens/GoldDXPToken.sol";
import "./tokens/SilverDXPToken.sol";

/**
 * @title CharacterUpgrade
 * @dev 角色升级合约，处理 Gold DXP 和 Silver DXP 的角色升级功能
 * - Gold DXP: 批量升级，仅限 CharacterNFT 合约的角色
 * - Silver DXP: 单个升级，支持任意角色（CharacterNFT 或 BlackGhostNFT）
 */
contract CharacterUpgrade is Initializable, OwnableUpgradeable, UUPSUpgradeable, ReentrancyGuardUpgradeable {
    
    // 合约地址
    GoldDXPToken public goldDXPToken;
    SilverDXPToken public silverDXPToken;
    ICharacterNFT public characterNFT;
    BlackGhostNFT public blackGhostNFT;
    
    // 升级配置
    struct UpgradeConfig {
        uint256 goldDXPCost;    // Gold DXP 单次升级消耗
        uint256 silverDXPCost;  // Silver DXP 单次升级消耗
        uint8 maxLevel;         // 最大等级
        uint256 expPerLevel;    // 每级所需经验值
    }
    
    UpgradeConfig public upgradeConfig;
    
    // 事件
    event CharacterUpgraded(
        address indexed user,
        address indexed nftContract,
        uint256 indexed tokenId,
        uint8 oldLevel,
        uint8 newLevel,
        uint256 newExp,
        string upgradeType
    );
    
    event BatchUpgradeCompleted(
        address indexed user,
        uint256[] tokenIds,
        uint256 totalGoldDXPUsed,
        uint256 successCount
    );
    
    event UpgradeConfigUpdated(
        uint256 goldDXPCost,
        uint256 silverDXPCost,
        uint8 maxLevel,
        uint256 expPerLevel
    );

    modifier validTokenId(address nftContract, uint256 tokenId) {
        require(
            (nftContract == address(characterNFT) && tokenId < 100000) ||
            (nftContract == address(blackGhostNFT) && tokenId >= 100000),
            "CharacterUpgrade: Invalid token ID for contract"
        );
        _;
    }

    function initialize(
        address _goldDXPToken,
        address _silverDXPToken,
        address _characterNFT,
        address _blackGhostNFT
    ) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();
        
        require(_goldDXPToken != address(0), "CharacterUpgrade: Invalid Gold DXP token");
        require(_silverDXPToken != address(0), "CharacterUpgrade: Invalid Silver DXP token");
        require(_characterNFT != address(0), "CharacterUpgrade: Invalid CharacterNFT");
        require(_blackGhostNFT != address(0), "CharacterUpgrade: Invalid BlackGhostNFT");
        
        goldDXPToken = GoldDXPToken(payable(_goldDXPToken));
        silverDXPToken = SilverDXPToken(payable(_silverDXPToken));
        characterNFT = ICharacterNFT(_characterNFT);
        blackGhostNFT = BlackGhostNFT(_blackGhostNFT);
        
        // 设置默认升级配置
        upgradeConfig = UpgradeConfig({
            goldDXPCost: 100 * 10**18,    // 100 Gold DXP
            silverDXPCost: 50 * 10**18,   // 50 Silver DXP
            maxLevel: 10,                 // 最大等级 10
            expPerLevel: 1000             // 每级 1000 经验值
        });
    }

    /**
     * @dev 设置升级配置（仅管理员）
     */
    function setUpgradeConfig(
        uint256 _goldDXPCost,
        uint256 _silverDXPCost,
        uint8 _maxLevel,
        uint256 _expPerLevel
    ) external onlyOwner {
        require(_maxLevel > 0 && _maxLevel <= 20, "CharacterUpgrade: Invalid max level");
        require(_expPerLevel > 0, "CharacterUpgrade: Invalid exp per level");
        
        upgradeConfig.goldDXPCost = _goldDXPCost;
        upgradeConfig.silverDXPCost = _silverDXPCost;
        upgradeConfig.maxLevel = _maxLevel;
        upgradeConfig.expPerLevel = _expPerLevel;
        
        emit UpgradeConfigUpdated(_goldDXPCost, _silverDXPCost, _maxLevel, _expPerLevel);
    }

    /**
     * @dev Gold DXP 批量升级（仅限 CharacterNFT）
     * @param tokenIds 要升级的角色 token ID 数组
     */
    function batchUpgradeWithGoldDXP(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "CharacterUpgrade: Empty token list");
        require(tokenIds.length <= 50, "CharacterUpgrade: Too many tokens");
        
        uint256 totalCost = upgradeConfig.goldDXPCost * tokenIds.length;
        require(
            goldDXPToken.balanceOf(msg.sender) >= totalCost,
            "CharacterUpgrade: Insufficient Gold DXP balance"
        );
        
        uint256 successCount = 0;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            
            // 验证是 CharacterNFT 的 token
            require(tokenId < 100000, "CharacterUpgrade: Gold DXP only for CharacterNFT");
            
            // 验证所有权
            require(
                characterNFT.ownerOf(tokenId) == msg.sender,
                "CharacterUpgrade: Not token owner"
            );
            
            // 获取当前属性
            uint8 currentLevel = characterNFT.getLevel(tokenId);
            uint256 currentExp = characterNFT.getExp(tokenId);
            
            // 检查是否可以升级
            if (currentLevel < upgradeConfig.maxLevel) {
                uint8 newLevel = currentLevel + 1;
                uint256 newExp = currentExp + upgradeConfig.expPerLevel;
                
                // 更新角色属性
                characterNFT.updateLevelAndExp(tokenId, newLevel, newExp);
                
                emit CharacterUpgraded(
                    msg.sender,
                    address(characterNFT),
                    tokenId,
                    currentLevel,
                    newLevel,
                    newExp,
                    "GoldDXP"
                );
                
                successCount++;
            }
        }
        
        // 扣除对应数量的 Gold DXP
        if (successCount > 0) {
            uint256 actualCost = upgradeConfig.goldDXPCost * successCount;
            goldDXPToken.burn(msg.sender, actualCost);
        }
        
        emit BatchUpgradeCompleted(msg.sender, tokenIds, upgradeConfig.goldDXPCost * successCount, successCount);
    }

    /**
     * @dev Silver DXP 单个升级（支持任意角色）
     * @param nftContract NFT 合约地址 (CharacterNFT 或 BlackGhostNFT)
     * @param tokenId 要升级的角色 token ID
     */
    function upgradeWithSilverDXP(
        address nftContract,
        uint256 tokenId
    ) external nonReentrant validTokenId(nftContract, tokenId) {
        require(
            silverDXPToken.balanceOf(msg.sender) >= upgradeConfig.silverDXPCost,
            "CharacterUpgrade: Insufficient Silver DXP balance"
        );
        
        uint8 currentLevel;
        uint256 currentExp;
        
        // 根据合约类型获取当前属性和验证所有权
        if (nftContract == address(characterNFT)) {
            require(
                characterNFT.ownerOf(tokenId) == msg.sender,
                "CharacterUpgrade: Not token owner"
            );
            currentLevel = characterNFT.getLevel(tokenId);
            currentExp = characterNFT.getExp(tokenId);
        } else {
            require(
                blackGhostNFT.ownerOf(tokenId) == msg.sender,
                "CharacterUpgrade: Not token owner"
            );
            currentLevel = blackGhostNFT.getLevel(tokenId);
            currentExp = blackGhostNFT.getExp(tokenId);
        }
        
        // 检查是否可以升级
        require(currentLevel < upgradeConfig.maxLevel, "CharacterUpgrade: Already at max level");
        
        uint8 newLevel = currentLevel + 1;
        uint256 newExp = currentExp + upgradeConfig.expPerLevel;
        
        // 更新角色属性
        if (nftContract == address(characterNFT)) {
            characterNFT.updateLevelAndExp(tokenId, newLevel, newExp);
        } else {
            blackGhostNFT.updateLevelAndExp(tokenId, newLevel, newExp);
        }
        
        // 扣除 Silver DXP
        silverDXPToken.burn(msg.sender, upgradeConfig.silverDXPCost);
        
        emit CharacterUpgraded(
            msg.sender,
            nftContract,
            tokenId,
            currentLevel,
            newLevel,
            newExp,
            "SilverDXP"
        );
    }

    /**
     * @dev 获取角色升级信息
     * @param nftContract NFT 合约地址
     * @param tokenId 角色 token ID
     * @return currentLevel 当前等级
     * @return currentExp 当前经验值
     * @return canUpgrade 是否可以升级
     * @return goldDXPCost Gold DXP 升级成本（如果适用）
     * @return silverDXPCost Silver DXP 升级成本
     */
    function getUpgradeInfo(
        address nftContract,
        uint256 tokenId
    ) external view validTokenId(nftContract, tokenId) returns (
        uint8 currentLevel,
        uint256 currentExp,
        bool canUpgrade,
        uint256 goldDXPCost,
        uint256 silverDXPCost
    ) {
        if (nftContract == address(characterNFT)) {
            currentLevel = characterNFT.getLevel(tokenId);
            currentExp = characterNFT.getExp(tokenId);
            goldDXPCost = upgradeConfig.goldDXPCost;
        } else {
            currentLevel = blackGhostNFT.getLevel(tokenId);
            currentExp = blackGhostNFT.getExp(tokenId);
            goldDXPCost = 0; // BlackGhostNFT 不支持 Gold DXP 升级
        }
        
        canUpgrade = currentLevel < upgradeConfig.maxLevel;
        silverDXPCost = upgradeConfig.silverDXPCost;
    }

    /**
     * @dev 批量获取用户拥有的可升级角色
     * @param user 用户地址
     * @return characterTokens CharacterNFT 中可升级的 token IDs
     * @return blackGhostTokens BlackGhostNFT 中可升级的 token IDs
     */
    function getUserUpgradeableTokens(
        address user
    ) external view returns (
        uint256[] memory characterTokens,
        uint256[] memory blackGhostTokens
    ) {
        // 获取 CharacterNFT tokens
        uint256[] memory allCharacterTokens = characterNFT.getOwnedTokens(user);
        uint256 characterUpgradeableCount = 0;
        
        // 计算可升级的 CharacterNFT 数量
        for (uint256 i = 0; i < allCharacterTokens.length; i++) {
            if (characterNFT.getLevel(allCharacterTokens[i]) < upgradeConfig.maxLevel) {
                characterUpgradeableCount++;
            }
        }
        
        // 填充可升级的 CharacterNFT tokens
        characterTokens = new uint256[](characterUpgradeableCount);
        uint256 characterIndex = 0;
        for (uint256 i = 0; i < allCharacterTokens.length; i++) {
            if (characterNFT.getLevel(allCharacterTokens[i]) < upgradeConfig.maxLevel) {
                characterTokens[characterIndex] = allCharacterTokens[i];
                characterIndex++;
            }
        }
        
        // 获取 BlackGhostNFT tokens
        uint256[] memory allBlackGhostTokens = blackGhostNFT.getOwnedTokens(user);
        uint256 blackGhostUpgradeableCount = 0;
        
        // 计算可升级的 BlackGhostNFT 数量
        for (uint256 i = 0; i < allBlackGhostTokens.length; i++) {
            if (blackGhostNFT.getLevel(allBlackGhostTokens[i]) < upgradeConfig.maxLevel) {
                blackGhostUpgradeableCount++;
            }
        }
        
        // 填充可升级的 BlackGhostNFT tokens
        blackGhostTokens = new uint256[](blackGhostUpgradeableCount);
        uint256 blackGhostIndex = 0;
        for (uint256 i = 0; i < allBlackGhostTokens.length; i++) {
            if (blackGhostNFT.getLevel(allBlackGhostTokens[i]) < upgradeConfig.maxLevel) {
                blackGhostTokens[blackGhostIndex] = allBlackGhostTokens[i];
                blackGhostIndex++;
            }
        }
    }

    /**
     * @dev 计算批量升级的 Gold DXP 成本
     * @param tokenIds 要升级的 CharacterNFT token IDs
     * @return totalCost 总成本
     * @return upgradeableCount 实际可升级的数量
     */
    function calculateBatchUpgradeCost(
        uint256[] calldata tokenIds
    ) external view returns (uint256 totalCost, uint256 upgradeableCount) {
        upgradeableCount = 0;
        
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(tokenIds[i] < 100000, "CharacterUpgrade: Gold DXP only for CharacterNFT");
            
            if (characterNFT.getLevel(tokenIds[i]) < upgradeConfig.maxLevel) {
                upgradeableCount++;
            }
        }
        
        totalCost = upgradeConfig.goldDXPCost * upgradeableCount;
    }

    // UUPS 升级授权
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}