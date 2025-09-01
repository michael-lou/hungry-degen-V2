// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IDUSTToken.sol";

/**
 * @title BaseMarketplaceNoVRF
 * @dev Base contract for marketplaces that don't use VRF
 */
abstract contract BaseMarketplaceNoVRF is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    IDUSTToken public dustToken;
    address payable public treasury;

    function __BaseMarketplaceNoVRF_init(
        address payable _treasury
    ) internal onlyInitializing {
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        treasury = _treasury;
    }

    // ======== 管理函数 ========

    function setTreasury(address payable _treasury) external onlyOwner {
        require(_treasury != address(0), "BaseMarketplaceNoVRF: Invalid treasury address");
        treasury = _treasury;
    }

    function setDustToken(address _dustToken) external onlyOwner {
        require(_dustToken != address(0), "BaseMarketplaceNoVRF: Invalid DUST token address");
        dustToken = IDUSTToken(_dustToken);
    }

    // UUPS升级所需函数
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    receive() external payable virtual {
    }
}
