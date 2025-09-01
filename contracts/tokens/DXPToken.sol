// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/**
 * @title DXPToken
 * @dev Abstract base contract for DXP tokens (Gold DXP and Silver DXP)
 */
abstract contract DXPToken is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    
    // 授权的铸造者（通常是ReferralV2合约）
    mapping(address => bool) public authorizedMinters;
    
    // 授权的销毁者（通常是角色升级合约）
    mapping(address => bool) public authorizedBurners;
    
    // DXP兑换ETH的汇率 (DXP per ETH * 1e18)
    uint256 public exchangeRate;
    
    // 白名单用户的额外奖励比例 (basis points, 10000 = 100%)
    uint256 public whitelistBonus;
    
    // 白名单地址
    mapping(address => bool) public whitelist;
    
    // 兑换功能是否启用
    bool public exchangeEnabled;
    
    // 事件
    event MinterAuthorized(address indexed minter, bool authorized);
    event BurnerAuthorized(address indexed burner, bool authorized);
    event ExchangeRateUpdated(uint256 newRate);
    event WhitelistBonusUpdated(uint256 newBonus);
    event WhitelistUpdated(address indexed user, bool status);
    event ExchangeEnabledUpdated(bool enabled);
    event DXPExchangedForETH(address indexed user, uint256 dxpAmount, uint256 ethAmount);

    function __DXPToken_init(
        string memory name,
        string memory symbol,
        uint256 _exchangeRate,
        uint256 _whitelistBonus
    ) internal onlyInitializing {
        __ERC20_init(name, symbol);
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        exchangeRate = _exchangeRate;
        whitelistBonus = _whitelistBonus;
        exchangeEnabled = false; // 默认关闭兑换功能
    }

    // ======== 铸造和销毁权限管理 ========
    
    function setMinterAuthorization(address minter, bool authorized) external onlyOwner {
        require(minter != address(0), "DXPToken: Invalid minter address");
        authorizedMinters[minter] = authorized;
        emit MinterAuthorized(minter, authorized);
    }
    
    function setBurnerAuthorization(address burner, bool authorized) external onlyOwner {
        require(burner != address(0), "DXPToken: Invalid burner address");
        authorizedBurners[burner] = authorized;
        emit BurnerAuthorized(burner, authorized);
    }

    // ======== 铸造和销毁功能 ========
    
    function mint(address to, uint256 amount) external {
        require(authorizedMinters[msg.sender], "DXPToken: Not authorized to mint");
        require(to != address(0), "DXPToken: Cannot mint to zero address");
        _mint(to, amount);
    }
    
    function burn(address from, uint256 amount) external {
        require(authorizedBurners[msg.sender], "DXPToken: Not authorized to burn");
        require(from != address(0), "DXPToken: Cannot burn from zero address");
        require(balanceOf(from) >= amount, "DXPToken: Insufficient balance to burn");
        _burn(from, amount);
    }

    // ======== 兑换功能配置 ========
    
    function setExchangeRate(uint256 _exchangeRate) external onlyOwner {
        require(_exchangeRate > 0, "DXPToken: Exchange rate must be greater than 0");
        exchangeRate = _exchangeRate;
        emit ExchangeRateUpdated(_exchangeRate);
    }
    
    function setWhitelistBonus(uint256 _whitelistBonus) external onlyOwner {
        require(_whitelistBonus <= 5000, "DXPToken: Whitelist bonus too high"); // 最多50%额外奖励
        whitelistBonus = _whitelistBonus;
        emit WhitelistBonusUpdated(_whitelistBonus);
    }
    
    function setWhitelist(address user, bool status) external onlyOwner {
        require(user != address(0), "DXPToken: Invalid user address");
        whitelist[user] = status;
        emit WhitelistUpdated(user, status);
    }
    
    function setExchangeEnabled(bool enabled) external onlyOwner {
        exchangeEnabled = enabled;
        emit ExchangeEnabledUpdated(enabled);
    }

    // ======== 兑换功能 ========
    
    function exchangeForETH(uint256 dxpAmount) external {
        require(exchangeEnabled, "DXPToken: Exchange is disabled");
        require(dxpAmount > 0, "DXPToken: Amount must be greater than 0");
        require(balanceOf(msg.sender) >= dxpAmount, "DXPToken: Insufficient DXP balance");
        
        // 计算可兑换的ETH数量
        uint256 ethAmount = (dxpAmount * 1e18) / exchangeRate;
        
        // 如果用户在白名单中，给予额外奖励
        if (whitelist[msg.sender]) {
            uint256 bonus = (ethAmount * whitelistBonus) / 10000;
            ethAmount += bonus;
        }
        
        require(address(this).balance >= ethAmount, "DXPToken: Insufficient contract ETH balance");
        
        // 销毁DXP
        _burn(msg.sender, dxpAmount);
        
        // 发送ETH
        (bool success, ) = payable(msg.sender).call{ value: ethAmount }("");
        require(success, "DXPToken: ETH transfer failed");
        
        emit DXPExchangedForETH(msg.sender, dxpAmount, ethAmount);
    }

    // ======== 查询功能 ========
    
    function getExchangeAmount(address user, uint256 dxpAmount) external view returns (uint256 ethAmount) {
        ethAmount = (dxpAmount * 1e18) / exchangeRate;
        
        // 如果用户在白名单中，计算额外奖励
        if (whitelist[user]) {
            uint256 bonus = (ethAmount * whitelistBonus) / 10000;
            ethAmount += bonus;
        }
        
        return ethAmount;
    }
    
    function isWhitelisted(address user) external view returns (bool) {
        return whitelist[user];
    }

    // ======== 管理员功能 ========
    
    // 向合约存入ETH用于兑换
    function depositETH() external payable onlyOwner {
        require(msg.value > 0, "DXPToken: Must send ETH");
    }
    
    // 提取合约中的ETH
    function withdrawETH(uint256 amount) external onlyOwner {
        require(amount > 0, "DXPToken: Amount must be greater than 0");
        require(address(this).balance >= amount, "DXPToken: Insufficient contract balance");
        
        (bool success, ) = payable(owner()).call{ value: amount }("");
        require(success, "DXPToken: ETH withdrawal failed");
    }
    
    // 紧急提取所有ETH
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "DXPToken: No ETH to withdraw");
        
        (bool success, ) = payable(owner()).call{ value: balance }("");
        require(success, "DXPToken: ETH withdrawal failed");
    }

    // ======== UUPS升级 ========
    
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
    
    // 接收ETH
    receive() external payable {}
}
