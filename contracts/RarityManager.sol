// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title RarityManager
 * @dev Manages rarity distribution and character types for NFT collections
 * @notice Handles randomization, rarity weights, and distribution mechanisms for NFTs
 */
contract RarityManager is Ownable {
    // Rarity constants - starting from 1
    uint8 public constant RARITY_C = 1;
    uint8 public constant RARITY_N = 2;
    uint8 public constant RARITY_R = 3;
    uint8 public constant RARITY_RR = 4;
    uint8 public constant RARITY_SR = 5;
    uint8 public constant RARITY_SSR = 6;

    // Character constants - starting from 1, no MIXED type
    uint8 public constant CHARACTER_ANDY = 1;
    uint8 public constant CHARACTER_STEVE = 2;
    uint8 public constant CHARACTER_DANNY = 3;
    uint8 public constant CHARACTER_LARRY = 4;
    uint8 public constant CHARACTER_GHOST = 5;

    // Rarity names - index 0 is blank for 1-based access
    string[7] public rarityNames = ["", "C", "N", "R", "RR", "SR", "SSR"];

    // Character names - index 0 is blank for 1-based access
    string[6] public characterNames = [
        "",
        "Airdrop Andy",
        "Scammed Steve",
        "Dustbag Danny",
        "Leverage Larry",
        "Trenches Ghost"
    ];

    // Rarity weights - total sum 10000
    uint16[6] public rarityWeights = [3500, 3500, 1300, 1300, 200, 200];

    // Character weights - total sum 10000
    uint16[5] public characterWeights = [1150, 2280, 2280, 1150, 3140];

    /**
     * @dev Rarity quota structure for tracking and limiting NFT supply
     * @param total Total quota for this rarity
     * @param minted Number of already minted NFTs
     * @param limited Whether the supply is limited or unlimited
     */
    struct RarityQuota {
        uint256 total; 
        uint256 minted;
        bool limited; 
    }

    // Rarity quotas mapping: character => rarity => quota
    mapping(uint8 => mapping(uint8 => RarityQuota)) public rarityQuotas;

    // 稀有度分发配置
    struct RarityDistribution {
        uint8[] sequence;           // 稀有度序列
        uint256 currentIndex;       // 当前序列位置
    }

    // 按包类型和角色存储稀有度分发配置: packType => characterType => distribution
    mapping(uint8 => mapping(uint8 => RarityDistribution)) private rarityDistributionConfig;

    // Pack rarity bonuses: packType => rarity bonuses array (index 0 unused)
    mapping(uint8 => int16[7]) public packRarityBonus;

    // Events
    event QuotaUpdated(uint8 character, uint8 rarity, uint256 total, bool limited);
    event RarityMinted(uint8 character, uint8 rarity);
    event RaritySequenceSet(uint8 packType, uint8 characterType, uint256 sequenceLength);
    event RarityWeightsUpdated(uint16[6] weights);
    event CharacterWeightsUpdated(uint16[5] weights);
    event PackRarityBonusUpdated(uint8 packType, int16[7] bonus);

    /**
     * @dev Constructor initializes the contract with default settings
     */
    constructor() Ownable(msg.sender) {
        // Initialize with default settings
    }

    /**
     * @dev Sets the weights for rarity distribution
     * @param weights Array of 6 weights that must sum to 10000
     */
    function setRarityWeights(uint16[6] calldata weights) external onlyOwner {
        uint32 sum = 0;
        for (uint8 i = 0; i < 6; i++) {
            sum += weights[i];
        }
        require(sum == 10000, "Weights must sum to 10000");
        rarityWeights = weights;
        emit RarityWeightsUpdated(weights);
    }

    /**
     * @dev Sets the weights for character distribution
     * @param weights Array of 5 weights that must sum to 10000
     */
    function setCharacterWeights(uint16[5] calldata weights) external onlyOwner {
        uint32 sum = 0;
        for (uint8 i = 0; i < 5; i++) {
            sum += weights[i];
        }
        require(sum == 10000, "Weights must sum to 10000");
        characterWeights = weights;
        emit CharacterWeightsUpdated(weights);
    }

    /**
     * @dev Sets bonuses for rarity weights based on pack type
     * @param packType The pack type to set bonuses for
     * @param bonus Array of 7 bonuses, index 0 is unused
     */
    function setPackRarityBonus(uint8 packType, int16[7] calldata bonus) external onlyOwner {
        packRarityBonus[packType] = bonus;
        emit PackRarityBonusUpdated(packType, bonus);
    }

    /**
     * @dev Sets quota for a specific rarity and character
     * @param character The character type
     * @param rarity The rarity level
     * @param total The total quota
     * @param limited Whether the supply is limited
     */
    function setRarityQuota(uint8 character, uint8 rarity, uint256 total, bool limited) external onlyOwner {
        rarityQuotas[character][rarity].total = total;
        rarityQuotas[character][rarity].limited = limited;
        emit QuotaUpdated(character, rarity, total, limited);
    }

    /**
     * @dev Sets quotas for multiple rarities and characters in batch
     * @param characters Array of character types
     * @param rarities Array of rarity levels
     * @param totals Array of quota totals
     * @param limitFlags Array of limitation flags
     */
    function setRarityQuotaBatch(
        uint8[] calldata characters,
        uint8[] calldata rarities,
        uint256[] calldata totals,
        bool[] calldata limitFlags
    ) external onlyOwner {
        require(
            characters.length == rarities.length &&
                rarities.length == totals.length &&
                totals.length == limitFlags.length,
            "Input arrays length mismatch"
        );

        for (uint256 i = 0; i < characters.length; i++) {
            rarityQuotas[characters[i]][rarities[i]].total = totals[i];
            rarityQuotas[characters[i]][rarities[i]].limited = limitFlags[i];
            emit QuotaUpdated(characters[i], rarities[i], totals[i], limitFlags[i]);
        }
    }

    /**
     * @dev Sets standard distribution percentages for a character
     * @param character The character to set distribution for
     * @param totalSupply The total supply to distribute
     */
    function setFixedDistribution(uint8 character, uint256 totalSupply) external onlyOwner {
        // Distribution: C:35%, N:35%, R:13%, RR:13%, SR:2%, SSR:2%
        rarityQuotas[character][RARITY_C] = RarityQuota((totalSupply * 35) / 100, 0, true);
        rarityQuotas[character][RARITY_N] = RarityQuota((totalSupply * 35) / 100, 0, true);
        rarityQuotas[character][RARITY_R] = RarityQuota((totalSupply * 13) / 100, 0, true);
        rarityQuotas[character][RARITY_RR] = RarityQuota((totalSupply * 13) / 100, 0, true);
        rarityQuotas[character][RARITY_SR] = RarityQuota((totalSupply * 2) / 100, 0, true);
        rarityQuotas[character][RARITY_SSR] = RarityQuota((totalSupply * 2) / 100, 0, true);

        // Emit events
        for (uint8 i = RARITY_C; i <= RARITY_SSR; i++) {
            emit QuotaUpdated(character, i, rarityQuotas[character][i].total, true);
        }
    }

    /**
     * @dev Checks if a rarity is available for a character
     * @param character The character type
     * @param rarity The rarity level
     * @return True if rarity is available, false otherwise
     */
    function isRarityAvailable(uint8 character, uint8 rarity) public view returns (bool) {
        if (!rarityQuotas[character][rarity].limited) {
            return true; // Unlimited supply
        }

        return rarityQuotas[character][rarity].minted < rarityQuotas[character][rarity].total;
    }

    /**
     * @dev Gets all available rarities for a character
     * @param character The character type
     * @return Array of available rarity levels
     */
    function getAvailableRarities(uint8 character) public view returns (uint8[] memory) {
        uint8 count = 0;

        // Count available rarities
        for (uint8 i = RARITY_C; i <= RARITY_SSR; i++) {
            if (isRarityAvailable(character, i)) {
                count++;
            }
        }

        // Create result array
        uint8[] memory availableRarities = new uint8[](count);
        uint8 index = 0;

        // Fill the array
        for (uint8 i = RARITY_C; i <= RARITY_SSR; i++) {
            if (isRarityAvailable(character, i)) {
                availableRarities[index] = i;
                index++;
            }
        }

        return availableRarities;
    }

    /**
     * @dev Records rarity usage when an NFT is minted
     * @param character The character type
     * @param rarity The rarity level
     */
    function recordRarityUsage(uint8 character, uint8 rarity) external {
        require(msg.sender == owner() || isAuthorizedCaller(msg.sender), "Not authorized");
        rarityQuotas[character][rarity].minted += 1;
        emit RarityMinted(character, rarity);
    }

    /**
     * @dev Gets a random character type based on weights
     * @param randomValue Random value input
     * @return Character type (1-based)
     */
    function getRandomCharacterType(uint256 randomValue) public view returns (uint8) {
        uint256 modValue = randomValue % 10000;
        uint256 cumulativeWeight = 0;

        for (uint8 i = 0; i < characterWeights.length; i++) {
            cumulativeWeight += characterWeights[i];
            if (modValue < cumulativeWeight) {
                return i + 1; // Character types start from 1
            }
        }

        return CHARACTER_GHOST; // Default to last character
    }

    /**
     * @dev 设置稀有度分发序列
     * @param packType 包类型
     * @param characterType 角色类型  
     * @param sequence 稀有度序列
     */
    function setRarityDistributionSequence(
        uint8 packType,
        uint8 characterType,
        uint8[] calldata sequence
    ) external onlyOwner {
        require(packType <= 1, "Invalid pack type");
        require(characterType >= 1 && characterType <= 5, "Invalid character type");
        require(sequence.length > 0, "Empty sequence");
        
        // 验证序列中的稀有度都在有效范围内
        for (uint256 i = 0; i < sequence.length; i++) {
            require(sequence[i] >= 1 && sequence[i] <= 6, "Invalid rarity in sequence");
        }
        
        RarityDistribution storage dist = rarityDistributionConfig[packType][characterType];
        delete dist.sequence;
        for (uint256 i = 0; i < sequence.length; i++) {
            dist.sequence.push(sequence[i]);
        }
        dist.currentIndex = 0;
        
        emit RaritySequenceSet(packType, characterType, sequence.length);
    }

    /**
     * @dev 序列化稀有度判定函数
     * @param packType 包类型
     * @param characterType 角色类型
     * @return 选择的稀有度等级
     */
    function determineRarityBySequence(uint8 packType, uint8 characterType) external returns (uint8) {
        require(msg.sender == owner() || isAuthorizedCaller(msg.sender), "Not authorized");
        require(packType <= 1, "Invalid pack type");
        require(characterType >= 1 && characterType <= 5, "Invalid character type");
        
        RarityDistribution storage dist = rarityDistributionConfig[packType][characterType];
        require(dist.sequence.length > 0, "No rarity sequence set");
        
        // 按序列获取稀有度
        uint8 rarity = dist.sequence[dist.currentIndex];
        
        // 更新序列索引（循环）
        dist.currentIndex = (dist.currentIndex + 1) % dist.sequence.length;
        
        // 记录使用情况
        rarityQuotas[characterType][rarity].minted += 1;
        emit RarityMinted(characterType, rarity);
        
        return rarity;
    }

    /**
     * @dev 获取稀有度分发序列信息
     * @param packType 包类型
     * @param characterType 角色类型
     * @return sequenceLength 序列长度
     * @return currentIndex 当前索引
     */
    function getRarityDistributionInfo(uint8 packType, uint8 characterType) 
        external view returns (uint256 sequenceLength, uint256 currentIndex) {
        RarityDistribution storage dist = rarityDistributionConfig[packType][characterType];
        return (dist.sequence.length, dist.currentIndex);
    }

    /**
     * @dev 获取稀有度分发序列
     * @param packType 包类型
     * @param characterType 角色类型
     * @return 稀有度序列
     */
    function getRarityDistributionSequence(uint8 packType, uint8 characterType) 
        external view returns (uint8[] memory) {
        return rarityDistributionConfig[packType][characterType].sequence;
    }

    // Authorized callers mapping
    mapping(address => bool) private authorizedCallers;

    /**
     * @dev Sets or removes authorized caller status
     * @param caller Address to authorize or deauthorize
     * @param authorized True to authorize, false to deauthorize
     */
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    /**
     * @dev Checks if an address is an authorized caller
     * @param caller Address to check
     * @return True if authorized, false otherwise
     */
    function isAuthorizedCaller(address caller) public view returns (bool) {
        return authorizedCallers[caller];
    }
}