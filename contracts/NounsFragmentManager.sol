// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.20;

import '@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import { IERC20 } from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import { Clones } from '@openzeppelin/contracts/proxy/Clones.sol';
import { Vault } from './Vault.sol';
import { NounsFragmentToken } from './NounsFragmentToken.sol';
import { NounsFungibleToken } from './NounsFungibleToken.sol';
import { INounsToken } from './external/nouns/interfaces/INounsToken.sol';
import { INounsDaoProxy } from './external/nouns/interfaces/INounsDaoProxy.sol';
import { NounsDAOTypes } from './external/nouns/interfaces/NounsDAOInterfaces.sol';

contract NounsFragmentManager is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 public constant FRAGMENTS_IN_A_NOUN = 1_000_000;
    uint256 public totalNounsDeposited;
    address public vaultImplementation;

    INounsToken public nounsToken;
    NounsFragmentToken public nounsFragmentToken;
    NounsFungibleToken public nounsFungibleToken;
    INounsDaoProxy public nounsDaoProxy;

    struct DepositInfo {
        uint48 availableFromBlock;
        uint48 size;
        address to;
    }

    address[] public allVaults;
    mapping(uint256 => address) public vaultFor;
    mapping(uint256 => uint48) public unlockBlockOf;
    mapping(address => uint256) public nounDepositedIn;
    mapping(uint256 => uint256[3]) public voteCountFor;
    mapping(uint256 => uint256) public nextVoteIndexFor;
    mapping(uint256 => DepositInfo) public depositInfoOf;
    mapping(uint256 => mapping(uint256 => bool)) public hasVotedOn;

    error Unauthorized();
    error ZeroInputSize();
    error InvalidSupport();
    error VotingPeriodEnded();
    error DepositNotAvailable();
    error FragmentNotUnlocked();
    error CanOnlyVoteAgainstDuringObjectionPeriod();
    error InvalidFragmentCount(uint256 fragmentCount);
    error AlreadyVoted(uint256 fragmentId, uint256 proposalId);
    error FragmentSizeExceedsDeposit(uint256 fragmentSize, uint48 depositSize);

    event DepositNouns(uint256 depositId, uint48 availableFromBlock, uint256[] nounIds, address indexed to);
    event RedeemNouns(uint256 nounsCount, address to);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner,
        INounsToken _nounsToken,
        NounsFragmentToken _nounsFragmentToken,
        NounsFungibleToken _nounsFungibleToken,
        INounsDaoProxy _nounsDaoProxy
    ) public initializer {
        __Pausable_init();
        __Ownable_init(owner);
        __UUPSUpgradeable_init();

        nounsToken = _nounsToken;
        nounsFragmentToken = _nounsFragmentToken;
        nounsFungibleToken = _nounsFungibleToken;
        nounsDaoProxy = _nounsDaoProxy;
        vaultImplementation = address(new Vault());
    }

    receive() external payable {}

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function withdrawEth(address payable to) external onlyOwner returns (bool) {
        (bool success, ) = to.call{ value: address(this).balance }('');
        return success;
    }

    function depositNouns(uint256[] calldata nounIds) external whenNotPaused {
        _depositNouns(nounIds, msg.sender);
    }

    function createFragments(uint256 depositId, uint256[] calldata fragmentSizes) external whenNotPaused {
        _createFragments(depositId, fragmentSizes, msg.sender);
    }

    function redeemNouns(uint256[] calldata fragmentIds, uint256 fungibleTokenCount) external whenNotPaused {
        _redeemNouns(fragmentIds, fungibleTokenCount, msg.sender);
    }

    function splitFragment(uint256 primaryFragmentId, uint256[] calldata targetFragmentSizes) external whenNotPaused {
        _splitFragment(primaryFragmentId, targetFragmentSizes, msg.sender);
    }

    function combineFragments(uint256[] calldata fragmentSizes, uint256 fungibleTokenCount) external whenNotPaused {
        _combineFragments(fragmentSizes, fungibleTokenCount, msg.sender);
    }

    function castVote(uint256[] calldata fragmentIds, uint256 proposalId, uint8 support) external whenNotPaused {
        _castVote(fragmentIds, proposalId, support, msg.sender);
    }

    // //////////////////
    // Internal Functions
    // //////////////////

    function _depositNouns(uint256[] calldata nounIds, address to) internal {
        uint256 numOfNouns = nounIds.length;
        if (numOfNouns == 0) {
            revert ZeroInputSize();
        }
        for (uint256 i; i < numOfNouns; ++i) {
            address vault = _fetchOrCreateVault(nounIds[i]); // seed the vault with nounId
            nounDepositedIn[vault] = nounIds[i];
            allVaults.push(vault);
            nounsToken.transferFrom(to, vault, nounIds[i]);
        }
        totalNounsDeposited += numOfNouns;
        uint48 availableFromBlock = _computeLastVotingBlock(nounsDaoProxy.proposalCount());
        uint48 size = uint48(numOfNouns * FRAGMENTS_IN_A_NOUN);
        uint256 depositId = nounIds[0];

        depositInfoOf[depositId] = DepositInfo(availableFromBlock, size, to);
        emit DepositNouns(depositId, availableFromBlock, nounIds, to);
    }

    function _createFragments(uint256 depositId, uint256[] calldata fragmentSizes, address to) internal {
        DepositInfo memory info = depositInfoOf[depositId];
        if (to != info.to) {
            revert Unauthorized();
        }

        if (block.number <= uint256(info.availableFromBlock)) {
            revert DepositNotAvailable();
        }

        uint256 totalSize;
        for (uint256 i; i < fragmentSizes.length; ++i) {
            totalSize += fragmentSizes[i];
            nounsFragmentToken.mint(to, fragmentSizes[i]);
        }

        if (totalSize > info.size) {
            revert FragmentSizeExceedsDeposit(totalSize, info.size);
        }

        if (totalSize < info.size) {
            nounsFungibleToken.mint(to, (info.size - totalSize) * 1e18);
        }

        // delete depositInfoOf depositId, so it may be deposited again in the future
        delete depositInfoOf[depositId];
    }

    function _redeemNouns(uint256[] calldata fragmentIds, uint256 fungibleTokenCount, address to) internal {
        uint256 totalSize;
        for (uint256 i; i < fragmentIds.length; ++i) {
            totalSize += nounsFragmentToken.fragmentCountOf(fragmentIds[i]);
            nounsFragmentToken.burn(fragmentIds[i]);
        }
        totalSize += fungibleTokenCount / 1e18;
        nounsFungibleToken.burn(to, fungibleTokenCount);

        uint256 nounsCount = totalSize / FRAGMENTS_IN_A_NOUN;
        if (nounsCount == 0 || totalSize % FRAGMENTS_IN_A_NOUN != 0) {
            revert InvalidFragmentCount(totalSize);
        }
        _transferNouns(nounsCount, to);

        emit RedeemNouns(nounsCount, to);
    }

    function _transferNouns(uint256 nounsCount, address to) internal {
        uint256 currentTotal = totalNounsDeposited;
        totalNounsDeposited = currentTotal - nounsCount;
        for (uint256 i = currentTotal; i > totalNounsDeposited; --i) {
            address vault = allVaults[i];
            Vault(vault).transferNounWithdrawRefund(nounDepositedIn[vault], to);
            allVaults.pop();
            delete nounDepositedIn[vault];
        }
    }

    function _splitFragment(uint256 primaryFragmentId, uint256[] calldata fragmentSizes, address to) internal {
        if (block.number <= unlockBlockOf[primaryFragmentId]) {
            revert FragmentNotUnlocked();
        }

        uint256 referenceSize = nounsFragmentToken.fragmentCountOf(primaryFragmentId);
        uint256 totalSize;

        if (fragmentSizes.length != 0) {
            totalSize = fragmentSizes[0];
            nounsFragmentToken.mint(to, fragmentSizes[0], primaryFragmentId);
        }

        // Can only burn after minting the 1st fragment with the same seed
        nounsFragmentToken.burn(primaryFragmentId);

        for (uint256 i = 1; i < fragmentSizes.length; ++i) {
            totalSize += fragmentSizes[i];
            nounsFragmentToken.mint(to, fragmentSizes[i]);
        }

        if (totalSize < referenceSize) {
            nounsFungibleToken.mint(to, (referenceSize - totalSize) * 1e18);
        }
    }

    function _combineFragments(uint256[] calldata fragmentIds, uint256 fungibleTokenCount, address to) internal {
        uint256 totalSize;
        if (fragmentIds.length != 0) {
            totalSize = nounsFragmentToken.fragmentCountOf(fragmentIds[0]);
        }

        // Starting the loop from 1 as we cannot yet burn the 0th fragment
        for (uint256 i = 1; i < fragmentIds.length; ++i) {
            totalSize += nounsFragmentToken.fragmentCountOf(fragmentIds[i]);
            nounsFragmentToken.burn(fragmentIds[i]);
        }
        totalSize += fungibleTokenCount / 1e18;
        nounsFungibleToken.burn(to, fungibleTokenCount);

        uint256 nounsCount = totalSize / FRAGMENTS_IN_A_NOUN;
        if (nounsCount == 0 || totalSize % FRAGMENTS_IN_A_NOUN != 0) {
            revert InvalidFragmentCount(totalSize);
        }

        if (fragmentIds.length != 0) {
            nounsFragmentToken.mint(to, totalSize, fragmentIds[0]);
            nounsFragmentToken.burn(fragmentIds[0]);
        } else {
            nounsFragmentToken.mint(to, totalSize);
        }
    }

    function _castVote(uint256[] calldata fragmentIds, uint256 proposalId, uint8 support, address holder) internal {
        NounsDAOTypes.ProposalState proposalState = nounsDaoProxy.state(proposalId);

        if (support > 2) {
            revert InvalidSupport();
        }

        if (proposalState != NounsDAOTypes.ProposalState.Active) {
            if (proposalState != NounsDAOTypes.ProposalState.ObjectionPeriod) {
                revert VotingPeriodEnded();
            }
            if (support != 0) revert CanOnlyVoteAgainstDuringObjectionPeriod();
        }

        uint256 lastVotingBlock = _computeLastVotingBlock(proposalId);
        uint256 totalSize;
        for (uint256 i; i < fragmentIds.length; ++i) {
            if (nounsFragmentToken.ownerOf(fragmentIds[i]) != holder) {
                revert Unauthorized();
            }
            if (hasVotedOn[fragmentIds[i]][proposalId]) {
                revert AlreadyVoted(fragmentIds[i], proposalId);
            }
            hasVotedOn[fragmentIds[i]][proposalId] = true;
            unlockBlockOf[fragmentIds[i]] = uint48(_max(lastVotingBlock, unlockBlockOf[fragmentIds[i]]));
            totalSize += nounsFragmentToken.fragmentCountOf(fragmentIds[i]);
        }

        for (uint8 i = 0; i <= 2; i++) {
            uint256 votes = voteCountFor[proposalId][i];
            if (i == support) {
                votes += totalSize;
                if (votes >= FRAGMENTS_IN_A_NOUN) {
                    uint256 fullVotes = votes / FRAGMENTS_IN_A_NOUN;
                    voteCountFor[proposalId][i] = votes % FRAGMENTS_IN_A_NOUN;
                    _relayVotes(proposalId, fullVotes, i);
                }
                break;
            }
        }
    }

    function _relayVotes(uint256 proposalId, uint256 numOfNouns, uint8 support) internal {
        uint256 startIndex = nextVoteIndexFor[proposalId];
        for (uint256 i = startIndex; i < startIndex + numOfNouns; ++i) {
            Vault(allVaults[i]).castVote(proposalId, support);
        }
        nextVoteIndexFor[proposalId] = startIndex + numOfNouns;
    }

    function _fetchOrCreateVault(uint256 nounId) internal returns (address) {
        address vault = vaultFor[nounId];
        if (vault == address(0)) {
            vault = Clones.cloneDeterministic(vaultImplementation, bytes32(nounId));
            vaultFor[nounId] = vault;
            Vault(vault).initialize(nounsToken, nounsDaoProxy);
        }
        return vault;
    }

    function _computeLastVotingBlock(uint256 proposalId) internal view returns (uint48) {
        uint256 objectionPeriodDurationInBlocks = nounsDaoProxy.objectionPeriodDurationInBlocks();
        NounsDAOTypes.ProposalCondensedV3 memory proposal = nounsDaoProxy.proposalsV3(proposalId);
        uint256 endBlock = proposal.endBlock;
        uint256 objectionPeriodEndBlock = proposal.objectionPeriodEndBlock;
        return uint48(_max(endBlock + objectionPeriodDurationInBlocks, objectionPeriodEndBlock));
    }

    function _max(uint256 a, uint256 b) internal pure returns (uint256) {
        return a >= b ? a : b;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
