// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Hungry Degen Token
 *
 * @dev A minimal ERC20 token contract for the Hungry Degen Token
 */
contract DUSTToken is ERC20("Hungry Degen Token", "DUST") {
    uint256 private constant TOTAL_SUPPLY = 100_000_000_000e18;

    constructor(address genesis_holder) {
        require(genesis_holder != address(0), "DUSTToken: zero address");
        _mint(genesis_holder, TOTAL_SUPPLY);
    }
}
