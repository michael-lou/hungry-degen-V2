// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

import "./PackMetadataStorage.sol";
import "./RarityManager.sol";

contract CoreNFT is Initializable, ERC721EnumerableUpgradeable, ERC2981Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Strings for uint256;
    // NFT属性结构
    struct Core {
        uint8 characterType; // 角色类型 1-5
        uint8 rarity; // 稀有度 1-6
        uint8 level; // 等级
        uint8 wear; // 磨损度
        uint8 part; // 部件类型
        uint8 set; // 套装类型
        bytes attributes; // 压缩存储的属性
        string metadataUri; // 元数据URI
    }

    // NFT属性存储
    mapping(uint256 => Core) private coreItems;

    // 元数据存储合约
    PackMetadataStorage public packMetadataStorage;

    // 稀有度管理器
    RarityManager public rarityManager;

    // 授权调用者
    mapping(address => bool) public authorizedCallers;

    // 基础URI
    string private _baseTokenURI;

    // 事件
    event CoreMinted(address indexed to, uint256 indexed tokenId, uint8 characterType, uint8 rarity);
    event PackMetadataStorageUpdated(address newStorage);
    event RarityManagerUpdated(address newManager);
    event LevelUpdated(uint256 indexed tokenId, uint8 newLevel);
    event WearUpdated(uint256 indexed tokenId, uint8 newWear);

    modifier onlyAuthorized() {
        require(owner() == _msgSender() || authorizedCallers[_msgSender()], "CoreNFT: Not authorized");
        _;
    }

    function initialize() public initializer {
        __ERC721_init("HungryDegenCore", "HDCI");
        __ERC721Enumerable_init();
        __ERC2981_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        // 设置默认版税：5%给合约所有者
        _setDefaultRoyalty(msg.sender, 500); // 500 = 5% (以10000为基数)
    }

    // 设置元数据存储合约
    function setPackMetadataStorage(address _packMetadataStorage) external onlyOwner {
        require(_packMetadataStorage != address(0), "Invalid address");
        packMetadataStorage = PackMetadataStorage(_packMetadataStorage);
        emit PackMetadataStorageUpdated(_packMetadataStorage);
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

    // 设置基础URI
    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    // 铸造NFT
    function mint(
        address to,
        uint8 characterType,
        uint8 rarity
    ) external onlyAuthorized returns (uint256,string memory) {
        require(address(packMetadataStorage) != address(0), "Metadata storage not set");
        require(characterType > 0 && characterType <= 5, "Invalid character type");
        require(rarity >= 1 && rarity <= 6, "Invalid rarity");

        uint256 tokenId = totalSupply() + 1;

        // 从元数据存储获取模板
        (string memory uri, bytes memory attributes, uint8 part, uint8 set) = packMetadataStorage.getMetadataTemplate(
            0, // TYPE_CORE = 0
            characterType,
            rarity
        );

        // 创建NFT属性
        coreItems[tokenId] = Core({
            characterType: characterType,
            rarity: rarity,
            level: 0,
            wear: 0,
            part: part,
            set: set,
            attributes: attributes,
            metadataUri: uri
        });

        _mint(to, tokenId);

        emit CoreMinted(to, tokenId, characterType, rarity);

        return (tokenId, uri);
    }

    // 获取NFT信息
    //tokenURI
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "URI query for nonexistent token");

        string memory baseURI = _baseTokenURI;

        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }
    function getCoreInfo(uint256 tokenId) external view returns (Core memory) {
        require(_exists(tokenId), "Token does not exist");
        return coreItems[tokenId];
    }

    function getCoreInfoBatch(uint256[] memory tokenIds) external view returns (Core[] memory) {
        Core[] memory items = new Core[](tokenIds.length);
        for (uint256 i = 0; i < tokenIds.length; i++) {
            require(_exists(tokenIds[i]), "Token does not exist");
            items[i] = coreItems[tokenIds[i]];
        }
        return items;
    }

    function getLevel(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Token does not exist");
        return coreItems[tokenId].level;
    }
    function getWear(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Token does not exist");
        return coreItems[tokenId].wear;
    }
    function getRarity(uint256 tokenId) external view returns (uint8) {
        require(_exists(tokenId), "Token does not exist");
        return coreItems[tokenId].rarity;
    }

    function getOwnedTokens(address _owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(_owner);
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokens;
    }
    
    // 更新NFT等级
    function updateLevel(uint256 tokenId, uint8 newLevel) external onlyAuthorized {
        require(_exists(tokenId), "Token does not exist");
        coreItems[tokenId].level = newLevel;
        emit LevelUpdated(tokenId, newLevel);
    }

    // 更新NFT磨损度
    function updateWear(uint256 tokenId, uint8 newWear) external onlyAuthorized {
        require(_exists(tokenId), "Token does not exist");
        coreItems[tokenId].wear = newWear;
        emit WearUpdated(tokenId, newWear);
    }
    
    // 销毁NFT
    function burn(uint256 tokenId) external {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "Not approved");
        _burn(tokenId);
        delete coreItems[tokenId];
    }

    function _exists(uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _ownerOf(tokenId);
        return tokenOwner != address(0);
    }

    // 检查是否是拥有者或被授权者
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "Token does not exist");
        address _owner = ownerOf(tokenId);
        return (spender == _owner || isApprovedForAll(_owner, spender) || getApproved(tokenId) == spender);
    }

    // 版税管理函数
    /**
     * @dev 设置默认版税信息
     * @param receiver 版税接收地址
     * @param feeNumerator 版税费率分子 (分母为10000，例如500表示5%)
     */
    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    /**
     * @dev 为特定token设置版税信息
     * @param tokenId 代币ID
     * @param receiver 版税接收地址
     * @param feeNumerator 版税费率分子 (分母为10000)
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @dev 删除默认版税
     */
    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    /**
     * @dev 重置特定token的版税信息
     * @param tokenId 代币ID
     */
    function resetTokenRoyalty(uint256 tokenId) external onlyOwner {
        _resetTokenRoyalty(tokenId);
    }

    /**
     * @dev 重写supportsInterface以支持ERC2981版税标准
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721EnumerableUpgradeable, ERC2981Upgradeable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

     // UUPS升级
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
