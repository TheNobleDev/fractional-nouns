// SPDX-License-Identifier: GPL-3.0

/// @title The Nouns Fragment NFT descriptor

pragma solidity ^0.8.20;

import { Strings } from '@openzeppelin/contracts/utils/Strings.sol';
import { INounsSeeder } from './external/nouns/interfaces/INounsSeeder.sol';
import { ISVGRenderer } from './external/nouns/interfaces/ISVGRenderer.sol';
import { INounsToken } from './external/nouns/interfaces/INounsToken.sol';
import { INounsArt } from './external/nouns/interfaces/INounsArt.sol';
import { Base64 } from 'base64-sol/base64.sol';

contract NounsFragmentDescriptor {
    using Strings for uint256;

    struct TokenURIParams {
        string name;
        string description;
        string background;
        string fragments;
        ISVGRenderer.Part[] parts;
    }

    /// @notice The nouns token contract
    INounsToken public nounsToken;

    /// @notice The contract responsible for holding compressed Noun art
    INounsArt public art;

    /// @notice The contract responsible for constructing SVGs
    ISVGRenderer public renderer;

    constructor(INounsToken _nounsToken, ISVGRenderer _renderer) {
        nounsToken = _nounsToken;
        renderer = _renderer;
        refetchArtContract();
    }

    /**
     * @notice Re-fetch the Art contract set in Nouns Token.
     * @dev Should be called if the art contract is updated in NounsToken contract.
     */
    function refetchArtContract() public {
        art = nounsToken.descriptor().art();
    }

    /**
     * @notice Given a token ID and seed, construct a token URI for an official Nouns DAO noun.
     * @dev The returned value may be a base64 encoded data URI or an API URL.
     */
    function tokenURI(
        uint256 tokenId,
        INounsSeeder.Seed memory seed,
        uint256 fragmentCount
    ) external view returns (string memory) {
        return dataURI(tokenId, seed, fragmentCount);
    }

    /**
     * @notice Given a token ID and seed, construct a base64 encoded data URI for an official Nouns DAO noun.
     */
    function dataURI(
        uint256 tokenId,
        INounsSeeder.Seed memory seed,
        uint256 fragmentCount
    ) public view returns (string memory) {
        string memory nounId = tokenId.toString();
        string memory name = string(abi.encodePacked('Noun Fragment ', nounId));
        string memory fragments = fragmentCount.toString();
        string memory description = string(
            abi.encodePacked(
                'Noun Fragment ',
                nounId,
                ' is a fractional member of the Nouns DAO with ',
                fragments,
                ' fragments'
            )
        );

        return genericDataURI(name, description, fragments, seed);
    }

    /**
     * @notice Construct an ERC721 token URI.
     */
    function constructTokenURI(TokenURIParams memory params) public view returns (string memory) {
        string memory image = _generateSVGImage(
            ISVGRenderer.SVGParams({ parts: params.parts, background: params.background })
        );

        // prettier-ignore
        return string(
            abi.encodePacked(
                'data:application/json;base64,',
                Base64.encode(
                    bytes(
                        abi.encodePacked(
                            '{"name":"', params.name, '", "description":"', params.description, '", "attributes": [{"trait_type": "Fragments", "max_value": 1000000, "value": ', params.fragments, '}], "image": "', 'data:image/svg+xml;base64,', image, '"}')
                    )
                )
            )
        );
    }

    /**
     * @notice Given a name, description, and seed, construct a base64 encoded data URI.
     */
    function genericDataURI(
        string memory name,
        string memory description,
        string memory fragments,
        INounsSeeder.Seed memory seed
    ) public view returns (string memory) {
        TokenURIParams memory params = TokenURIParams({
            name: name,
            description: description,
            fragments: fragments,
            parts: _getPartsForSeed(seed),
            background: art.backgrounds(seed.background)
        });
        return constructTokenURI(params);
    }

    /**
     * @notice Given a seed, construct a base64 encoded SVG image.
     */
    function generateSVGImage(INounsSeeder.Seed memory seed) external view returns (string memory) {
        ISVGRenderer.SVGParams memory params = ISVGRenderer.SVGParams({
            parts: _getPartsForSeed(seed),
            background: art.backgrounds(seed.background)
        });

        return _generateSVGImage(params);
    }

    /**
     * @notice Generate an SVG image for use in the ERC721 token URI.
     */
    function _generateSVGImage(ISVGRenderer.SVGParams memory params) internal view returns (string memory svg) {
        return Base64.encode(bytes(renderer.generateSVG(params)));
    }

    /**
     * @notice Get all Noun parts for the passed `seed`.
     */
    function _getPartsForSeed(INounsSeeder.Seed memory seed) internal view returns (ISVGRenderer.Part[] memory) {
        bytes memory body = art.bodies(seed.body);
        bytes memory accessory = art.accessories(seed.accessory);
        bytes memory head = art.heads(seed.head);
        bytes memory glasses_ = art.glasses(seed.glasses);

        ISVGRenderer.Part[] memory parts = new ISVGRenderer.Part[](4);
        parts[0] = ISVGRenderer.Part({ image: body, palette: _getPalette(body) });
        parts[1] = ISVGRenderer.Part({ image: accessory, palette: _getPalette(accessory) });
        parts[2] = ISVGRenderer.Part({ image: head, palette: _getPalette(head) });
        parts[3] = ISVGRenderer.Part({ image: glasses_, palette: _getPalette(glasses_) });
        return parts;
    }

    /**
     * @notice Get the color palette pointer for the passed part.
     */
    function _getPalette(bytes memory part) private view returns (bytes memory) {
        return art.palettes(uint8(part[0]));
    }
}
