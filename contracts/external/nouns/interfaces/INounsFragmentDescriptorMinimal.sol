// SPDX-License-Identifier: GPL-3.0

/// @title Minimal interface for NounsFragmentDescriptor versions, as used by NounsFragmentToken.

pragma solidity ^0.8.20;

import { INounsSeeder } from './INounsSeeder.sol';

interface INounsFragmentDescriptorMinimal {
    function tokenURI(
        uint256 tokenId,
        INounsSeeder.Seed memory seed,
        uint256 fragmentCount
    ) external view returns (string memory);

    function dataURI(
        uint256 tokenId,
        INounsSeeder.Seed memory seed,
        uint256 fragmentCount
    ) external view returns (string memory);
}
