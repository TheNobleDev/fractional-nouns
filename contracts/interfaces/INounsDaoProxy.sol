// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsDaoProxy

pragma solidity ^0.8.20;

interface INounsDaoProxy {
    function castRefundableVote(uint256 proposalId, uint8 support) external;

    function castRefundableVote(uint256 proposalId, uint8 support, uint32 clientId) external;
}
