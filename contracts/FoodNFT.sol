// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";

contract FoodNFT is Initializable, ERC1155Upgradeable, ERC1155SupplyUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    using Strings for uint256;

    // 食物类型定义
    struct Food {
        uint8 rarity; // 稀有度 1-8 (F,N,R,RR,C,SSR,SR)
        string name; // 食物名称
        uint256 value; // 食物价值（用于回收价格）
        uint256 exp; // 食物提供的经验值
    }

    // 食物类型信息存储
    mapping(uint256 => Food) private foodTypes;

    // 用户拥有的食物类型ID数组
    mapping(address => uint256[]) public ownedFoodTypes;

    // 用户拥有的每种食物类型的ID (防止重复添加到ownedFoodTypes)
    mapping(address => mapping(uint256 => bool)) private userOwnsFoodType;

    address public gameMaster;

    // 授权地址
    mapping(address => bool) public authorizedCallers;

    string private baseURI;

    event FoodMinted(address indexed to, uint256 indexed id, uint256 amount, uint8 rarity);
    event FoodBurned(address indexed from, uint256 indexed id, uint256 amount, uint8 rarity);
    event CallerAuthorized(address caller, bool authorized);

    modifier onlyAuthorized() {
        require(
            owner() == _msgSender() || gameMaster == _msgSender() || authorizedCallers[_msgSender()],
            "Not authorized"
        );
        _;
    }

    function initialize() public initializer {
        __ERC1155_init("");
        __ERC1155Supply_init();
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    // 初始化集合
    function initializeCollection(
        uint256 tokenId,
        uint8 rarity,
        string memory name,
        uint256 value,
        uint256 exp
    ) external onlyOwner {
        require(!_exists(tokenId), "FoodNFT: Token ID already _exists");
        require(rarity >= 1 && rarity <= 8, "FoodNFT: Invalid rarity (1-8)");
        require(bytes(name).length > 0, "FoodNFT: Name cannot be empty");
        require(value >= 0, "FoodNFT: Value must be greater than 0");
        require(exp > 0, "FoodNFT: Exp must be greater than 0");

        // 初始化该 tokenId 的食物类型信息
        foodTypes[tokenId] = Food({ rarity: rarity, name: name, value: value, exp: exp });
    }

    function setAuthorizedCaller(address caller, bool authorized) external onlyOwner {
        require(caller != address(0), "FoodNFT: Invalid caller");
        authorizedCallers[caller] = authorized;
        emit CallerAuthorized(caller, authorized);
    }

    function setGameMaster(address _gameMaster) external onlyOwner {
        require(_gameMaster != address(0), "FoodNFT: Invalid gameMaster");
        gameMaster = _gameMaster;
        authorizedCallers[_gameMaster] = true;
    }

    function setURI(string memory newURI) external onlyOwner {
        baseURI = newURI;
        _setURI(newURI);
    }

    // 铸造食物
    function mint(address to, uint256 id) external onlyAuthorized returns (uint256) {
        require(_exists(id), "FoodNFT: Food type does not exist");

        Food memory foodType = foodTypes[id];

        // 铸造一个指定id的食物
        _mint(to, id, 1, "");

        // 更新用户拥有的食物类型
        if (!userOwnsFoodType[to][id]) {
            ownedFoodTypes[to].push(id);
            userOwnsFoodType[to][id] = true;
        }

        emit FoodMinted(to, id, 1, foodType.rarity);

        return id;
    }

    // 批量铸造食物
    function mintBatch(address to, uint256[] memory ids, uint256[] memory amounts) external onlyAuthorized {
        require(ids.length == amounts.length, "FoodNFT: ids and amounts length mismatch");

        _mintBatch(to, ids, amounts, "");

        // 更新用户拥有的食物类型
        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            if (!userOwnsFoodType[to][id] && amounts[i] > 0) {
                ownedFoodTypes[to].push(id);
                userOwnsFoodType[to][id] = true;
            }
        }

        // 为每个ID发出事件
        for (uint256 i = 0; i < ids.length; i++) {
            if (amounts[i] > 0) {
                Food memory foodType = foodTypes[ids[i]];
                emit FoodMinted(to, ids[i], amounts[i], foodType.rarity);
            }
        }
    }

    // 销毁食物
    function burn(address from, uint256 id) external onlyAuthorized {
        Food memory foodType = foodTypes[id];

        _burn(from, id, 1);

        // 如果用户不再拥有这种食物，从列表中移除
        if (balanceOf(from, id) == 0 && userOwnsFoodType[from][id]) {
            userOwnsFoodType[from][id] = false;

            // 在拥有列表中删除该ID
            for (uint256 i = 0; i < ownedFoodTypes[from].length; i++) {
                if (ownedFoodTypes[from][i] == id) {
                    ownedFoodTypes[from][i] = ownedFoodTypes[from][ownedFoodTypes[from].length - 1];
                    ownedFoodTypes[from].pop();
                    break;
                }
            }
        }

        emit FoodBurned(from, id, 1, foodType.rarity);
    }

    // 批量销毁食物
    function burnBatch(address from, uint256[] memory ids, uint256[] memory amounts) external onlyAuthorized {
        require(ids.length == amounts.length, "FoodNFT: ids and amounts length mismatch");

        // 收集需要从ownedFoodTypes中移除的ID
        uint256[] memory toRemove = new uint256[](ids.length);
        uint256 removeCount = 0;

        for (uint256 i = 0; i < ids.length; i++) {
            Food memory foodType = foodTypes[ids[i]];
            _burn(from, ids[i], amounts[i]);

            // 检查是否需要从列表中移除
            if (balanceOf(from, ids[i]) == 0 && userOwnsFoodType[from][ids[i]]) {
                userOwnsFoodType[from][ids[i]] = false;
                toRemove[removeCount] = ids[i];
                removeCount++;
            }

            emit FoodBurned(from, ids[i], amounts[i], foodType.rarity);
        }

        // 批量移除已消耗完的食物类型（优化gas消耗）
        if (removeCount > 0) {
            _batchRemoveFromOwnedTypes(from, toRemove, removeCount);
        }
    }

    // 授权转移食物
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public override onlyAuthorized {
        require(_exists(id), "FoodNFT: Food type does not exist");
        require(from != address(0), "FoodNFT: transfer from the zero address");
        require(to != address(0), "FoodNFT: transfer to the zero address");
        require(balanceOf(from, id) >= amount, "FoodNFT: insufficient balance");
        require(authorizedCallers[to], "FoodNFT: Not authorized receiver");

        super.safeTransferFrom(from, to, id, amount, data);

        // 更新用户拥有的食物类型
        if (balanceOf(from, id) == 0 && userOwnsFoodType[from][id]) {
            userOwnsFoodType[from][id] = false;

            // 在from的拥有列表中删除该ID
            for (uint256 i = 0; i < ownedFoodTypes[from].length; i++) {
                if (ownedFoodTypes[from][i] == id) {
                    ownedFoodTypes[from][i] = ownedFoodTypes[from][ownedFoodTypes[from].length - 1];
                    ownedFoodTypes[from].pop();
                    break;
                }
            }
        }

        if (!userOwnsFoodType[to][id]) {
            ownedFoodTypes[to].push(id);
            userOwnsFoodType[to][id] = true;
        }
    }

    // 获取用户拥有的所有食物类型
    function getOwnedFoodTypes(address account) external view returns (uint256[] memory) {
        return ownedFoodTypes[account];
    }

    // 获取食物属性
    function getRarity(uint256 id) external view returns (uint8) {
        return foodTypes[id].rarity;
    }

    // 获取食物价值
    function getValue(uint256 id) external view returns (uint256) {
        return foodTypes[id].value;
    }

    // 获取食物经验值
    function getExp(uint256 id) external view returns (uint256) {
        return foodTypes[id].exp;
    }

    // 获取食物名称
    function getName(uint256 id) external view returns (string memory) {
        return foodTypes[id].name;
    }

    // 获取食物类型信息
    function getFoodInfo(uint256 id) external view returns (Food memory) {
        return foodTypes[id];
    }

    // 防止合约接收ERC-1155代币
    function onERC1155Received(address, address, uint256, uint256, bytes memory) public virtual returns (bytes4) {
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual returns (bytes4) {
        return this.onERC1155BatchReceived.selector;
    }

    function _update(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values
    ) internal override(ERC1155Upgradeable, ERC1155SupplyUpgradeable) {
        super._update(from, to, ids, values);
    }

    // 优化的批量移除函数
    function _batchRemoveFromOwnedTypes(address from, uint256[] memory toRemove, uint256 removeCount) internal {
        uint256[] storage ownedTypes = ownedFoodTypes[from];
        uint256 originalLength = ownedTypes.length;
        uint256 writeIndex = 0;

        // 使用双指针技术，一次遍历完成移除
        for (uint256 readIndex = 0; readIndex < originalLength; readIndex++) {
            bool shouldRemove = false;

            // 检查当前元素是否在移除列表中
            for (uint256 j = 0; j < removeCount; j++) {
                if (ownedTypes[readIndex] == toRemove[j]) {
                    shouldRemove = true;
                    break;
                }
            }

            // 如果不需要移除，则保留
            if (!shouldRemove) {
                if (writeIndex != readIndex) {
                    ownedTypes[writeIndex] = ownedTypes[readIndex];
                }
                writeIndex++;
            }
        }

        // 调整数组大小
        while (ownedTypes.length > writeIndex) {
            ownedTypes.pop();
        }
    }

    function _exists(uint256 id) internal view returns (bool) {
        return foodTypes[id].rarity != 0;
    }

    // UUPS升级所需函数
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
