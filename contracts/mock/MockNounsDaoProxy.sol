// SPDX-License-Identifier: GPL-3.0

/// @title Interface for NounsDaoProxy

pragma solidity ^0.8.20;

import { NounsDAOTypes } from '../external/nouns/interfaces/NounsDAOInterfaces.sol';

contract MockNounsDaoProxy {
    uint256 private _proposalCount;
    mapping(uint256 => NounsDAOTypes.ProposalState) private _proposalStates;
    uint256 private _objectionPeriodDurationInBlocks;
    mapping(uint256 => NounsDAOTypes.ProposalCondensedV3) private _proposalsV3;

    function proposalCount() external view returns (uint256) {
        return _proposalCount;
    }

    function setProposalCount(uint256 count) external {
        _proposalCount = count;
    }

    function state(uint256 proposalId) external view returns (NounsDAOTypes.ProposalState) {
        return _proposalStates[proposalId];
    }

    function setState(uint256 proposalId, NounsDAOTypes.ProposalState _state) external {
        _proposalStates[proposalId] = _state;
    }

    function objectionPeriodDurationInBlocks() external view returns (uint256) {
        return _objectionPeriodDurationInBlocks;
    }

    function setObjectionPeriodDurationInBlocks(uint256 duration) external {
        _objectionPeriodDurationInBlocks = duration;
    }

    function proposalsV3(uint256 proposalId) external view returns (NounsDAOTypes.ProposalCondensedV3 memory) {
        return _proposalsV3[proposalId];
    }

    function setProposalsV3(uint256 proposalId, NounsDAOTypes.ProposalCondensedV3 memory proposal) external {
        _proposalsV3[proposalId] = proposal;
    }

    function castRefundableVote(uint256 proposalId, uint8 support) external {}

    function castRefundableVote(uint256 proposalId, uint8 support, uint32 clientId) external {}
}
