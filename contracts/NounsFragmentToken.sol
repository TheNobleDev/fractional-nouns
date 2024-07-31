// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import { INounsFragmentDescriptorMinimal } from './external/nouns/interfaces/INounsFragmentDescriptorMinimal.sol';
import { INounsDescriptorMinimal } from './external/nouns/interfaces/INounsDescriptorMinimal.sol';
import { INounsToken } from './external/nouns/interfaces/INounsToken.sol';
import { INounsSeeder } from './external/nouns/interfaces/INounsSeeder.sol';
import { IProxyRegistry } from './external/opensea/IProxyRegistry.sol';

contract NounsFragmentToken is ERC721, Ownable {
    // OpenSea's Proxy Registry
    IProxyRegistry public immutable proxyRegistry;

    // The NounsFT token URI descriptor
    INounsFragmentDescriptorMinimal public descriptor;

    // The Nouns token
    INounsToken public nounsToken;

    // The NounFT seeds
    mapping(uint256 => INounsSeeder.Seed) public seeds;

    // The NounFT fragment counts
    mapping(uint256 => uint256) public fragmentCountOf;

    // The internal token ID tracker
    uint256 private _nextTokenId;

    event NounFTCreated(uint256 tokenId, INounsSeeder.Seed seed, uint256 fragmentCount);
    event NounFTUpdated(uint256 tokenId, uint256 oldFragmentCount, uint256 newFragmentCount);
    event DescriptorUpdated(INounsFragmentDescriptorMinimal descriptor);

    /**
     * @notice Initializes the NounsFragmentToken contract
     * @dev Sets up the ERC721 token with name and symbol, and initializes other contract dependencies
     * @param initialOwner The address that will be granted the owner role
     * @param _descriptor The address of the NounsFragmentDescriptor contract
     * @param _nounsToken The address of the NounsToken contract
     * @param _proxyRegistry The address of OpenSea's proxy registry
     */
    constructor(
        address initialOwner,
        INounsFragmentDescriptorMinimal _descriptor,
        INounsToken _nounsToken,
        IProxyRegistry _proxyRegistry
    ) ERC721('Nouns Fragment Token', 'NOUNFT') Ownable(initialOwner) {
        descriptor = _descriptor;
        nounsToken = _nounsToken;
        proxyRegistry = _proxyRegistry;
    }

    /**
     * @notice Mint a token to the 'to' address, consisting of 'fragmentCount' fragments
     * @dev Only callable by the owner
     * @param to The address that will receive the minted token
     * @param fragmentCount The number of fragments the token represents
     */
    function mint(address to, uint256 fragmentCount) external onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _mintTo(to, tokenId, fragmentCount);
    }

    /**
     * @notice Mint a token to the 'to' address, consisting of 'fragmentCount' fragments,
     * using the seed from the provided 'tokenSeedToUse'
     * @dev Only callable by the owner
     * @param to The address that will receive the minted token
     * @param fragmentCount The number of fragments the token represents
     * @param tokenSeedToUse The token ID whose seed should be used for this new token
     */
    function mint(address to, uint256 fragmentCount, uint256 tokenSeedToUse) external onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _requireOwned(tokenSeedToUse);
        _mintToUsingSeed(to, tokenId, fragmentCount, seeds[tokenSeedToUse]);
    }

    /**
     * @notice Burn a NounFT
     * @dev Only callable by the owner
     * @param tokenId The ID of the token to burn
     */
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
        delete seeds[tokenId];
        delete fragmentCountOf[tokenId];
    }

    /**
     * @notice Update the fragment count of the provided 'tokenId' to 'newFragmentCount'
     * @dev Only callable by the owner
     * @param tokenId The ID of the token to update
     * @param newFragmentCount The new fragment count for the token
     */
    function updateFragmentCount(uint256 tokenId, uint256 newFragmentCount) external onlyOwner {
        uint256 currentFragmentCount = fragmentCountOf[tokenId];
        fragmentCountOf[tokenId] = newFragmentCount;

        emit NounFTUpdated(tokenId, currentFragmentCount, newFragmentCount);
    }

    /**
     * @notice Set the token URI descriptor
     * @dev Only callable by the owner
     * @param _descriptor The new descriptor contract address
     */
    function setDescriptor(INounsFragmentDescriptorMinimal _descriptor) external onlyOwner {
        descriptor = _descriptor;

        emit DescriptorUpdated(_descriptor);
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings
     * @param owner The owner of the tokens
     * @param operator The address of the operator to check
     * @return bool Whether the operator is approved for all tokens of the owner
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset
     * @dev See {IERC721Metadata-tokenURI}
     * @param tokenId The ID of the token to get the URI for
     * @return string The token URI
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return descriptor.tokenURI(tokenId, seeds[tokenId], fragmentCountOf[tokenId]);
    }

    /**
     * @notice Similar to `tokenURI`, but always serves a base64 encoded data URI
     * with the JSON contents directly inlined
     * @param tokenId The ID of the token to get the data URI for
     * @return string The data URI for the token
     */
    function dataURI(uint256 tokenId) public view returns (string memory) {
        _requireOwned(tokenId);
        return descriptor.dataURI(tokenId, seeds[tokenId], fragmentCountOf[tokenId]);
    }

    /**
     * @notice The next token ID to be minted
     * @return uint256 The next token ID
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    // //////////////////
    // Internal Functions
    // //////////////////

    /**
     * @notice Mint a NounFT with `tokenId`, worth 'fragmentCount' fragments to the provided `to` address
     * @param to The address that will receive the minted token
     * @param tokenId The ID of the token to mint
     * @param fragmentCount The number of fragments the token represents
     */
    function _mintTo(address to, uint256 tokenId, uint256 fragmentCount) internal {
        INounsSeeder.Seed memory seed = seeds[tokenId] = nounsToken.seeder().generateSeed(
            tokenId,
            INounsDescriptorMinimal(address(descriptor))
        );
        fragmentCountOf[tokenId] = fragmentCount;
        _mint(to, tokenId);

        emit NounFTCreated(tokenId, seed, fragmentCount);
    }

    /**
     * @notice Mint a NounFT with `tokenId`, worth 'fragmentCount' fragments, using 'seed' to the provided `to` address
     * @param to The address that will receive the minted token
     * @param tokenId The ID of the token to mint
     * @param fragmentCount The number of fragments the token represents
     * @param seedToUse The seed to use for this token
     */
    function _mintToUsingSeed(
        address to,
        uint256 tokenId,
        uint256 fragmentCount,
        INounsSeeder.Seed memory seedToUse
    ) internal {
        INounsSeeder.Seed memory seed = seeds[tokenId] = seedToUse;
        fragmentCountOf[tokenId] = fragmentCount;
        _mint(to, tokenId);

        emit NounFTCreated(tokenId, seed, fragmentCount);
    }
}
