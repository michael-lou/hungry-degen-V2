// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "./RarityManager.sol";

contract PackMetadataStorage is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    // NFT类型常量
    uint8 public constant TYPE_CORE = 0;
    uint8 public constant TYPE_FLEX = 1;

    // 元数据模板结构
    struct MetadataTemplate {
        string uri; // 元数据URI
        bytes attributes; // 压缩存储的属性数据
        uint8 part; // 部件类型
        uint8 set; // 套装类型
    }

    // 模板分发配置
    struct TemplateDistribution {
        MetadataTemplate[] templates;    // 模板库：存储所有不重复模板
        uint256[] sequence;             // 分发序列：存储模板索引的分发顺序
        uint256 currentIndex;           // 当前序列位置
    }

    // 按NFT类型、角色和稀有度分类存储模板分发配置
    mapping(uint8 => mapping(uint8 => mapping(uint8 => TemplateDistribution))) private distributionConfig;

    // 稀有度管理器
    RarityManager public rarityManager;

    // 授权调用者
    mapping(address => bool) public authorizedCallers;

    event TemplatesAdded(uint8 nftType, uint8 character, uint8 rarity, uint256 count);
    event DistributionSequenceSet(uint8 nftType, uint8 character, uint8 rarity, uint256 sequenceLength);
    event RarityManagerUpdated(address newManager);

    modifier onlyAuthorized() {
        require(owner() == _msgSender() || authorizedCallers[_msgSender()], "PackMetadataStorage: Not authorized");
        _;
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // 设置稀有度管理器
    function setRarityManager(address _rarityManager) external onlyOwner {
        require(_rarityManager != address(0), "Invalid address");
        rarityManager = RarityManager(_rarityManager);
        emit RarityManagerUpdated(_rarityManager);
    }

    // 设置授权调用者
    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        authorizedCallers[caller] = authorized;
    }

    // 添加模板到模板库（不重复存储）
    function addTemplates(
        uint8 nftType,
        uint8 character,
        uint8 rarity,
        string[] calldata uris,
        bytes[] calldata attributesArray,
        uint8[] calldata partArray,
        uint8[] calldata setArray
    ) external onlyOwner {
        require(uris.length == attributesArray.length, "Arrays length mismatch");
        require(attributesArray.length == partArray.length, "Arrays length mismatch");
        require(setArray.length == partArray.length, "Arrays length mismatch");
        require(character > 0 && character <= 5, "Invalid character type");
        require(rarity > 0 && rarity <= 6, "Invalid rarity");
        require(nftType <= 1, "Invalid NFT type");

        TemplateDistribution storage dist = distributionConfig[nftType][character][rarity];
        
        for (uint256 i = 0; i < uris.length; i++) {
            dist.templates.push(
                MetadataTemplate({
                    uri: uris[i],
                    attributes: attributesArray[i],
                    part: partArray[i],
                    set: setArray[i]
                })
            );
        }

        emit TemplatesAdded(nftType, character, rarity, uris.length);
    }

    // 设置分发序列（核心功能）
    function setDistributionSequence(
        uint8 nftType,
        uint8 character,
        uint8 rarity,
        uint256[] calldata sequence
    ) external onlyOwner {
        require(character > 0 && character <= 5, "Invalid character type");
        require(rarity > 0 && rarity <= 6, "Invalid rarity");
        require(nftType <= 1, "Invalid NFT type");
        require(sequence.length > 0, "Empty sequence");

        TemplateDistribution storage dist = distributionConfig[nftType][character][rarity];
        require(dist.templates.length > 0, "No templates available");

        // 验证序列中的索引都在templates范围内
        for (uint256 i = 0; i < sequence.length; i++) {
            require(sequence[i] < dist.templates.length, "Invalid template index in sequence");
        }

        // 设置sequence数组
        delete dist.sequence; // 清空现有序列
        for (uint256 i = 0; i < sequence.length; i++) {
            dist.sequence.push(sequence[i]);
        }
        
        // 重置currentIndex为0
        dist.currentIndex = 0;

        emit DistributionSequenceSet(nftType, character, rarity, sequence.length);
    }

    // 获取模板（修改后的核心函数）
    function getMetadataTemplate(
        uint8 nftType,
        uint8 character,
        uint8 rarity
    )
        external
        onlyAuthorized
        returns (string memory uri, bytes memory attributes, uint8 part, uint8 set)
    {
        require(character > 0 && character <= 5, "Invalid character type");
        require(rarity > 0 && rarity <= 6, "Invalid rarity");
        require(nftType <= 1, "Invalid NFT type");

        TemplateDistribution storage dist = distributionConfig[nftType][character][rarity];
        require(dist.templates.length > 0, "No templates available");
        require(dist.sequence.length > 0, "No distribution sequence set");
        
        // 按序列获取模板索引
        uint256 templateIndex = dist.sequence[dist.currentIndex];
        require(templateIndex < dist.templates.length, "Invalid template index");
        
        // 获取模板
        MetadataTemplate storage template = dist.templates[templateIndex];
        
        // 更新序列索引（循环）
        dist.currentIndex = (dist.currentIndex + 1) % dist.sequence.length;
        
        return (template.uri, template.attributes, template.part, template.set);
    }

    // 获取模板数量
    function getTemplateCount(uint8 nftType, uint8 character, uint8 rarity) external view returns (uint256) {
        return distributionConfig[nftType][character][rarity].templates.length;
    }

    // 检查是否有可用的模板
    function hasAvailableTemplates(uint8 nftType, uint8 character, uint8 rarity) external view returns (bool) {
        TemplateDistribution storage dist = distributionConfig[nftType][character][rarity];
        return dist.templates.length > 0 && dist.sequence.length > 0;
    }

    // 获取分发序列信息
    function getDistributionInfo(uint8 nftType, uint8 character, uint8 rarity) 
        external view returns (uint256 templateCount, uint256 sequenceLength, uint256 currentIndex) {
        TemplateDistribution storage dist = distributionConfig[nftType][character][rarity];
        return (dist.templates.length, dist.sequence.length, dist.currentIndex);
    }

    // 获取分发序列
    function getDistributionSequence(uint8 nftType, uint8 character, uint8 rarity) 
        external view returns (uint256[] memory) {
        return distributionConfig[nftType][character][rarity].sequence;
    }

    // UUPS升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
