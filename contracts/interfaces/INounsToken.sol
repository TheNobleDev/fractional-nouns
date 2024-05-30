// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsToken

pragma solidity ^0.8.20;

import { INounsDescriptorArt } from './INounsDescriptorArt.sol';

interface INounsToken {
    function descriptor() external returns (INounsDescriptorArt);
}
