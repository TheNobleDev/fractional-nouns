// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import { INounsToken } from './external/nouns/interfaces/INounsToken.sol';
import { INounsDaoProxy } from './external/nouns/interfaces/INounsDaoProxy.sol';

contract Vault {
    address payable public owner;
    INounsToken public nounsToken;
    INounsDaoProxy public nounsDaoProxy;

    error OwnableUnauthorizedAccount(address account);

    constructor() {}

    modifier onlyOwner() {
        if (owner != msg.sender) {
            revert OwnableUnauthorizedAccount(msg.sender);
        }
        _;
    }

    function version() external pure returns (uint8) {
        return 1;
    }

    function initialize(INounsToken _nounsToken, INounsDaoProxy _nounsDaoProxy) external {
        require(owner == address(0), 'Already initialized');
        owner = payable(msg.sender);
        nounsToken = _nounsToken;
        nounsDaoProxy = _nounsDaoProxy;
    }

    function castVote(uint256 proposalId, uint8 support) external onlyOwner {
        nounsDaoProxy.castRefundableVote(proposalId, support);
    }

    function castVote(uint256 proposalId, uint8 support, uint32 clientId) external onlyOwner {
        nounsDaoProxy.castRefundableVote(proposalId, support, clientId);
    }

    function transferNounWithdrawRefund(uint256 nounId, address to) external onlyOwner returns (bool) {
        nounsToken.transferFrom(address(this), to, nounId);
        (bool success, ) = owner.call{ value: address(this).balance }('');
        return success;
    }
}
