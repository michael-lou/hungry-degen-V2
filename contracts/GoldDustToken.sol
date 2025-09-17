// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GoldDustToken
 * @dev Gold Dust Token for LP Staking V2 rewards
 * Features:
 * - Only authorized minters can mint tokens
 * - Only authorized transfer operators can transfer tokens
 * - Regular users cannot transfer tokens directly
 * - Used exclusively for Gold Pack purchases
 */
contract GoldDustToken is ERC20, Ownable {
    // 授权的铸造者（LP Staking V2）
    mapping(address => bool) public authorizedMinters;
    
    // 授权的转账操作者（PackMarketplace等合约）
    mapping(address => bool) public authorizedTransferOperators;
    
    // 事件
    event AuthorizedMinterUpdated(address indexed minter, bool authorized);
    event AuthorizedTransferOperatorUpdated(address indexed operator, bool authorized);
    
    modifier onlyAuthorizedMinter() {
        require(authorizedMinters[msg.sender], "GoldDust: Not authorized minter");
        _;
    }
    
    modifier onlyAuthorizedTransferOperator() {
        require(authorizedTransferOperators[msg.sender], "GoldDust: Not authorized transfer operator");
        _;
    }
    
    constructor(address _owner) ERC20("Gold Dust", "GOLDDUST") Ownable(_owner) {
        // 构造函数中设置初始所有者
    }
    
    /**
     * @dev 只有授权的合约可以铸造代币
     */
    function mint(address to, uint256 amount) external onlyAuthorizedMinter {
        _mint(to, amount);
    }
    
    /**
     * @dev 重写转账函数 - 只允许授权合约进行转账操作
     */
    function transfer(address to, uint256 amount) public override returns (bool) {
        require(authorizedTransferOperators[msg.sender], "GoldDust: Direct transfer not allowed");
        return super.transfer(to, amount);
    }
    
    /**
     * @dev 重写transferFrom函数 - 只允许授权合约进行转账操作
     */
    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        require(authorizedTransferOperators[msg.sender], "GoldDust: Direct transfer not allowed");
        return super.transferFrom(from, to, amount);
    }
    
    /**
     * @dev 设置授权铸造者
     */
    function setAuthorizedMinter(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "GoldDust: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit AuthorizedMinterUpdated(minter, authorized);
    }
    
    /**
     * @dev 设置授权转账操作者
     */
    function setAuthorizedTransferOperator(address operator, bool authorized) external onlyOwner {
        require(operator != address(0), "GoldDust: Invalid operator address");
        authorizedTransferOperators[operator] = authorized;
        emit AuthorizedTransferOperatorUpdated(operator, authorized);
    }
    
    /**
     * @dev 查询授权状态
     */
    function isAuthorizedMinter(address minter) external view returns (bool) {
        return authorizedMinters[minter];
    }
    
    function isAuthorizedTransferOperator(address operator) external view returns (bool) {
        return authorizedTransferOperators[operator];
    }
    
    /**
     * @dev 获取代币信息
     */
    function decimals() public view virtual override returns (uint8) {
        return 18;
    }
}
