// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsDaoProxy

pragma solidity ^0.8.20;

import { NounsDAOTypes } from './NounsDAOInterfaces.sol';

interface INounsDaoProxy {
    function proposalCount() external view returns (uint256);

    function state(uint256 proposalId) external view returns (NounsDAOTypes.ProposalState);

    function objectionPeriodDurationInBlocks() external view returns (uint256);

    function proposalsV3(uint256 proposalId) external view returns (NounsDAOTypes.ProposalCondensedV3 memory);

    function castRefundableVote(uint256 proposalId, uint8 support) external;

    function castRefundableVote(uint256 proposalId, uint8 support, uint32 clientId) external;
}
