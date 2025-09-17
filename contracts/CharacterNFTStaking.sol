// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./interfaces/ICharacterNFT.sol";
import "./interfaces/IBlackGhostNFT.sol";
import "./interfaces/IConfigCenter.sol";

contract CharacterNFTStaking is 
    Initializable, 
    OwnableUpgradeable, 
    PausableUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable,
    IERC721Receiver 
{
    // NFT类型枚举
    enum NFTType { CHARACTER, BLACKGHOST }

    // 质押配置
    struct StakingConfig {
        uint256 expPerBlock;    // 每个区块每个NFT的EXP奖励
        uint256 endBlock;       // 结束区块
        bool active;            // 池子是否激活
    }

    // 质押信息
    struct StakeInfo {
        uint256 tokenId;        // 质押的NFT ID
        uint256 startBlock;     // 开始质押的区块
        uint256 lastRewardBlock; // 上次计算奖励的区块
        uint256 accumulatedExp; // 累积经验值
        NFTType nftType;        // NFT类型
    }

    ICharacterNFT public characterNFT;
    IBlackGhostNFT public blackGhostNFT;
    IConfigCenter public configCenter;
    StakingConfig public stakingConfig;

    // 用户质押记录
    mapping(address => uint256[]) public userStakedTokens; // 用户质押的token列表
    mapping(uint256 => StakeInfo) public stakeInfos; // tokenId => StakeInfo
    mapping(uint256 => address) public tokenStakers; // tokenId => staker地址
    mapping(address => mapping(uint256 => uint256)) public userTokenIndex; // 用户token在数组中的索引

    // 全局统计
    uint256 public totalStakedTokens;
    uint256 public totalExpRewarded;

    // 事件
    event TokenStaked(address indexed user, uint256 indexed tokenId, uint256 blockNumber);
    event TokenUnstaked(address indexed user, uint256 indexed tokenId, uint256 expGained, uint256 blockNumber);
    event TokensStakedBatch(address indexed user, uint256[] tokenIds, uint256 blockNumber);
    event TokensUnstakedBatch(address indexed user, uint256[] tokenIds, uint256 totalExpGained, uint256 blockNumber);
    event ConfigUpdated(uint256 expPerBlock, uint256 endBlock, bool active);
    event ExpClaimed(address indexed user, uint256 indexed tokenId, uint256 expAmount);
    event BlackGhostNFTUpdated(address indexed oldAddress, address indexed newAddress);
    event CharacterNFTUpdated(address indexed oldAddress, address indexed newAddress);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _characterNFT,
        address _blackGhostNFT,
        address _configCenter,
        uint256 _expPerBlock,
        uint256 _endBlock
    ) public initializer {
        __Ownable_init(msg.sender);
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        require(_characterNFT != address(0), "CharacterNFTStaking: Invalid CharacterNFT address");
        require(_blackGhostNFT != address(0), "CharacterNFTStaking: Invalid BlackGhostNFT address");
        require(_configCenter != address(0), "CharacterNFTStaking: Invalid ConfigCenter address");
        require(_expPerBlock > 0, "CharacterNFTStaking: Invalid exp per block");
        require(_endBlock > block.number, "CharacterNFTStaking: Invalid end block");

        characterNFT = ICharacterNFT(_characterNFT);
        blackGhostNFT = IBlackGhostNFT(_blackGhostNFT);
        configCenter = IConfigCenter(_configCenter);
        stakingConfig = StakingConfig({
            expPerBlock: _expPerBlock,
            endBlock: _endBlock,
            active: true
        });
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // 质押单个Character NFT
    function stakeCharacter(uint256 tokenId) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(characterNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
        require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

        // 转移NFT到合约
        characterNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        // 创建质押记录
        stakeInfos[tokenId] = StakeInfo({
            tokenId: tokenId,
            startBlock: block.number,
            lastRewardBlock: block.number,
            accumulatedExp: 0,
            nftType: NFTType.CHARACTER
        });

        // 更新用户记录
        userStakedTokens[msg.sender].push(tokenId);
        userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
        tokenStakers[tokenId] = msg.sender;
        totalStakedTokens++;

        emit TokenStaked(msg.sender, tokenId, block.number);
    }

    // 质押单个BlackGhost NFT
    function stakeBlackGhost(uint256 tokenId) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(blackGhostNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
        require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

        // 转移NFT到合约
        blackGhostNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        // 创建质押记录
        stakeInfos[tokenId] = StakeInfo({
            tokenId: tokenId,
            startBlock: block.number,
            lastRewardBlock: block.number,
            accumulatedExp: 0,
            nftType: NFTType.BLACKGHOST
        });

        // 更新用户记录
        userStakedTokens[msg.sender].push(tokenId);
        userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
        tokenStakers[tokenId] = msg.sender;
        totalStakedTokens++;

        emit TokenStaked(msg.sender, tokenId, block.number);
    }

    // 兼容性函数 - 保持原有的 stake 函数作为 stakeCharacter 的别名
    function stake(uint256 tokenId) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(characterNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
        require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

        // 转移NFT到合约
        characterNFT.safeTransferFrom(msg.sender, address(this), tokenId);

        // 创建质押记录
        stakeInfos[tokenId] = StakeInfo({
            tokenId: tokenId,
            startBlock: block.number,
            lastRewardBlock: block.number,
            accumulatedExp: 0,
            nftType: NFTType.CHARACTER
        });

        // 更新用户记录
        userStakedTokens[msg.sender].push(tokenId);
        userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
        tokenStakers[tokenId] = msg.sender;
        totalStakedTokens++;

        emit TokenStaked(msg.sender, tokenId, block.number);
    }

    // 批量质押Character NFT
    function stakeCharacterBatch(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(tokenIds.length > 0, "CharacterNFTStaking: Empty token list");
        require(tokenIds.length <= 50, "CharacterNFTStaking: Too many tokens");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(characterNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
            require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

            // 转移NFT到合约
            characterNFT.safeTransferFrom(msg.sender, address(this), tokenId);

            // 创建质押记录
            stakeInfos[tokenId] = StakeInfo({
                tokenId: tokenId,
                startBlock: block.number,
                lastRewardBlock: block.number,
                accumulatedExp: 0,
                nftType: NFTType.CHARACTER
            });

            // 更新用户记录
            userStakedTokens[msg.sender].push(tokenId);
            userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
            tokenStakers[tokenId] = msg.sender;
        }

        totalStakedTokens += tokenIds.length;
        emit TokensStakedBatch(msg.sender, tokenIds, block.number);
    }

    // 批量质押BlackGhost NFT
    function stakeBlackGhostBatch(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(tokenIds.length > 0, "CharacterNFTStaking: Empty token list");
        require(tokenIds.length <= 50, "CharacterNFTStaking: Too many tokens");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(blackGhostNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
            require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

            // 转移NFT到合约
            blackGhostNFT.safeTransferFrom(msg.sender, address(this), tokenId);

            // 创建质押记录
            stakeInfos[tokenId] = StakeInfo({
                tokenId: tokenId,
                startBlock: block.number,
                lastRewardBlock: block.number,
                accumulatedExp: 0,
                nftType: NFTType.BLACKGHOST
            });

            // 更新用户记录
            userStakedTokens[msg.sender].push(tokenId);
            userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
            tokenStakers[tokenId] = msg.sender;
        }

        totalStakedTokens += tokenIds.length;
        emit TokensStakedBatch(msg.sender, tokenIds, block.number);
    }

    // 兼容性函数 - 保持原有的 stakeBatch 函数作为 stakeCharacterBatch 的别名
    function stakeBatch(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        require(stakingConfig.active, "CharacterNFTStaking: Staking not active");
        require(block.number < stakingConfig.endBlock, "CharacterNFTStaking: Staking period ended");
        require(tokenIds.length > 0, "CharacterNFTStaking: Empty token list");
        require(tokenIds.length <= 50, "CharacterNFTStaking: Too many tokens");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(characterNFT.ownerOf(tokenId) == msg.sender, "CharacterNFTStaking: Not token owner");
            require(tokenStakers[tokenId] == address(0), "CharacterNFTStaking: Token already staked");

            // 转移NFT到合约
            characterNFT.safeTransferFrom(msg.sender, address(this), tokenId);

            // 创建质押记录
            stakeInfos[tokenId] = StakeInfo({
                tokenId: tokenId,
                startBlock: block.number,
                lastRewardBlock: block.number,
                accumulatedExp: 0,
                nftType: NFTType.CHARACTER
            });

            // 更新用户记录
            userStakedTokens[msg.sender].push(tokenId);
            userTokenIndex[msg.sender][tokenId] = userStakedTokens[msg.sender].length - 1;
            tokenStakers[tokenId] = msg.sender;
        }

        totalStakedTokens += tokenIds.length;
        emit TokensStakedBatch(msg.sender, tokenIds, block.number);
    }

    // 解质押单个NFT
    function unstake(uint256 tokenId) external nonReentrant {
        require(tokenStakers[tokenId] == msg.sender, "CharacterNFTStaking: Not your token");

        StakeInfo memory stakeInfo = stakeInfos[tokenId];
        uint256 expGained = _calculatePendingExp(tokenId);
        
        // 根据NFT类型更新经验值和等级
        if (expGained > 0) {
            if (stakeInfo.nftType == NFTType.CHARACTER) {
                uint256 currentExp = characterNFT.getExp(tokenId);
                uint256 newExp = currentExp + expGained;
                uint8 newLevel = configCenter.calculateLevel(newExp);
                characterNFT.updateLevelAndExp(tokenId, newLevel, newExp);
            } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
                uint256 currentExp = blackGhostNFT.getExp(tokenId);
                uint256 newExp = currentExp + expGained;
                uint8 newLevel = configCenter.calculateLevel(newExp);
                blackGhostNFT.updateLevelAndExp(tokenId, newLevel, newExp);
            }
            totalExpRewarded += expGained;
        }

        // 返还NFT
        if (stakeInfo.nftType == NFTType.CHARACTER) {
            characterNFT.safeTransferFrom(address(this), msg.sender, tokenId);
        } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
            blackGhostNFT.safeTransferFrom(address(this), msg.sender, tokenId);
        }

        // 清理记录
        _removeTokenFromUser(msg.sender, tokenId);
        delete stakeInfos[tokenId];
        delete tokenStakers[tokenId];
        totalStakedTokens--;

        emit TokenUnstaked(msg.sender, tokenId, expGained, block.number);
    }

    // 批量解质押NFT
    function unstakeBatch(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "CharacterNFTStaking: Empty token list");
        require(tokenIds.length <= 50, "CharacterNFTStaking: Too many tokens");

        uint256 totalExpGained = 0;

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenStakers[tokenId] == msg.sender, "CharacterNFTStaking: Not your token");

            StakeInfo memory stakeInfo = stakeInfos[tokenId];
            uint256 expGained = _calculatePendingExp(tokenId);
            totalExpGained += expGained;

            // 根据NFT类型更新经验值
            if (expGained > 0) {
                if (stakeInfo.nftType == NFTType.CHARACTER) {
                    uint256 currentExp = characterNFT.getExp(tokenId);
                    uint8 currentLevel = characterNFT.getLevel(tokenId);
                    characterNFT.updateLevelAndExp(tokenId, currentLevel, currentExp + expGained);
                } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
                    uint256 currentExp = blackGhostNFT.getExp(tokenId);
                    uint8 currentLevel = blackGhostNFT.getLevel(tokenId);
                    blackGhostNFT.updateLevelAndExp(tokenId, currentLevel, currentExp + expGained);
                }
            }

            // 返还NFT
            if (stakeInfo.nftType == NFTType.CHARACTER) {
                characterNFT.safeTransferFrom(address(this), msg.sender, tokenId);
            } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
                blackGhostNFT.safeTransferFrom(address(this), msg.sender, tokenId);
            }

            // 清理记录
            _removeTokenFromUser(msg.sender, tokenId);
            delete stakeInfos[tokenId];
            delete tokenStakers[tokenId];
        }

        totalStakedTokens -= tokenIds.length;
        totalExpRewarded += totalExpGained;

        emit TokensUnstakedBatch(msg.sender, tokenIds, totalExpGained, block.number);
    }

    // 领取奖励而不解质押
    function claimReward(uint256 tokenId) external nonReentrant {
        require(tokenStakers[tokenId] == msg.sender, "CharacterNFTStaking: Not your token");

        uint256 expGained = _calculatePendingExp(tokenId);
        require(expGained > 0, "CharacterNFTStaking: No rewards to claim");

        StakeInfo memory stakeInfo = stakeInfos[tokenId];
        
        // 根据NFT类型获取当前状态并计算新的等级和经验值
        if (stakeInfo.nftType == NFTType.CHARACTER) {
            uint256 currentExp = characterNFT.getExp(tokenId);
            uint256 newExp = currentExp + expGained;
            uint8 newLevel = configCenter.calculateLevel(newExp);
            characterNFT.updateLevelAndExp(tokenId, newLevel, newExp);
        } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
            uint256 currentExp = blackGhostNFT.getExp(tokenId);
            uint256 newExp = currentExp + expGained;
            uint8 newLevel = configCenter.calculateLevel(newExp);
            blackGhostNFT.updateLevelAndExp(tokenId, newLevel, newExp);
        }

        // 更新质押记录
        stakeInfos[tokenId].lastRewardBlock = block.number > stakingConfig.endBlock ? stakingConfig.endBlock : block.number;
        stakeInfos[tokenId].accumulatedExp += expGained;
        totalExpRewarded += expGained;

        emit ExpClaimed(msg.sender, tokenId, expGained);
    }

    // 批量领取奖励
    function claimRewardBatch(uint256[] calldata tokenIds) external nonReentrant {
        require(tokenIds.length > 0, "CharacterNFTStaking: Empty token list");
        require(tokenIds.length <= 50, "CharacterNFTStaking: Too many tokens");

        for (uint256 i = 0; i < tokenIds.length; i++) {
            uint256 tokenId = tokenIds[i];
            require(tokenStakers[tokenId] == msg.sender, "CharacterNFTStaking: Not your token");

            uint256 expGained = _calculatePendingExp(tokenId);
            
            if (expGained > 0) {
                StakeInfo memory stakeInfo = stakeInfos[tokenId];
                
                // 根据NFT类型更新经验值
                if (stakeInfo.nftType == NFTType.CHARACTER) {
                    uint256 currentExp = characterNFT.getExp(tokenId);
                    uint8 currentLevel = characterNFT.getLevel(tokenId);
                    characterNFT.updateLevelAndExp(tokenId, currentLevel, currentExp + expGained);
                } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
                    uint256 currentExp = blackGhostNFT.getExp(tokenId);
                    uint8 currentLevel = blackGhostNFT.getLevel(tokenId);
                    blackGhostNFT.updateLevelAndExp(tokenId, currentLevel, currentExp + expGained);
                }

                // 更新质押记录
                stakeInfos[tokenId].lastRewardBlock = block.number > stakingConfig.endBlock ? stakingConfig.endBlock : block.number;
                stakeInfos[tokenId].accumulatedExp += expGained;
                totalExpRewarded += expGained;

                emit ExpClaimed(msg.sender, tokenId, expGained);
            }
        }
    }

    // 计算待领取经验值
    function _calculatePendingExp(uint256 tokenId) internal view returns (uint256) {
        StakeInfo memory stakeInfo = stakeInfos[tokenId];
        if (stakeInfo.tokenId == 0) return 0;

        uint256 currentBlock = block.number > stakingConfig.endBlock ? stakingConfig.endBlock : block.number;
        if (currentBlock <= stakeInfo.lastRewardBlock) return 0;

        uint256 blocksPassed = currentBlock - stakeInfo.lastRewardBlock;
        return blocksPassed * stakingConfig.expPerBlock;
    }

    // 移除用户token记录
    function _removeTokenFromUser(address user, uint256 tokenId) internal {
        uint256 tokenIndex = userTokenIndex[user][tokenId];
        uint256 lastTokenIndex = userStakedTokens[user].length - 1;

        if (tokenIndex != lastTokenIndex) {
            uint256 lastTokenId = userStakedTokens[user][lastTokenIndex];
            userStakedTokens[user][tokenIndex] = lastTokenId;
            userTokenIndex[user][lastTokenId] = tokenIndex;
        }

        userStakedTokens[user].pop();
        delete userTokenIndex[user][tokenId];
    }

    // 管理函数 - 更新配置
    function updateConfig(
        uint256 _expPerBlock,
        uint256 _endBlock,
        bool _active
    ) external onlyOwner {
        require(_expPerBlock > 0, "CharacterNFTStaking: Invalid exp per block");
        
        stakingConfig.expPerBlock = _expPerBlock;
        stakingConfig.endBlock = _endBlock;
        stakingConfig.active = _active;

        emit ConfigUpdated(_expPerBlock, _endBlock, _active);
    }

    // 管理函数 - 更新CharacterNFT合约地址
    function updateCharacterNFT(address _characterNFT) external onlyOwner {
        require(_characterNFT != address(0), "CharacterNFTStaking: Invalid CharacterNFT address");
        address oldAddress = address(characterNFT);
        characterNFT = ICharacterNFT(_characterNFT);
        emit CharacterNFTUpdated(oldAddress, _characterNFT);
    }

    // 管理函数 - 更新BlackGhostNFT合约地址
    function updateBlackGhostNFT(address _blackGhostNFT) external onlyOwner {
        require(_blackGhostNFT != address(0), "CharacterNFTStaking: Invalid BlackGhostNFT address");
        address oldAddress = address(blackGhostNFT);
        blackGhostNFT = IBlackGhostNFT(_blackGhostNFT);
        emit BlackGhostNFTUpdated(oldAddress, _blackGhostNFT);
    }

    // 紧急提取NFT
    function emergencyWithdraw(uint256 tokenId) external nonReentrant {
        require(tokenStakers[tokenId] == msg.sender, "CharacterNFTStaking: Not your token");

        StakeInfo memory stakeInfo = stakeInfos[tokenId];
        
        // 返还NFT，不给经验奖励
        if (stakeInfo.nftType == NFTType.CHARACTER) {
            characterNFT.safeTransferFrom(address(this), msg.sender, tokenId);
        } else if (stakeInfo.nftType == NFTType.BLACKGHOST) {
            blackGhostNFT.safeTransferFrom(address(this), msg.sender, tokenId);
        }

        // 清理记录
        _removeTokenFromUser(msg.sender, tokenId);
        delete stakeInfos[tokenId];
        delete tokenStakers[tokenId];
        totalStakedTokens--;

        emit TokenUnstaked(msg.sender, tokenId, 0, block.number);
    }

    // 暂停/恢复合约
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // 查询函数 - 用户质押的token列表
    function getUserStakedTokens(address user) external view returns (uint256[] memory) {
        return userStakedTokens[user];
    }

    // 查询函数 - 用户质押的Character NFT列表
    function getUserStakedCharacters(address user) external view returns (uint256[] memory) {
        uint256[] memory allTokens = userStakedTokens[user];
        uint256 characterCount = 0;
        
        // 首先计算Character NFT数量
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (stakeInfos[allTokens[i]].nftType == NFTType.CHARACTER) {
                characterCount++;
            }
        }
        
        // 创建结果数组并填充
        uint256[] memory characterTokens = new uint256[](characterCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (stakeInfos[allTokens[i]].nftType == NFTType.CHARACTER) {
                characterTokens[index] = allTokens[i];
                index++;
            }
        }
        
        return characterTokens;
    }

    // 查询函数 - 用户质押的BlackGhost NFT列表
    function getUserStakedBlackGhosts(address user) external view returns (uint256[] memory) {
        uint256[] memory allTokens = userStakedTokens[user];
        uint256 blackGhostCount = 0;
        
        // 首先计算BlackGhost NFT数量
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (stakeInfos[allTokens[i]].nftType == NFTType.BLACKGHOST) {
                blackGhostCount++;
            }
        }
        
        // 创建结果数组并填充
        uint256[] memory blackGhostTokens = new uint256[](blackGhostCount);
        uint256 index = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (stakeInfos[allTokens[i]].nftType == NFTType.BLACKGHOST) {
                blackGhostTokens[index] = allTokens[i];
                index++;
            }
        }
        
        return blackGhostTokens;
    }

    // 查询函数 - token质押信息
    function getStakeInfo(uint256 tokenId) external view returns (
        uint256 startBlock,
        uint256 lastRewardBlock,
        uint256 accumulatedExp,
        uint256 pendingExp,
        address staker,
        NFTType nftType
    ) {
        StakeInfo memory stakeInfo = stakeInfos[tokenId];
        return (
            stakeInfo.startBlock,
            stakeInfo.lastRewardBlock,
            stakeInfo.accumulatedExp,
            _calculatePendingExp(tokenId),
            tokenStakers[tokenId],
            stakeInfo.nftType
        );
    }

    // 查询函数 - 用户总待领取经验
    function getUserPendingExp(address user) external view returns (uint256 totalPending) {
        uint256[] memory tokens = userStakedTokens[user];
        for (uint256 i = 0; i < tokens.length; i++) {
            totalPending += _calculatePendingExp(tokens[i]);
        }
    }

    // 查询函数 - 合约统计信息
    function getContractStats() external view returns (
        uint256 _totalStakedTokens,
        uint256 _totalExpRewarded,
        uint256 _currentBlock,
        uint256 _endBlock,
        bool _active
    ) {
        return (
            totalStakedTokens,
            totalExpRewarded,
            block.number,
            stakingConfig.endBlock,
            stakingConfig.active
        );
    }

    // 查询函数 - 分类统计信息
    function getDetailedStats() external view returns (
        uint256 totalCharacterStaked,
        uint256 totalBlackGhostStaked,
        uint256 _totalStakedTokens,
        uint256 _totalExpRewarded,
        uint256 _currentBlock,
        uint256 _endBlock,
        bool _active
    ) {
        // 这个函数可能会消耗较多gas，建议只在前端查询时使用
        uint256 characterCount = 0;
        uint256 blackGhostCount = 0;
        
        // 注意：这种方式在大量数据时可能会超出gas限制
        // 在实际部署时，建议考虑添加计数器来跟踪这些统计信息
        
        return (
            characterCount, // 暂时返回0，需要在质押时维护计数器
            blackGhostCount, // 暂时返回0，需要在质押时维护计数器
            totalStakedTokens,
            totalExpRewarded,
            block.number,
            stakingConfig.endBlock,
            stakingConfig.active
        );
    }

    // ERC721接收器
    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}