// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsDescriptorArt

pragma solidity ^0.8.20;

import { INounsArt } from '../external/nouns/interfaces/INounsArt.sol';

interface INounsDescriptorArt {
    function art() external returns (INounsArt);
}
