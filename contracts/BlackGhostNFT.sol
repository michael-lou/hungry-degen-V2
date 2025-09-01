// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import { IERC721 } from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import "./interfaces/ICoreNFT.sol";
import "./interfaces/IFlexNFT.sol";
import "./interfaces/ICharacterNFT.sol";

contract BlackGhostNFT is Initializable, ERC721EnumerableUpgradeable, ERC2981Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Strings for uint256;

    // BlackGhostNFT tokenId 起始值，用于与 CharacterNFT 区分
    uint256 public constant TOKEN_ID_START = 100000;

    struct Core {
        uint256 tokenId;
        uint8 part;
    }

    struct Flex {
        uint256 tokenId;
        uint8 part;
    }

    struct Character {
        uint8 character; // 1=Airdrop Andy,2=Scammed Steve, 3=Dustbag Danny, 4=Leverage Larry, 5=Trenches Ghost
        uint8 rarity; // 1=C, 2=R, 3=RR, 4=SR, 5=SSR
        uint8 level; // 1-5
        uint256 exp; // 经验值
        bytes attributes;
        string metadataUri; // 元数据URI
    }

    mapping(uint256 => Character) private characters;
    mapping(uint256 => Core[]) public characterCores; // 角色装备的配饰
    mapping(uint256 => Flex[]) public characterFlexes; // 角色装备的道具

    // 授权地址
    mapping(address => bool) public authorizedCallers;

    address public relayer;

    // 开盲盒
    uint256 public openingTime;
    mapping(uint256 => bool) public openedBoxes;

    string private _baseTokenURI;

    address public gameMaster;
    address public coreContract;
    address public flexContract;

    event CharacterMinted(address indexed to, uint256 indexed tokenId, uint8 rarity, uint8 pattern);
    event CharacterLevelUpdated(uint256 indexed tokenId, uint8 newLevel, uint256 newExp);
    event CharacterCoreEquipped(uint256 indexed tokenId, uint256 coreId, uint8 part);
    event CharacterFlexEquipped(uint256 indexed tokenId, uint256 flexId, uint8 part);
    event CallerAuthorized(address caller, bool authorized);
    event AdminMint(address indexed to, uint256 indexed tokenId, uint8 character, uint8 rarity);

    modifier onlyAuthorized() {
        require(
            owner() == _msgSender() || gameMaster == _msgSender() || authorizedCallers[_msgSender()],
            "BlackGhostNFT: Not authorized"
        );
        _;
    }

    modifier onlyGameMaster() {
        require(gameMaster == _msgSender(), "BlackGhostNFT: Not authorized");
        _;
    }

    function initialize() public initializer {
        __ERC721_init("HungryDegenBlackGhost", "HDBG");
        __ERC721Enumerable_init();
        __ERC2981_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
        
        // 设置默认版税：5%给合约所有者
        _setDefaultRoyalty(msg.sender, 500); // 500 = 5% (以10000为基数)
    }

    // settings

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "BlackGhostNFT: caller is the zero address");
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }

    function setGameMaster(address _gameMaster) external onlyOwner {
        require(_gameMaster != address(0), "BlackGhostNFT: gameMaster is the zero address");
        gameMaster = _gameMaster;
        authorizedCallers[_gameMaster] = true;
    }

    function setCoreContract(address _coreContract) external onlyOwner {
        require(_coreContract != address(0), "BlackGhostNFT: Invalid core contract");
        coreContract = _coreContract;
    }

    function setFlexContract(address _flexContract) external onlyOwner {
        require(_flexContract != address(0), "BlackGhostNFT: Invalid flex contract");
        flexContract = _flexContract;
    }

    function setBaseURI(string calldata baseURI) external onlyOwner {
        _baseTokenURI = baseURI;
    }

    function mint(
        address to,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external onlyAuthorized returns (uint256) {
        require(character > 0 && character <= 6, "BlackGhostNFT: Invalid character"); // 支持 BlackGhost (6)
        require(rarity > 0 && rarity <= 5, "BlackGhostNFT: Invalid rarity");

        // tokenId 从 TOKEN_ID_START (100000) 开始递增
        uint256 tokenId = TOKEN_ID_START + totalSupply();
        _mint(to, tokenId);

        characters[tokenId] = Character({
            character: character,
            rarity: rarity,
            level: 1,
            exp: 0,
            attributes: attributes,
            metadataUri: metadataUri
        });

        openedBoxes[tokenId] = true;

        emit CharacterMinted(to, tokenId, rarity, character);
        return tokenId;
    }

    /**
     * @dev Admin mint function - allows owner to mint BlackGhost NFTs directly
     * @param to Address to mint the NFT to
     * @param character Character type (1-6, where 6 is BlackGhost)
     * @param rarity Rarity level (1-5)
     * @param attributes Character attributes as bytes
     * @param metadataUri Metadata URI for the NFT
     * @return tokenId The minted token ID
     */
    function adminMint(
        address to,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external onlyOwner returns (uint256) {
        require(to != address(0), "BlackGhostNFT: Invalid recipient");
        require(character > 0 && character <= 6, "BlackGhostNFT: Invalid character");
        require(rarity > 0 && rarity <= 5, "BlackGhostNFT: Invalid rarity");

        // tokenId 从 TOKEN_ID_START (100000) 开始递增
        uint256 tokenId = TOKEN_ID_START + totalSupply();
        _mint(to, tokenId);

        characters[tokenId] = Character({
            character: character,
            rarity: rarity,
            level: 1,
            exp: 0,
            attributes: attributes,
            metadataUri: metadataUri
        });

        openedBoxes[tokenId] = true;

        emit AdminMint(to, tokenId, character, rarity);
        emit CharacterMinted(to, tokenId, rarity, character);
        return tokenId;
    }

    /**
     * @dev Batch admin mint function - allows owner to mint multiple BlackGhost NFTs
     * @param to Address to mint the NFTs to
     * @param quantity Number of NFTs to mint
     * @param character Character type (1-6, where 6 is BlackGhost)
     * @param rarity Rarity level (1-5)
     * @param attributes Character attributes as bytes
     * @param metadataUri Metadata URI for the NFTs
     * @return tokenIds Array of minted token IDs
     */
    function batchAdminMint(
        address to,
        uint256 quantity,
        uint8 character,
        uint8 rarity,
        bytes calldata attributes,
        string calldata metadataUri
    ) external onlyOwner returns (uint256[] memory) {
        require(to != address(0), "BlackGhostNFT: Invalid recipient");
        require(quantity > 0 && quantity <= 100, "BlackGhostNFT: Invalid quantity");
        require(character > 0 && character <= 6, "BlackGhostNFT: Invalid character");
        require(rarity > 0 && rarity <= 5, "BlackGhostNFT: Invalid rarity");

        uint256[] memory tokenIds = new uint256[](quantity);

        for (uint256 i = 0; i < quantity; i++) {
            uint256 tokenId = TOKEN_ID_START + totalSupply();
            _mint(to, tokenId);

            characters[tokenId] = Character({
                character: character,
                rarity: rarity,
                level: 1,
                exp: 0,
                attributes: attributes,
                metadataUri: metadataUri
            });

            openedBoxes[tokenId] = true;
            tokenIds[i] = tokenId;

            emit AdminMint(to, tokenId, character, rarity);
            emit CharacterMinted(to, tokenId, rarity, character);
        }

        return tokenIds;
    }

    // 更新角色等级和经验
    function updateLevelAndExp(uint256 tokenId, uint8 newLevel, uint256 newExp) external onlyAuthorized {
        characters[tokenId].level = newLevel;
        characters[tokenId].exp = newExp;

        emit CharacterLevelUpdated(tokenId, newLevel, newExp);
    }

    // 装备管理 只有GameMaster可以调用
    function equipCore(uint256 tokenId, uint256 coreId) external onlyGameMaster {
        ICoreNFT coreNFT = ICoreNFT(coreContract);

        ICoreNFT.Core memory coreInfo = coreNFT.getCoreInfo(coreId);
        require(
            coreInfo.characterType == 5,
            "BlackGhostNFT: This core is not exclusive to this character"
        );
        for (uint i = 0; i < characterCores[tokenId].length; i++) {
            require(characterCores[tokenId][i].part != coreInfo.part, "BlackGhostNFT: This part already equipped");
        }

        characterCores[tokenId].push(Core({ tokenId: coreId, part: coreInfo.part }));

        emit CharacterCoreEquipped(tokenId, coreId, coreInfo.part);
    }

    function equipFlex(uint256 tokenId, uint256 flexId) external onlyGameMaster {
        IFlexNFT flexNFT = IFlexNFT(flexContract);

        IFlexNFT.Flex memory flexInfo = flexNFT.getFlexInfo(flexId);
        require(
            flexInfo.characterType == 5,
            "BlackGhostNFT: This flex is not exclusive to this character"
        );

        for (uint i = 0; i < characterFlexes[tokenId].length; i++) {
            require(characterFlexes[tokenId][i].part != flexInfo.part, "BlackGhostNFT: This part already equipped");
        }

        characterFlexes[tokenId].push(Flex({ tokenId: flexId, part: flexInfo.part }));

        emit CharacterFlexEquipped(tokenId, flexId, flexInfo.part);
    }

    function unequipCore(uint256 tokenId, uint256 coreId) external onlyGameMaster {
        for (uint256 i = 0; i < characterCores[tokenId].length; i++) {
            if (characterCores[tokenId][i].tokenId == coreId) {
                characterCores[tokenId][i] = characterCores[tokenId][characterCores[tokenId].length - 1];
                characterCores[tokenId].pop();
                break;
            }
        }
    }

    function unequipFlex(uint256 tokenId, uint256 flexId) external onlyGameMaster {
        for (uint256 i = 0; i < characterFlexes[tokenId].length; i++) {
            if (characterFlexes[tokenId][i].tokenId == flexId) {
                characterFlexes[tokenId][i] = characterFlexes[tokenId][characterFlexes[tokenId].length - 1];
                characterFlexes[tokenId].pop();
                break;
            }
        }
    }

    //重载转移方法，非授权地址调用时需要清空装备
    function transferFrom(address from, address to, uint256 tokenId) public override(ERC721Upgradeable, IERC721) {
        // BlackGhost 只能被授权合约转移（用于质押等游戏功能）
        require(authorizedCallers[_msgSender()], "BlackGhostNFT: Transfer not allowed");

        _transfer(from, to, tokenId);
    }

    // 添加缺失的 _isApprovedOrOwner 函数
    function _isApprovedOrOwner(address spender, uint256 tokenId) internal view returns (bool) {
        require(_exists(tokenId), "ERC721: nonexistent token");
        address owner = ownerOf(tokenId);
        return (spender == owner || isApprovedForAll(owner, spender) || getApproved(tokenId) == spender);
    }

    // 获取角色属性 - 激活后（预售结束）可读取
    function getLevel(uint256 tokenId) external view returns (uint8) {
        if (!openedBoxes[tokenId]) {
            return 0;
        }

        return characters[tokenId].level;
    }

    function getExp(uint256 tokenId) external view returns (uint256) {
        if (!openedBoxes[tokenId]) {
            return 0;
        }

        return characters[tokenId].exp;
    }

    function getRarity(uint256 tokenId) external view returns (uint8) {
        if (!openedBoxes[tokenId]) {
            return 0;
        }

        return characters[tokenId].rarity;
    }

    function getCharacterType(uint256 tokenId) external view returns (uint8) {
        if (!openedBoxes[tokenId]) {
            return 0;
        }
        return characters[tokenId].character;
    }

    function getEquippedAccessories(uint256 tokenId) external view returns (uint256[] memory) {
        uint256[] memory coreIds = new uint256[](characterCores[tokenId].length);
        for (uint i = 0; i < characterCores[tokenId].length; i++) {
            coreIds[i] = characterCores[tokenId][i].tokenId;
        }
        return coreIds;
    }

    function getEquippedFlexes(uint256 tokenId) external view returns (uint256[] memory) {
        uint256[] memory flexIds = new uint256[](characterFlexes[tokenId].length);
        for (uint i = 0; i < characterFlexes[tokenId].length; i++) {
            flexIds[i] = characterFlexes[tokenId][i].tokenId;
        }
        return flexIds;
    }

    // 获取全部角色信息
    function getCharacterInfo(uint256 tokenId) external view returns (Character memory, Core[] memory, Flex[] memory) {
        if (!openedBoxes[tokenId]) {
            return (
                Character({ character: 0, rarity: 0, level: 0, exp: 0, attributes: "", metadataUri: "" }),
                new Core[](0),
                new Flex[](0)
            );
        }
        return (characters[tokenId], characterCores[tokenId], characterFlexes[tokenId]);
    }

    function getOwnedTokens(address _owner) external view returns (uint256[] memory) {
        uint256 balance = balanceOf(_owner);
        uint256[] memory tokens = new uint256[](balance);
        for (uint256 i = 0; i < balance; i++) {
            tokens[i] = tokenOfOwnerByIndex(_owner, i);
        }
        return tokens;
    }

    //tokenURI 
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), "BlackGhostNFT: URI query for nonexistent token");

        string memory baseURI = _baseTokenURI;

        return string(abi.encodePacked(baseURI, tokenId.toString(), ".json"));
    }
    // internal
    function _exists(uint256 tokenId) internal view returns (bool) {
        address tokenOwner = _ownerOf(tokenId);
        return tokenOwner != address(0);
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

    // UUPS升级所需函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
