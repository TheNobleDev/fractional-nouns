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

    address[] public allVaults;

    mapping(uint256 => address) private _voteOwnerOf;
    mapping(uint256 => uint48) private _voteUnlockBlockOf;
    mapping(uint256 => uint48) private _depositUnlockBlockOf;

    mapping(uint256 => address) public vaultFor;
    mapping(address => uint256) public nounDepositedIn;
    mapping(uint256 => uint256[3]) public voteCountFor;
    mapping(uint256 => uint256) public nextVoteIndexFor;
    mapping(uint256 => mapping(uint256 => bool)) public hasVotedOn;

    error Unauthorized();
    error ZeroInputSize();
    error InvalidSupport();
    error VotingPeriodEnded();
    error DepositNotUnlocked(uint256 fragmentId);
    error FragmentNotUnlocked(uint256 fragmentId);
    error CanOnlyVoteAgainstDuringObjectionPeriod();
    error InvalidFragmentCount(uint256 fragmentCount);
    error AlreadyVoted(uint256 fragmentId, uint256 proposalId);
    error FragmentSizeExceedsDeposit(uint256 fragmentSize, uint48 depositSize);

    event DepositNouns(uint256[] nounIds, uint256[] fragmentSizes, uint48 availableFromBlock, address indexed to);
    event RedeemNouns(uint256 nounsCount, address to);
    event VoteDelegated(uint256 fragmentId, address to);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Modifier to make function callable only when
     * fragment has passed the deposit waiting period
     * @param fragmentId Fragment ID to check for
     */
    modifier ensureDepositUnlocked(uint256 fragmentId) {
        if (isDepositLocked(fragmentId)) {
            revert DepositNotUnlocked(fragmentId);
        }
        _;
    }

    /**
     * @notice Modifier to make function callable only when
     * fragments have passed the deposit waiting period
     * @param fragmentIds Fragment IDs to check for
     */
    modifier ensureDepositUnlockedMulti(uint256[] calldata fragmentIds) {
        for (uint256 i; i < fragmentIds.length; ++i) {
            if (isDepositLocked(fragmentIds[i])) {
                revert DepositNotUnlocked(fragmentIds[i]);
            }
        }
        _;
    }

    /**
     * @notice Initializes the NounsFragmentManager contract
     * @param owner The address that will be granted the owner role
     * @param _nounsToken The address of the NounsToken contract
     * @param _nounsFragmentToken The address of the NounsFragmentToken contract
     * @param _nounsToken The address of the NounsToken contract
     * @param _nounsFragmentToken The address of the NounsFragmentToken contract
     * @param _nounsFungibleToken The address of the NounsFungibleToken contract
     * @param _nounsDaoProxy The address of the NounsDaoProxy contract
     */
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

    /**
     * @notice Fallback function to receive Ether
     */
    receive() external payable {}

    /**
     * @notice Returns the vote power owner of address for a given fragment ID
     * @param fragmentId The ID of the fragment
     * @return The address of the voter
     */
    function votePowerOwnerOf(uint256 fragmentId) public view returns (address) {
        address voter = _voteOwnerOf[fragmentId];
        if (voter == address(0)) {
            return nounsFragmentToken.ownerOf(fragmentId);
        }
        return voter;
    }

    /**
     * @notice Returns true if the fragment is currently locked on deposit
     * Note: This is set as the last voting block of the latest proposal when this fragment was created
     * @param fragmentId The ID of the fragment
     */
    function isDepositLocked(uint256 fragmentId) public view returns (bool) {
        return (block.number <= _depositUnlockBlockOf[fragmentId]);
    }

    /**
     * @notice Returns true if the fragment has voted on a proposal that is live
     * @param fragmentId The ID of the fragment
     */
    function hasLiveVote(uint256 fragmentId) public view returns (bool) {
        return (block.number <= _voteUnlockBlockOf[fragmentId]);
    }

    /**
     * @notice Pauses the contract
     * @dev Only callable by the owner
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract
     * @dev Only callable by the owner
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Withdraws all Eth from the contract
     * @dev Only callable by the owner
     * @param to The address to send the Ether to
     * @return A boolean indicating whether the withdrawal was successful
     */
    function withdrawEth(address payable to) external onlyOwner returns (bool) {
        (bool success, ) = to.call{ value: address(this).balance }('');
        return success;
    }

    /**
     * @notice Deposits Nouns tokens into the contract
     * @param nounIds An array of Noun IDs to deposit
     * @param fragmentSizes An array of fragment sizes to create
     */
    function depositNouns(uint256[] calldata nounIds, uint256[] calldata fragmentSizes) external whenNotPaused {
        _depositNouns(nounIds, fragmentSizes, msg.sender);
    }

    /**
     * @notice Redeems Nouns tokens by burning fragments and ERC20 tokens
     * @param fragmentIds An array of fragment IDs to burn
     * @param fungibleTokenCount The amount of fungible tokens to burn
     */
    function redeemNouns(
        uint256[] calldata fragmentIds,
        uint256 fungibleTokenCount
    ) external whenNotPaused ensureDepositUnlockedMulti(fragmentIds) {
        _redeemNouns(fragmentIds, fungibleTokenCount, msg.sender);
    }

    /**
     * @notice Splits a fragment into smaller fragments and ERC20 tokens
     * @param primaryFragmentId The ID of the fragment to split
     * @param targetFragmentSizes An array of sizes for the new fragments
     * If sum of targetFragmentSizes is less than primary, ERC20 tokens are created
     */
    function splitFragment(
        uint256 primaryFragmentId,
        uint256[] calldata targetFragmentSizes
    ) external whenNotPaused ensureDepositUnlocked(primaryFragmentId) {
        _splitFragment(primaryFragmentId, targetFragmentSizes, msg.sender);
    }

    /**
     * @notice Combines multiple fragments, and ERC20 tokens into a single fragment
     * @param fragmentIds An array of fragment IDs to combine
     * @param fungibleTokenCount The amount of fungible tokens to include
     */
    function combineFragments(
        uint256[] calldata fragmentIds,
        uint256 fungibleTokenCount
    ) external whenNotPaused ensureDepositUnlockedMulti(fragmentIds) {
        _combineFragments(fragmentIds, fungibleTokenCount, msg.sender);
    }

    /**
     * @notice Delegates voting power of fragments to another address
     * @param fragmentIds An array of fragment IDs to delegate
     * @param to The address to delegate voting power to
     */
    function delegateVote(uint256[] calldata fragmentIds, address to) external {
        _delegateVote(fragmentIds, msg.sender, to);
    }

    /**
     * @notice Casts votes for a proposal using fragment voting power
     * @param fragmentIds An array of fragment IDs to vote with
     * @param proposalId The ID of the proposal to vote on
     * @param support The voting position (0: Against, 1: For, 2: Abstain)
     */
    function castVote(
        uint256[] calldata fragmentIds,
        uint256 proposalId,
        uint8 support
    ) external whenNotPaused ensureDepositUnlockedMulti(fragmentIds) {
        _castVote(fragmentIds, proposalId, support, msg.sender);
    }

    // //////////////////
    // Internal Functions
    // //////////////////

    function _depositNouns(uint256[] calldata nounIds, uint256[] calldata fragmentSizes, address to) internal {
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
        uint48 lastVotingBlock = _computeLastVotingBlock(nounsDaoProxy.proposalCount());
        uint256 totalSize;
        uint256 nextFragmentId = nounsFragmentToken.nextTokenId();
        for (uint256 i; i < fragmentSizes.length; ++i) {
            totalSize += fragmentSizes[i];
            _depositUnlockBlockOf[nextFragmentId++] = lastVotingBlock;
            nounsFragmentToken.mint(to, fragmentSizes[i]);
        }

        uint48 depositSize = uint48(numOfNouns * FRAGMENTS_IN_A_NOUN);
        if (totalSize < depositSize) {
            nounsFungibleToken.mint(to, (depositSize - totalSize) * 1e18);
        } else if (totalSize > depositSize) {
            revert FragmentSizeExceedsDeposit(totalSize, depositSize);
        }

        emit DepositNouns(nounIds, fragmentSizes, lastVotingBlock, to);
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
        if (hasLiveVote(primaryFragmentId)) {
            revert FragmentNotUnlocked(primaryFragmentId);
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
        } else if (totalSize > referenceSize) {
            revert FragmentSizeExceedsDeposit(totalSize, uint48(referenceSize));
        }
    }

    function _combineFragments(uint256[] calldata fragmentIds, uint256 fungibleTokenCount, address to) internal {
        uint256 totalSize;
        uint48 maxVoteUnlockBlock;
        if (fragmentIds.length != 0) {
            totalSize = nounsFragmentToken.fragmentCountOf(fragmentIds[0]);
            maxVoteUnlockBlock = _voteUnlockBlockOf[fragmentIds[0]];
        }

        // Starting the loop from 1 as we cannot yet burn the 0th fragment
        for (uint256 i = 1; i < fragmentIds.length; ++i) {
            totalSize += nounsFragmentToken.fragmentCountOf(fragmentIds[i]);
            maxVoteUnlockBlock = uint48(_max(_voteUnlockBlockOf[fragmentIds[i]], maxVoteUnlockBlock));
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
        _voteUnlockBlockOf[nounsFragmentToken.nextTokenId() - 1] = maxVoteUnlockBlock;
    }

    function _delegateVote(uint256[] calldata fragmentIds, address holder, address to) internal {
        for (uint256 i; i < fragmentIds.length; ++i) {
            if (nounsFragmentToken.ownerOf(fragmentIds[i]) != holder) {
                revert Unauthorized();
            }
            _voteOwnerOf[fragmentIds[i]] = to;
            emit VoteDelegated(fragmentIds[i], to);
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
            if (votePowerOwnerOf(fragmentIds[i]) != holder) {
                revert Unauthorized();
            }
            if (hasVotedOn[fragmentIds[i]][proposalId]) {
                revert AlreadyVoted(fragmentIds[i], proposalId);
            }
            hasVotedOn[fragmentIds[i]][proposalId] = true;
            _voteUnlockBlockOf[fragmentIds[i]] = uint48(_max(lastVotingBlock, _voteUnlockBlockOf[fragmentIds[i]]));
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
