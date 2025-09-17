// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IUserBalanceManager {
    // 余额类型枚举
    enum BalanceType { 
        FOOD_BOX,     // 食物盒子余额 - 简单映射
        GOLD_PACK,    // 金包余额 - 三维映射
        BOX           // 盒子余额 - 三维映射
    }
    
    // 事件
    event BalanceIncreased(address indexed user, BalanceType indexed balanceType, uint256 amount);
    event BalanceDecreased(address indexed user, BalanceType indexed balanceType, uint256 amount);
    event GoldPackBalanceIncreased(address indexed user, uint8 packType, uint8 characterType, uint256 amount);
    event GoldPackBalanceDecreased(address indexed user, uint8 packType, uint8 characterType, uint256 amount);
    event BoxBalanceIncreased(address indexed user, uint8 packType, uint8 characterType, uint256 amount);
    event BoxBalanceDecreased(address indexed user, uint8 packType, uint8 characterType, uint256 amount);
    event AuthorizedContractUpdated(address indexed contractAddr, bool authorized);
    
    // ======== 食物盒子余额操作 (简单映射) ========
    
    /**
     * @dev 增加用户食物盒子余额
     * @param user 用户地址
     * @param amount 增加数量
     */
    function increaseFoodBoxBalance(address user, uint256 amount) external;
    
    /**
     * @dev 减少用户食物盒子余额
     * @param user 用户地址
     * @param amount 减少数量
     */
    function decreaseFoodBoxBalance(address user, uint256 amount) external;
    
    /**
     * @dev 获取用户食物盒子余额
     * @param user 用户地址
     * @return 食物盒子余额
     */
    function getFoodBoxBalance(address user) external view returns (uint256);
    
    // ======== 金包余额操作 (三维映射) ========
    
    /**
     * @dev 增加用户金包余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @param amount 增加数量
     */
    function increaseGoldPackBalance(address user, uint8 packType, uint8 characterType, uint256 amount) external;
    
    /**
     * @dev 减少用户金包余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @param amount 减少数量
     */
    function decreaseGoldPackBalance(address user, uint8 packType, uint8 characterType, uint256 amount) external;
    
    /**
     * @dev 获取用户金包余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @return 金包余额
     */
    function getGoldPackBalance(address user, uint8 packType, uint8 characterType) external view returns (uint256);
    
    // ======== 盒子余额操作 (三维映射) ========
    
    /**
     * @dev 增加用户盒子余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @param amount 增加数量
     */
    function increaseBoxBalance(address user, uint8 packType, uint8 characterType, uint256 amount) external;
    
    /**
     * @dev 减少用户盒子余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @param amount 减少数量
     */
    function decreaseBoxBalance(address user, uint8 packType, uint8 characterType, uint256 amount) external;
    
    /**
     * @dev 获取用户盒子余额
     * @param user 用户地址
     * @param packType 包类型
     * @param characterType 角色类型
     * @return 盒子余额
     */
    function getBoxBalance(address user, uint8 packType, uint8 characterType) external view returns (uint256);
    
    // ======== 管理函数 ========
    
    /**
     * @dev 设置授权合约
     * @param contractAddr 合约地址
     * @param authorized 是否授权
     */
    function setAuthorizedContract(address contractAddr, bool authorized) external;
    
    /**
     * @dev 检查合约是否被授权
     * @param contractAddr 合约地址
     * @return 是否被授权
     */
    function isAuthorizedContract(address contractAddr) external view returns (bool);
}
