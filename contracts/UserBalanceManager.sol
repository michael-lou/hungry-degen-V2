// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./interfaces/IUserBalanceManager.sol";

/**
 * @title UserBalanceManager
 * @dev 统一管理用户在不同合约中的余额数据
 * 支持三种不同的数据结构：
 * 1. FoodBox - 简单映射 (address => uint256)
 * 2. GoldPack - 三维映射 (address => packType => characterType => uint256)
 * 3. Box - 三维映射 (address => packType => characterType => uint256)
 */
contract UserBalanceManager is 
    Initializable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    UUPSUpgradeable,
    IUserBalanceManager 
{
    // ======== 状态变量 ========
    
    // 授权的操作合约映射
    mapping(address => bool) public authorizedContracts;
    
    // 食物盒子余额 - 简单映射 (用户 => 数量)
    mapping(address => uint256) public foodBoxBalances;
    
    // 金包余额 - 三维映射 (用户 => 包类型 => 角色类型 => 数量)
    mapping(address => mapping(uint8 => mapping(uint8 => uint256))) public goldPackBalances;
    
    // 盒子余额 - 三维映射 (用户 => 包类型 => 角色类型 => 数量)
    mapping(address => mapping(uint8 => mapping(uint8 => uint256))) public boxBalances;
    
    // ======== 修饰符 ========
    
    modifier onlyAuthorized() {
        require(authorizedContracts[msg.sender] || msg.sender == owner(), "UserBalanceManager: Unauthorized caller");
        _;
    }
    
    // ======== 初始化 ========
    
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }
    
    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __UUPSUpgradeable_init();
    }
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // ======== 食物盒子余额操作 (简单映射) ========
    
    function increaseFoodBoxBalance(address user, uint256 amount) external onlyAuthorized whenNotPaused {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        
        foodBoxBalances[user] += amount;
        
        emit BalanceIncreased(user, BalanceType.FOOD_BOX, amount);
    }
    
    function decreaseFoodBoxBalance(address user, uint256 amount) external onlyAuthorized whenNotPaused {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        require(foodBoxBalances[user] >= amount, "UserBalanceManager: Insufficient food box balance");
        
        foodBoxBalances[user] -= amount;
        
        emit BalanceDecreased(user, BalanceType.FOOD_BOX, amount);
    }
    
    function getFoodBoxBalance(address user) external view returns (uint256) {
        return foodBoxBalances[user];
    }
    
    // ======== 金包余额操作 (三维映射) ========
    
    function increaseGoldPackBalance(address user, uint8 packType, uint8 characterType, uint256 amount) 
        external onlyAuthorized whenNotPaused 
    {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        
        goldPackBalances[user][packType][characterType] += amount;
        
        emit GoldPackBalanceIncreased(user, packType, characterType, amount);
        emit BalanceIncreased(user, BalanceType.GOLD_PACK, amount);
    }
    
    function decreaseGoldPackBalance(address user, uint8 packType, uint8 characterType, uint256 amount) 
        external onlyAuthorized whenNotPaused 
    {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        require(goldPackBalances[user][packType][characterType] >= amount, 
                "UserBalanceManager: Insufficient gold pack balance");
        
        goldPackBalances[user][packType][characterType] -= amount;
        
        emit GoldPackBalanceDecreased(user, packType, characterType, amount);
        emit BalanceDecreased(user, BalanceType.GOLD_PACK, amount);
    }
    
    function getGoldPackBalance(address user, uint8 packType, uint8 characterType) 
        external view returns (uint256) 
    {
        return goldPackBalances[user][packType][characterType];
    }
    
    // ======== 盒子余额操作 (三维映射) ========
    
    function increaseBoxBalance(address user, uint8 packType, uint8 characterType, uint256 amount) 
        external onlyAuthorized whenNotPaused 
    {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        
        boxBalances[user][packType][characterType] += amount;
        
        emit BoxBalanceIncreased(user, packType, characterType, amount);
        emit BalanceIncreased(user, BalanceType.BOX, amount);
    }
    
    function decreaseBoxBalance(address user, uint8 packType, uint8 characterType, uint256 amount) 
        external onlyAuthorized whenNotPaused 
    {
        require(user != address(0), "UserBalanceManager: Invalid user address");
        require(amount > 0, "UserBalanceManager: Amount must be greater than 0");
        require(boxBalances[user][packType][characterType] >= amount, 
                "UserBalanceManager: Insufficient box balance");
        
        boxBalances[user][packType][characterType] -= amount;
        
        emit BoxBalanceDecreased(user, packType, characterType, amount);
        emit BalanceDecreased(user, BalanceType.BOX, amount);
    }
    
    function getBoxBalance(address user, uint8 packType, uint8 characterType) 
        external view returns (uint256) 
    {
        return boxBalances[user][packType][characterType];
    }
    
    // ======== 批量查询函数 ========
    
    /**
     * @dev 批量获取用户的金包余额
     * @param user 用户地址
     * @param packTypes 包类型数组
     * @param characterTypes 角色类型数组
     * @return balances 对应的余额数组
     */
    function getGoldPackBalancesBatch(
        address user, 
        uint8[] calldata packTypes, 
        uint8[] calldata characterTypes
    ) external view returns (uint256[] memory balances) {
        require(packTypes.length == characterTypes.length, "UserBalanceManager: Array length mismatch");
        
        balances = new uint256[](packTypes.length);
        for (uint256 i = 0; i < packTypes.length; i++) {
            balances[i] = goldPackBalances[user][packTypes[i]][characterTypes[i]];
        }
    }
    
    /**
     * @dev 批量获取用户的盒子余额
     * @param user 用户地址
     * @param packTypes 包类型数组
     * @param characterTypes 角色类型数组
     * @return balances 对应的余额数组
     */
    function getBoxBalancesBatch(
        address user, 
        uint8[] calldata packTypes, 
        uint8[] calldata characterTypes
    ) external view returns (uint256[] memory balances) {
        require(packTypes.length == characterTypes.length, "UserBalanceManager: Array length mismatch");
        
        balances = new uint256[](packTypes.length);
        for (uint256 i = 0; i < packTypes.length; i++) {
            balances[i] = boxBalances[user][packTypes[i]][characterTypes[i]];
        }
    }
    
    // ======== 管理函数 ========
    
    function setAuthorizedContract(address contractAddr, bool authorized) external onlyOwner {
        require(contractAddr != address(0), "UserBalanceManager: Invalid contract address");
        
        authorizedContracts[contractAddr] = authorized;
        
        emit AuthorizedContractUpdated(contractAddr, authorized);
    }
    
    function isAuthorizedContract(address contractAddr) external view returns (bool) {
        return authorizedContracts[contractAddr];
    }
    
    // ======== 紧急功能 ========
    
    function pause() external onlyOwner {
        _pause();
    }
    
    function unpause() external onlyOwner {
        _unpause();
    }
    
    /**
     * @dev 紧急情况下的余额迁移功能
     * @param users 用户地址数组
     * @param newFoodBoxBalances 新的食物盒子余额数组
     */
    function emergencyMigrateFoodBoxBalances(
        address[] calldata users, 
        uint256[] calldata newFoodBoxBalances
    ) external onlyOwner whenPaused {
        require(users.length == newFoodBoxBalances.length, "UserBalanceManager: Array length mismatch");
        
        for (uint256 i = 0; i < users.length; i++) {
            foodBoxBalances[users[i]] = newFoodBoxBalances[i];
        }
    }
    
    /**
     * @dev 紧急情况下的金包余额迁移功能
     * @param users 用户地址数组
     * @param packTypes 包类型数组
     * @param characterTypes 角色类型数组
     * @param newBalances 新的余额数组
     */
    function emergencyMigrateGoldPackBalances(
        address[] calldata users,
        uint8[] calldata packTypes,
        uint8[] calldata characterTypes,
        uint256[] calldata newBalances
    ) external onlyOwner whenPaused {
        require(
            users.length == packTypes.length && 
            packTypes.length == characterTypes.length && 
            characterTypes.length == newBalances.length, 
            "UserBalanceManager: Array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            goldPackBalances[users[i]][packTypes[i]][characterTypes[i]] = newBalances[i];
        }
    }
    
    /**
     * @dev 紧急情况下的盒子余额迁移功能
     * @param users 用户地址数组
     * @param packTypes 包类型数组
     * @param characterTypes 角色类型数组
     * @param newBalances 新的余额数组
     */
    function emergencyMigrateBoxBalances(
        address[] calldata users,
        uint8[] calldata packTypes,
        uint8[] calldata characterTypes,
        uint256[] calldata newBalances
    ) external onlyOwner whenPaused {
        require(
            users.length == packTypes.length && 
            packTypes.length == characterTypes.length && 
            characterTypes.length == newBalances.length, 
            "UserBalanceManager: Array length mismatch"
        );
        
        for (uint256 i = 0; i < users.length; i++) {
            boxBalances[users[i]][packTypes[i]][characterTypes[i]] = newBalances[i];
        }
    }
    
    // ======== 查询统计函数 ========
    
    /**
     * @dev 获取用户的完整余额概览
     * @param user 用户地址
     * @return foodBoxBalance 食物盒子余额
     */
    function getUserBalanceOverview(address user) external view returns (uint256 foodBoxBalance) {
        return foodBoxBalances[user];
    }
    
    /**
     * @dev 检查用户是否有任何余额
     * @param user 用户地址
     * @return hasBalance 是否有余额
     */
    function hasAnyBalance(address user) external view returns (bool hasBalance) {
        // 检查食物盒子余额
        if (foodBoxBalances[user] > 0) {
            return true;
        }
        
        // 注意：检查所有金包和盒子余额会消耗大量gas，这里简化处理
        // 在实际使用中，可以根据需要优化此函数
        return false;
    }
}
