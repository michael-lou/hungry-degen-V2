// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReferral {
    function referrers(address user) external view returns (address);
    function referralCount(address referrer) external view returns (uint256);
    function isPlayer(address player) external view returns (bool);
    function authorizedContracts(address) external view returns (bool);
    function registerPlayer(address player) external;
    function registerReferral(address user, address referrer) external;
    function getReferrer(address user) external view returns (address);
    function getReferralCount(address referrer) external view returns (uint256);
    function checkIsPlayer(address addr) external view returns (bool);
}