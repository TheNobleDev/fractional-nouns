// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract NounsFungibleToken is ERC20, Ownable {
    /**
     * @notice Initializes the NounsFungibleToken contract
     * @param initialOwner The address that will be granted the owner role
     */
    constructor(address initialOwner) ERC20('Nouns Fungible Token', unicode'$⌐◧-◧') Ownable(initialOwner) {}

    /**
     * @notice Mints new tokens to the specified address
     * @dev Only callable by the owner
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens from the specified address
     * @dev Only callable by the owner
     * @param from The address from which tokens will be burned
     * @param amount The amount of tokens to burn
     */
    function burn(address from, uint256 amount) external onlyOwner {
        _burn(from, amount);
    }
}
