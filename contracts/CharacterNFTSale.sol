// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "./CharacterNFT.sol";
import "./interfaces/IReferralV2.sol";

contract CharacterNFTSale is
    Initializable,
    OwnableUpgradeable,
    UUPSUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{
    CharacterNFT public characterNFT;
    IReferralV2 public referralV2;

    // 销售配置
    uint256 public price; // 每个 NFT 的价格
    address public treasury; // Treasury 钱包地址

    // 待售 NFT 队列
    uint256[] public tokensForSale;
    uint256 public currentSaleIndex; // 当前销售的索引

    // 用户购买记录
    mapping(address => uint256[]) public userPurchasedTokens;

    // 事件
    event CharacterNFTPurchased(address indexed buyer, uint256 indexed tokenId, uint256 price);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event TokensAddedForSale(uint256[] tokenIds);
    event TokensRemovedFromSale(uint256[] tokenIds);

    modifier onlySaleActive() {
        require(currentSaleIndex < tokensForSale.length, "CharacterNFTSale: No tokens available for sale");
        _;
    }

    function initialize(address _characterNFT, uint256 _price, address _treasury, address _referralV2) public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        require(_characterNFT != address(0), "CharacterNFTSale: Invalid CharacterNFT address");
        require(_price > 0, "CharacterNFTSale: Invalid price");
        require(_treasury != address(0), "CharacterNFTSale: Invalid treasury address");

        characterNFT = CharacterNFT(_characterNFT);
        price = _price;
        treasury = _treasury;
        if (_referralV2 != address(0)) {
            referralV2 = IReferralV2(_referralV2);
        }
        currentSaleIndex = 0;
    }

    /**
     * @dev 购买 CharacterNFT
     * 按照队列顺序出售 NFT
     */
    function purchaseCharacterNFT(address referrerAddress) external payable nonReentrant whenNotPaused onlySaleActive {
        require(msg.value >= price, "CharacterNFTSale: Insufficient payment");

        // 获取当前要出售的 token ID
        uint256 tokenId = tokensForSale[currentSaleIndex];

        // 确保合约拥有该 NFT
        require(characterNFT.ownerOf(tokenId) == address(this), "CharacterNFTSale: Contract doesn't own this token");

        // 处理推荐奖励 - 使用ReferralV2系统
        uint256 treasuryAmount = price;
        if (address(referralV2) != address(0)) {
            // 获取推荐人 - 直接从ReferralV2获取
            address currentReferrer = referralV2.getReferrer(msg.sender);
            if (currentReferrer == address(0) && referrerAddress != address(0)) {
                // 如果没有推荐人但提供了referrer参数，尝试注册推荐关系
                referralV2.registerReferral(msg.sender, referrerAddress);
                currentReferrer = referrerAddress;
            }
            
            // 使用新的推荐系统记录销售和分发奖励
            referralV2.recordSaleAndDistributeRewards(
                msg.sender,
                currentReferrer,
                IReferralV2.ProductType.CHARACTER_NFT,
                price
            );
            
            // 计算推荐奖励金额（CHARACTER_NFT的标准佣金率是12% = 1200 basis points）
            if (currentReferrer != address(0)) {
                uint256 referralReward = (price * 1200) / 10000; // 12%
                treasuryAmount = price - referralReward;
            }
        }

        // 转移 NFT 到购买者
        characterNFT.transferFrom(address(this), msg.sender, tokenId);

        // 记录购买
        userPurchasedTokens[msg.sender].push(tokenId);

        // 移动到下一个 token
        currentSaleIndex++;

        emit CharacterNFTPurchased(msg.sender, tokenId, msg.value);

        // 将支付金额发送到 treasury（扣除推荐奖励后）
        if (treasuryAmount > 0) {
            (bool treasurySuccess, ) = payable(treasury).call{ value: treasuryAmount }("");
            require(treasurySuccess, "CharacterNFTSale: Treasury transfer failed");
        }

        // 退还多余的 ETH
        if (msg.value > price) {
            (bool refundSuccess, ) = payable(msg.sender).call{ value: msg.value - price }("");
            require(refundSuccess, "CharacterNFTSale: ETH refund failed");
        }
    }

    /**
     * @dev 批量添加 NFT 到销售队列
     * 只有 owner 可以调用
     */
    function addTokensForSale(uint256[] calldata tokenIds) external onlyOwner {
        require(tokenIds.length > 0, "CharacterNFTSale: Empty token array");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(characterNFT.ownerOf(tokenIds[i]) == address(this), "CharacterNFTSale: Contract doesn't own token");
            tokensForSale.push(tokenIds[i]);
        }

        emit TokensAddedForSale(tokenIds);
    }

    /**
     * @dev 从销售队列中移除指定的 NFT
     * 只有 owner 可以调用
     */
    function removeTokensFromSale(uint256[] calldata tokenIds) external onlyOwner {
        require(tokenIds.length > 0, "CharacterNFTSale: Empty token array");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];

            // 找到并移除 token
            for (uint256 j = currentSaleIndex; j < tokensForSale.length; j++) {
                if (tokensForSale[j] == tokenId) {
                    // 将最后一个元素移到当前位置
                    tokensForSale[j] = tokensForSale[tokensForSale.length - 1];
                    tokensForSale.pop();
                    break;
                }
            }
        }

        emit TokensRemovedFromSale(tokenIds);
    }

    /**
     * @dev 更新价格
     * 只有 owner 可以调用
     */
    function updatePrice(uint256 _newPrice) external onlyOwner {
        require(_newPrice > 0, "CharacterNFTSale: Invalid price");

        uint256 oldPrice = price;
        price = _newPrice;

        emit PriceUpdated(oldPrice, _newPrice);
    }

    /**
     * @dev 更新 treasury 地址
     * 只有 owner 可以调用
     */
    function updateTreasury(address _newTreasury) external onlyOwner {
        require(_newTreasury != address(0), "CharacterNFTSale: Invalid treasury address");

        address oldTreasury = treasury;
        treasury = _newTreasury;

        emit TreasuryUpdated(oldTreasury, _newTreasury);
    }

    /**
     * @dev 更新 ReferralV2 地址
     * 只有 owner 可以调用
     */
    function setReferralV2(address _referralV2) external onlyOwner {
        require(_referralV2 != address(0), "CharacterNFTSale: Invalid referralV2 address");
        referralV2 = IReferralV2(_referralV2);
    }

    /**
     * @dev 暂停销售
     * 只有 owner 可以调用
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev 恢复销售
     * 只有 owner 可以调用
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @dev 紧急提取 NFT
     * 只有 owner 可以调用
     */
    function emergencyWithdrawNFT(uint256 tokenId) external onlyOwner {
        require(characterNFT.ownerOf(tokenId) == address(this), "CharacterNFTSale: Contract doesn't own token");
        characterNFT.transferFrom(address(this), msg.sender, tokenId);
    }

    /**
     * @dev 紧急提取 ETH
     * 只有 owner 可以调用
     */
    function emergencyWithdrawETH() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "CharacterNFTSale: No ETH to withdraw");
        payable(msg.sender).transfer(balance);
    }

    // ============ View Functions ============

    /**
     * @dev 检查销售是否活跃
     */
    function isSaleActive() external view returns (bool) {
        return currentSaleIndex < tokensForSale.length && !paused();
    }

    /**
     * @dev 获取可用的 NFT 数量
     */
    function getAvailableTokenCount() external view returns (uint256) {
        if (currentSaleIndex >= tokensForSale.length) {
            return 0;
        }
        return tokensForSale.length - currentSaleIndex;
    }

    /**
     * @dev 获取下一个要出售的 token ID
     */
    function getNextTokenForSale() external view returns (uint256) {
        require(currentSaleIndex < tokensForSale.length, "CharacterNFTSale: No tokens available");
        return tokensForSale[currentSaleIndex];
    }

    /**
     * @dev 获取用户购买的所有 token ID
     */
    function getUserPurchasedTokens(address user) external view returns (uint256[] memory) {
        return userPurchasedTokens[user];
    }

    /**
     * @dev 获取用户购买的 NFT 数量
     */
    function getUserPurchaseCount(address user) external view returns (uint256) {
        return userPurchasedTokens[user].length;
    }

    /**
     * @dev 获取所有待售的 token ID
     */
    function getTokensForSale() external view returns (uint256[] memory) {
        return tokensForSale;
    }

    /**
     * @dev 获取销售统计信息
     */
    function getSaleStats()
        external
        view
        returns (
            uint256 _totalTokens,
            uint256 _soldTokens,
            uint256 _availableTokens,
            uint256 _currentPrice,
            bool _isActive
        )
    {
        return (
            tokensForSale.length,
            currentSaleIndex,
            tokensForSale.length > currentSaleIndex ? tokensForSale.length - currentSaleIndex : 0,
            price,
            this.isSaleActive()
        );
    }

    /**
     * @dev 获取指定范围的待售 token ID
     */
    function getTokensForSaleRange(uint256 start, uint256 end) external view returns (uint256[] memory) {
        require(start < tokensForSale.length, "CharacterNFTSale: Start index out of bounds");
        require(end <= tokensForSale.length, "CharacterNFTSale: End index out of bounds");
        require(start < end, "CharacterNFTSale: Invalid range");

        uint256[] memory result = new uint256[](end - start);
        for (uint256 i = start; i < end; i++) {
            result[i - start] = tokensForSale[i];
        }
        return result;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
