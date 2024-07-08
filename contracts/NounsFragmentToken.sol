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
     * @notice Mint a token to the 'to' address, consisting of 'fragmentCount' fragments.
     * @dev Only callable by the owner.
     */
    function mint(address to, uint256 fragmentCount) external onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _mintTo(to, tokenId, fragmentCount);
    }

    /**
     * @notice Mint a token to the 'to' address, consisting of 'fragmentCount' fragments,
     * using the seed from the provided 'tokenSeedToUse'.
     * @dev Only callable by the owner.
     */
    function mint(address to, uint256 fragmentCount, uint256 tokenSeedToUse) external onlyOwner {
        uint256 tokenId = _nextTokenId++;
        _requireOwned(tokenSeedToUse);
        _mintToUsingSeed(to, tokenId, fragmentCount, seeds[tokenSeedToUse]);
    }

    /**
     * @notice Burn a NounFT.
     * @dev Only callable by the owner.
     */
    function burn(uint256 tokenId) external onlyOwner {
        _burn(tokenId);
        delete seeds[tokenId];
        delete fragmentCountOf[tokenId];
    }

    /**
     * @notice Update the fragment count of the provided 'tokenId' to 'newFragmentCount'.
     * @dev Only callable by the owner.
     */
    function updateFragmentCount(uint256 tokenId, uint256 newFragmentCount) external onlyOwner {
        uint256 currentFragmentCount = fragmentCountOf[tokenId];
        fragmentCountOf[tokenId] = newFragmentCount;

        emit NounFTUpdated(tokenId, currentFragmentCount, newFragmentCount);
    }

    /**
     * @notice Set the token URI descriptor.
     * @dev Only callable by the owner.
     */
    function setDescriptor(INounsFragmentDescriptorMinimal _descriptor) external onlyOwner {
        descriptor = _descriptor;

        emit DescriptorUpdated(_descriptor);
    }

    /**
     * @notice Override isApprovedForAll to whitelist user's OpenSea proxy accounts to enable gas-less listings.
     */
    function isApprovedForAll(address owner, address operator) public view override returns (bool) {
        // Whitelist OpenSea proxy contract for easy trading.
        if (proxyRegistry.proxies(owner) == operator) {
            return true;
        }
        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @notice A distinct Uniform Resource Identifier (URI) for a given asset.
     * @dev See {IERC721Metadata-tokenURI}.
     */
    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return descriptor.tokenURI(tokenId, seeds[tokenId], fragmentCountOf[tokenId]);
    }

    /**
     * @notice Similar to `tokenURI`, but always serves a base64 encoded data URI
     * with the JSON contents directly inlined.
     */
    function dataURI(uint256 tokenId) public view returns (string memory) {
        _requireOwned(tokenId);
        return descriptor.dataURI(tokenId, seeds[tokenId], fragmentCountOf[tokenId]);
    }

    /**
     * @notice The next token ID to be minted
     */
    function nextTokenId() public view returns (uint256) {
        return _nextTokenId;
    }

    /**
     * @notice Mint a NounFT with `tokenId`, worth 'fragmentCount' fragments to the provided `to` address.
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
     * @notice Mint a NounFT with `tokenId`, worth 'fragmentCount' fragments, using 'seed' to the provided `to` address.
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
