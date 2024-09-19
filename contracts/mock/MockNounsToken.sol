// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';

contract MockNounsToken is ERC721 {
    uint256 private _nextTokenId;
    MockNounsSeeder mockNounsSeeder;

    constructor() ERC721('MockNounsToken', 'MNT') {
        mockNounsSeeder = new MockNounsSeeder();
    }

    function mint(address to) public {
        uint256 tokenId = _nextTokenId++;
        _mint(to, tokenId);
    }

    struct Seed {
        uint48 background;
        uint48 body;
        uint48 accessory;
        uint48 head;
        uint48 glasses;
    }

    function seeder() public view returns (MockNounsSeeder) {
        return mockNounsSeeder;
    }
}

import { INounsSeeder } from '../external/nouns/interfaces/INounsSeeder.sol';
import { INounsDescriptorMinimal } from '../external/nouns/interfaces/INounsDescriptorMinimal.sol';

contract MockNounsSeeder is INounsSeeder {
    function generateSeed(uint256 nounId, INounsDescriptorMinimal) external pure override returns (Seed memory) {
        return
            Seed({
                background: uint48(nounId % 2),
                body: uint48((nounId + 1) % 3),
                accessory: uint48((nounId + 2) % 4),
                head: uint48((nounId + 3) % 5),
                glasses: uint48((nounId + 4) % 6)
            });
    }
}

contract MockNounsDescriptor is INounsDescriptorMinimal {
    function tokenURI(uint256, INounsSeeder.Seed memory) public pure override returns (string memory) {
        return 'https://nouns.com/token/';
    }

    function dataURI(uint256, INounsSeeder.Seed memory) public pure override returns (string memory) {
        return 'https://nouns.com/token/';
    }

    function tokenURI(uint256, INounsSeeder.Seed memory, uint256) external pure returns (string memory) {
        return 'https://nouns.com/token/';
    }

    function dataURI(uint256, INounsSeeder.Seed memory, uint256) external pure returns (string memory) {
        return 'https://nouns.com/token/';
    }

    function backgroundCount() external pure override returns (uint256) {
        return 2;
    }

    function bodyCount() external pure override returns (uint256) {
        return 3;
    }

    function accessoryCount() external pure override returns (uint256) {
        return 4;
    }

    function headCount() external pure override returns (uint256) {
        return 5;
    }

    function glassesCount() external pure override returns (uint256) {
        return 6;
    }
}
