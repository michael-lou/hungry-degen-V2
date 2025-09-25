// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

contract ConfigCenter is Initializable, OwnableUpgradeable, UUPSUpgradeable {

    // ---------------------------------------------------------------------
    // EXP SCALING
    // ---------------------------------------------------------------------
    // All experience related numbers (expRequiredForLevel, character exp values,
    // staking expPerBlock, upgrade exp increments) are interpreted as:
    //   storedValue = humanReadableValue * EXP_SCALER
    // Front-end / off-chain code that wants the human readable value should divide by EXP_SCALER.
    // We keep original variable names for minimal intrusive change.
    uint256 public constant EXP_SCALER = 1_000_000_000_000; // 1e12

    uint256 public TOTAL_REWARD_PER_BLOCK; // 奖励计算参数

    mapping(uint8 => mapping(uint8 => uint256)) public characterBaseWeight; // 稀有度基础权重 level => rarity => weight
    mapping(uint8 => mapping(uint8 => uint256)) public multiplier; // Multiplier for core and flex  rarity => level => multiplier

    // 损耗度参数
    uint8 public baseWearPerClaim; // 基础每次领取损耗度
    uint8 public rarityReduction; // 稀有度减少量
    uint8 public levelReduction; // 等级减少量


    // 角色升级所需经验
    mapping(uint8 => uint256) public expRequiredForLevel;

    // 角色类型权重系数 (1000 = 100%)
    mapping(uint8 => uint256) public characterTypeMultiplier;

    // core和flex升级所需物料数量
    mapping(uint8 => mapping(uint8 => uint256)) public equipmentUpgradeMaterialAmount; // rarity => level => amount

    // 修复损耗度所需DUST token
    mapping(uint8 => mapping(uint8 => uint256)) public repairCostByRarityAndLevel; // 按稀有度和等级
    mapping(uint8 => mapping(uint8 => uint256)) public repairETHCostByRarityAndLevel;
    bool public repairByEth;

    // 授权地址
    mapping(address => bool) public authorizedCallers;

    address public rewarder;

    event ConfigUpdated(string paramName, uint256 value);
    event RarityConfigUpdated(string paramName, uint8 rarity, uint256 value);
    event LevelConfigUpdated(string paramName, uint8 level, uint256 value);
    event RarityLevelConfigUpdated(string paramName, uint8 rarity, uint8 level, uint256 value);
    event CallerAuthorized(address caller, bool authorized);

    modifier onlyAuthorized() {
        require(owner() == _msgSender() || authorizedCallers[_msgSender()], "ConfigCenter: Not authorized");
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();

        // 设置默认参数
        TOTAL_REWARD_PER_BLOCK = 1000 * 10 ** 18; // 1000 DUST per block

        // 角色基础权重
        ///***
        /// level  c    R   RR   SR   SSR
        ///     1   12  14  20   36    40
        ///     2   16  18  26   47    52
        ///     3   20  24  34   61    68
        ///     4   26  31  44   79    88
        ///     5   34  40  57   103   114
        ///     6   45  52  74   134   149
        ///     7   58  68  97   174   193
        ///     8   75  88  125  226   251
        ///     9   98  114 163  294   326
        ///     10  196 228  326 587   653
        /// */
        characterBaseWeight[1][1] = 12;
        characterBaseWeight[1][2] = 14;
        characterBaseWeight[1][3] = 20;
        characterBaseWeight[1][4] = 36;
        characterBaseWeight[1][5] = 40;
        characterBaseWeight[2][1] = 16;
        characterBaseWeight[2][2] = 18;
        characterBaseWeight[2][3] = 26;
        characterBaseWeight[2][4] = 47;
        characterBaseWeight[2][5] = 52;
        characterBaseWeight[3][1] = 20;
        characterBaseWeight[3][2] = 24;
        characterBaseWeight[3][3] = 34;
        characterBaseWeight[3][4] = 61;
        characterBaseWeight[3][5] = 68;
        characterBaseWeight[4][1] = 26;
        characterBaseWeight[4][2] = 31;
        characterBaseWeight[4][3] = 44;
        characterBaseWeight[4][4] = 79;
        characterBaseWeight[4][5] = 88;
        characterBaseWeight[5][1] = 34;
        characterBaseWeight[5][2] = 40;
        characterBaseWeight[5][3] = 57;
        characterBaseWeight[5][4] = 103;
        characterBaseWeight[5][5] = 114;
        characterBaseWeight[6][1] = 45;
        characterBaseWeight[6][2] = 52;
        characterBaseWeight[6][3] = 74;
        characterBaseWeight[6][4] = 134;
        characterBaseWeight[6][5] = 149;
        characterBaseWeight[7][1] = 58;
        characterBaseWeight[7][2] = 68;
        characterBaseWeight[7][3] = 97;
        characterBaseWeight[7][4] = 174;
        characterBaseWeight[7][5] = 193;
        characterBaseWeight[8][1] = 75;
        characterBaseWeight[8][2] = 88;
        characterBaseWeight[8][3] = 125;
        characterBaseWeight[8][4] = 226;
        characterBaseWeight[8][5] = 251;
        characterBaseWeight[9][1] = 98;
        characterBaseWeight[9][2] = 114;
        characterBaseWeight[9][3] = 163;
        characterBaseWeight[9][4] = 294;
        characterBaseWeight[9][5] = 326;
        characterBaseWeight[10][1] = 196;
        characterBaseWeight[10][2] = 228;
        characterBaseWeight[10][3] = 326;
        characterBaseWeight[10][4] = 587;
        characterBaseWeight[10][5] = 653;

        // core和flex multiplier
        multiplier[1][1] = 1100; // 1100 / 1000 = 1.1
        multiplier[1][2] = 1300;
        multiplier[1][3] = 1600;
        multiplier[1][4] = 2000;
        multiplier[1][5] = 2500;
        multiplier[2][1] = 1150;
        multiplier[2][2] = 1450;
        multiplier[2][3] = 1900;
        multiplier[2][4] = 2500;
        multiplier[2][5] = 3500;
        multiplier[3][1] = 1300;
        multiplier[3][2] = 1600;
        multiplier[3][3] = 2200;
        multiplier[3][4] = 2800;
        multiplier[3][5] = 5000;
        multiplier[4][1] = 1500;
        multiplier[4][2] = 2000;
        multiplier[4][3] = 3000;
        multiplier[4][4] = 4000;
        multiplier[4][5] = 7000;
        multiplier[5][1] = 2000;
        multiplier[5][2] = 4000;
        multiplier[5][3] = 6000;
        multiplier[5][4] = 8000;
        multiplier[5][5] = 12000;
        multiplier[6][1] = 2000;
        multiplier[6][2] = 4000;
        multiplier[6][3] = 6000;
        multiplier[6][4] = 8000;
        multiplier[6][5] = 12000;

        // 损耗度参数
        baseWearPerClaim = 10;
        rarityReduction = 1;
        levelReduction = 1;

    // 角色等级所需经验 (Scaled). Human thresholds: 10,20,40,65,100,175,250,350,500
    // Stored as base * EXP_SCALER (replaces the previous *10000 pseudo-scaling)
    expRequiredForLevel[1] = 10 * EXP_SCALER; //1～2级
    expRequiredForLevel[2] = 20 * EXP_SCALER; //2～3级
    expRequiredForLevel[3] = 40 * EXP_SCALER; //3～4级
    expRequiredForLevel[4] = 65 * EXP_SCALER; //4～5级
    expRequiredForLevel[5] = 100 * EXP_SCALER; //5～6级
    expRequiredForLevel[6] = 175 * EXP_SCALER; //6～7级
    expRequiredForLevel[7] = 250 * EXP_SCALER; //7～8级
    expRequiredForLevel[8] = 350 * EXP_SCALER; //8～9级
    expRequiredForLevel[9] = 500 * EXP_SCALER; //9～10级

        // 角色类型权重系数 (1000 = 100%)
        characterTypeMultiplier[1] = 1000; // Airdrop Andy
        characterTypeMultiplier[2] = 1000; // Scammed Steve
        characterTypeMultiplier[3] = 1000; // Dustbag Danny
        characterTypeMultiplier[4] = 1000; // Leverage Larry
        characterTypeMultiplier[5] = 1000; // Trenches Ghost
        characterTypeMultiplier[6] = 50;   // BlackGhost (5%)

        // 升级所需物料数量
        equipmentUpgradeMaterialAmount[1][1] = 0;
        equipmentUpgradeMaterialAmount[2][1] = 0;
        equipmentUpgradeMaterialAmount[3][1] = 0;
        equipmentUpgradeMaterialAmount[4][1] = 0;
        equipmentUpgradeMaterialAmount[5][1] = 0;
        equipmentUpgradeMaterialAmount[6][1] = 0;
        equipmentUpgradeMaterialAmount[1][2] = 3;
        equipmentUpgradeMaterialAmount[2][2] = 3;
        equipmentUpgradeMaterialAmount[3][2] = 2;
        equipmentUpgradeMaterialAmount[4][2] = 2;
        equipmentUpgradeMaterialAmount[5][2] = 1;
        equipmentUpgradeMaterialAmount[6][2] = 1;
        equipmentUpgradeMaterialAmount[1][3] = 9;
        equipmentUpgradeMaterialAmount[2][3] = 9;
        equipmentUpgradeMaterialAmount[3][3] = 4;
        equipmentUpgradeMaterialAmount[4][3] = 4;
        equipmentUpgradeMaterialAmount[5][3] = 1;
        equipmentUpgradeMaterialAmount[6][3] = 1;
        equipmentUpgradeMaterialAmount[1][4] = 18;
        equipmentUpgradeMaterialAmount[2][4] = 18;
        equipmentUpgradeMaterialAmount[3][4] = 8;
        equipmentUpgradeMaterialAmount[4][4] = 8;
        equipmentUpgradeMaterialAmount[5][4] = 2;
        equipmentUpgradeMaterialAmount[6][4] = 2;
        equipmentUpgradeMaterialAmount[1][5] = 27;
        equipmentUpgradeMaterialAmount[2][5] = 27;
        equipmentUpgradeMaterialAmount[3][5] = 12;
        equipmentUpgradeMaterialAmount[4][5] = 12;
        equipmentUpgradeMaterialAmount[5][5] = 2;
        equipmentUpgradeMaterialAmount[6][5] = 2;
    }

    //settings
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "ConfigCenter: Invalid caller");
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }

    function setRewarder(address _rewarder) external onlyOwner {
        require(_rewarder != address(0), "ConfigCenter: Invalid rewarder");
        rewarder = _rewarder;
    }

    function updateTotalRewardPerBlock(uint256 value) external onlyOwner {
        // Staking(stakingAddress).updateAccumulatorExternal();
        TOTAL_REWARD_PER_BLOCK = value;
        emit ConfigUpdated("TOTAL_REWARD_PER_BLOCK", value);
    }

    function updateMultiplier(uint8 rarity, uint8 level, uint256 value) external onlyOwner {
        require(rarity >= 1 && rarity <= 6, "ConfigCenter: Invalid rarity");
        require(level >= 1 && level <= 5, "ConfigCenter: Invalid level");
        multiplier[rarity][level] = value;
        emit RarityLevelConfigUpdated("multiplier", rarity, level, value);
    }

    function updateCharacterBaseWeight(uint8 level, uint8 rarity, uint256 value) external onlyOwner {
        require(level >= 1, "ConfigCenter: Invalid level");
        require(rarity >= 1, "ConfigCenter: Invalid rarity");
        characterBaseWeight[level][rarity] = value;
        emit LevelConfigUpdated("characterBaseWeight", level, value);
    }

    function updateCharacterTypeMultiplier(uint8 characterType, uint256 multiplierValue) external onlyOwner {
        require(characterType >= 1 && characterType <= 6, "ConfigCenter: Invalid character type");
        require(multiplierValue <= 1000, "ConfigCenter: Multiplier cannot exceed 100%");
        characterTypeMultiplier[characterType] = multiplierValue;
        emit RarityConfigUpdated("characterTypeMultiplier", characterType, multiplierValue);
    }

    function updateWearParameters(
        uint8 _baseWearPerClaim,
        uint8 _rarityReduction,
        uint8 _levelReduction
    ) external onlyOwner {
        require(_baseWearPerClaim > 0, "ConfigCenter: Invalid baseWearPerClaim");
        baseWearPerClaim = _baseWearPerClaim;
        rarityReduction = _rarityReduction;
        levelReduction = _levelReduction;

        emit ConfigUpdated("baseWearPerClaim", _baseWearPerClaim);
    }

    function updateExpRequiredForLevel(uint8 level, uint256 value) external onlyOwner {
        require(level >= 1 && level <= 10, "ConfigCenter: Invalid level");
        require(value >= 0, "ConfigCenter: Invalid value");
        expRequiredForLevel[level] = value;
        emit LevelConfigUpdated("expRequiredForLevel", level, value);
    }

    function updateRepairCost(uint256 baseCost) external onlyOwner {
        require(baseCost > 0, "ConfigCenter: Invalid baseCost");
        // 修复成本随稀有度和等级增加
        for (uint8 r = 1; r <= 6; r++) {
            for (uint8 l = 1; l <= 5; l++) {
                repairCostByRarityAndLevel[r][l] = baseCost * (r + 1) * l;
                emit RarityLevelConfigUpdated("repairCostByRarityAndLevel", r, l, baseCost * (r + 1) * l);
            }
        }
    }

    function updateRepairETHCost(uint256 baseCost) external onlyOwner {
        require(baseCost > 0, "ConfigCenter: Invalid baseCost");
        // 修复成本随稀有度和等级增加
        for (uint8 r = 1; r <= 6; r++) {
            for (uint8 l = 1; l <= 5; l++) {
                repairETHCostByRarityAndLevel[r][l] = baseCost * (r + 1) * l;
                emit RarityLevelConfigUpdated("repairCostByRarityAndLevel", r, l, baseCost * (r + 1) * l);
            }
        }
    }

    function setRepairByEth(bool _repairByEth) external onlyOwner {
        repairByEth = _repairByEth;
        emit ConfigUpdated("repairByEth", _repairByEth ? 1 : 0);
    }
    function setequipmentUpgradeMaterialAmount(uint8 rarity, uint8 level, uint256 amount) external onlyOwner {
        require(rarity> 0 && rarity <= 6, "ConfigCenter: Invalid rarity");
        require(level <= 5, "ConfigCenter: Invalid level");
        require(amount >= 0, "ConfigCenter: Invalid amount");
        equipmentUpgradeMaterialAmount[rarity][level] = amount;
        emit RarityConfigUpdated("equipmentUpgradeMaterialAmount", level, amount);
    }
    // view function
    // 获取角色升级所需的经验值
    function getExpForLevel(uint8 level) external view returns (uint256) {
        require(level >= 1, "ConfigCenter: Invalid level");
        return expRequiredForLevel[level];
    }

    // 根据经验值计算等级
    function calculateLevel(uint256 exp) external view returns (uint8) {
        for (uint8 i = 9; i >= 1; i--) {
            if (exp >= expRequiredForLevel[i]) {
                return i + 1; // 返回升级后的等级
            }
        }
        return 1; // 默认等级是1
    }

    // 计算损耗度增加值
    function calculateWearIncrease(uint8 /* rarity */, uint8 level) external view returns (uint8) {
        // 等级为0的装备不应该被装配，这里返回最大损耗作为惩罚
        if (level == 0) {
            return 100; // 返回高损耗值作为错误指示
        }
        
        // 简化磨损度计算：直接返回基础磨损度
        return baseWearPerClaim;
    }

    function calculateMaterialAmountToLevel(uint8 rarity, uint256 materialAmount) external view returns (uint8 ,uint256) {
        uint8 level = 0;
        uint256 remainderMaterial = 0;
        for (uint8 i = 1; i <= 5; i++) {
            if (materialAmount >= equipmentUpgradeMaterialAmount[rarity][i]) {
                level = i;
            } else {
                remainderMaterial = materialAmount - equipmentUpgradeMaterialAmount[rarity][level];
                break;
            }
        }
        return (level, remainderMaterial);
    }
    // 获取修复损耗度所需的DUST token
    function getRepairCost(uint8 rarity, uint8 level, uint8 wear) external view returns (uint256) {
        require(rarity <= 6, "Invalid rarity");
        require(level >= 1, "Invalid level");

        uint256 cost;
        if (repairByEth) {
            cost = (repairETHCostByRarityAndLevel[rarity][level] * wear) / 100;
        } else {
            cost = (repairCostByRarityAndLevel[rarity][level] * wear) / 100;
        }
        // 基础修复成本 * 损耗度百分比
        return cost;
    }

    function getRewarder() external view returns (address) {
        return rewarder;
    }

    function getCharacterTypeMultiplier(uint8 characterType) external view returns (uint256) {
        require(characterType >= 1 && characterType <= 6, "ConfigCenter: Invalid character type");
        return characterTypeMultiplier[characterType];
    }


    function getAllEquipmentUpgradeMaterialAmount() external view returns (uint256[][] memory) {
        uint256[][] memory amounts = new uint256[][](6);
        for (uint8 r = 1; r <= 6; r++) {
            amounts[r - 1] = new uint256[](5);
            for (uint8 l = 1; l <= 5; l++) {
                amounts[r - 1][l - 1] = equipmentUpgradeMaterialAmount[r][l];
            }
        }
        return amounts;
    }
    // UUPS升级所需函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
