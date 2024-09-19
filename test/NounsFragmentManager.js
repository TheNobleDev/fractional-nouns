const { expect } = require('chai');
const { upgrades } = require('hardhat');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('NounsFragmentManager', function () {
  async function deployNounsFragmentManagerFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const MockNounsToken = await ethers.getContractFactory('MockNounsToken');
    const nounsToken = await MockNounsToken.deploy();
    await nounsToken.waitForDeployment();

    const MockNounsDescriptor = await ethers.getContractFactory('MockNounsDescriptor');
    const mockNounsDescriptor = await MockNounsDescriptor.deploy();
    await mockNounsDescriptor.waitForDeployment();

    const NounsFragmentToken = await ethers.getContractFactory('NounsFragmentToken');
    const proxyRegistryAddress = '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd'; // Replace with actual address
    const nounsFragmentToken = await NounsFragmentToken.deploy(
      owner.address,
      mockNounsDescriptor.target,
      nounsToken.target,
      proxyRegistryAddress,
    );
    await nounsFragmentToken.waitForDeployment();

    const NounsFungibleToken = await ethers.getContractFactory('NounsFungibleToken');
    const nounsFungibleToken = await NounsFungibleToken.deploy(owner.address);
    await nounsFungibleToken.waitForDeployment();

    const MockNounsDaoProxy = await ethers.getContractFactory('MockNounsDaoProxy');
    const mockNounsDaoProxy = await MockNounsDaoProxy.deploy();
    await mockNounsDaoProxy.waitForDeployment();

    const NounsFragmentManager = await ethers.getContractFactory('NounsFragmentManager');
    const nounsFragmentManager = await upgrades.deployProxy(NounsFragmentManager, [
      owner.address,
      nounsToken.target,
      nounsFragmentToken.target,
      nounsFungibleToken.target,
      mockNounsDaoProxy.target,
    ]);
    await nounsFragmentManager.waitForDeployment();

    await nounsFragmentToken.transferOwnership(nounsFragmentManager.target);
    await nounsFungibleToken.transferOwnership(nounsFragmentManager.target);

    // mint 10 Nouns tokens to owner
    for (let i = 0; i < 10; i++) {
      await nounsToken.mint(owner.address);
    }
    // mint 10 Nouns tokens to addr1
    for (let i = 0; i < 10; i++) {
      await nounsToken.mint(addr1.address);
    }

    // approve the fragment token for the fragment manager
    await nounsToken.setApprovalForAll(nounsFragmentManager.target, true);
    await nounsToken.connect(addr1).setApprovalForAll(nounsFragmentManager.target, true);

    return {
      nounsFragmentManager,
      nounsToken,
      nounsFragmentToken,
      nounsFungibleToken,
      mockNounsDaoProxy,
      owner,
      addr1,
      addr2,
    };
  }

  describe('Initialization', function () {
    it('Should set the right owner', async function () {
      const { nounsFragmentManager, owner } = await loadFixture(deployNounsFragmentManagerFixture);
      expect(await nounsFragmentManager.owner()).to.equal(owner.address);
    });

    it('Should set the correct contract addresses', async function () {
      const {
        nounsFragmentManager,
        nounsToken,
        nounsFragmentToken,
        nounsFungibleToken,
        mockNounsDaoProxy,
      } = await loadFixture(deployNounsFragmentManagerFixture);
      expect(await nounsFragmentManager.nounsToken()).to.equal(nounsToken.target);
      expect(await nounsFragmentManager.nounsFragmentToken()).to.equal(nounsFragmentToken.target);
      expect(await nounsFragmentManager.nounsFungibleToken()).to.equal(nounsFungibleToken.target);
      expect(await nounsFragmentManager.nounsDaoProxy()).to.equal(mockNounsDaoProxy.target);
    });
  });

  describe('Deposit Nouns', function () {
    it('Should deposit Nouns and create fragments & fungible tokens', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, nounsToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);
      await nounsFragmentManager.depositNouns([0], [500000]);
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(500000);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('500000', 18),
      );
    });

    it('Should revert when no nouns deposited', async function () {
      const { nounsFragmentManager } = await loadFixture(deployNounsFragmentManagerFixture);
      await expect(nounsFragmentManager.depositNouns([], [500000])).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'ZeroInputSize',
      );
    });

    it('Should revert when fragment size >= 1M', async function () {
      const { nounsFragmentManager } = await loadFixture(deployNounsFragmentManagerFixture);
      await expect(nounsFragmentManager.depositNouns([0], [1000000])).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'InvalidFragmentSize',
      );
    });

    it('Should revert when fragment sum exceeds deposit', async function () {
      const { nounsFragmentManager } = await loadFixture(deployNounsFragmentManagerFixture);
      await expect(nounsFragmentManager.depositNouns([0, 1], [900000, 900000, 200001]))
        .to.be.revertedWithCustomError(nounsFragmentManager, 'FragmentSizeExceedsDeposit')
        .withArgs(2000001, 2000000);
    });

    it('Should mint only fungible tokens when no fragment sizes given', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, nounsToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);
      await nounsFragmentManager.depositNouns([0], []);
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(0);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('1000000', 18),
      );
    });

    it('Should mint fragments and fungible tokens correctly', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, nounsToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);
      await nounsFragmentManager.depositNouns([0], [300000, 400000]);
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(2);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(300000);
      expect(await nounsFragmentToken.fragmentCountOf(1)).to.equal(400000);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('300000', 18),
      );
    });
  });

  describe('Split Fragment', function () {
    it('Should split a fragment into smaller fragments & fungible token', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, nounsToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);

      await nounsFragmentManager.depositNouns([0], [500000, 500000]);
      await nounsFragmentManager.splitFragment(0, [200000, 200000]);
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(3);
      expect(await nounsFragmentToken.fragmentCountOf(2)).to.equal(200000);
      expect(await nounsFragmentToken.fragmentCountOf(3)).to.equal(200000);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('100000', 18),
      );
    });

    it('Should revert if any one fragment size is 0', async function () {
      const { nounsFragmentManager, nounsFragmentToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);
      await expect(
        nounsFragmentManager.splitFragment(0, [0, 200000, 200000]),
      ).to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidFragmentSize');
      await expect(
        nounsFragmentManager.splitFragment(0, [200000, 0, 200000]),
      ).to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidFragmentSize');
    });

    it('Should revert if sum of total sizes is more than deposited fragment size', async function () {
      const { nounsFragmentManager, nounsFragmentToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);
      await expect(
        nounsFragmentManager.splitFragment(0, [300000, 300000]),
      ).to.be.revertedWithCustomError(nounsFragmentManager, 'FragmentSizeExceedsDeposit');
    });
  });

  describe('Combine Fragments', function () {
    it('Should combine fragments & fungible tokens into a single fragment', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, nounsToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);

      await nounsFragmentManager.depositNouns([0], [200000, 200000]);
      await nounsFragmentManager.combineFragments([0, 1], ethers.parseUnits('200000', 18));
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(2)).to.equal(600000);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('400000', 18),
      );
    });

    it('Should combine only fungible tokens into a single fragment', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);

      await nounsFragmentManager.depositNouns([0], []);
      await nounsFragmentManager.combineFragments([], ethers.parseUnits('500000', 18));
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(500000);
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('500000', 18),
      );
    });

    it('Should revert when sum >= 1M', async function () {
      const { nounsFragmentManager, nounsFragmentToken, nounsFungibleToken, owner } =
        await loadFixture(deployNounsFragmentManagerFixture);

      await nounsFragmentManager.depositNouns([0], [500000, 500000]);
      await expect(nounsFragmentManager.combineFragments([0, 1], 0)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'InvalidFragmentSize',
      );
    });

    it('Should revert when no fractionals and no fungible tokens provided', async function () {
      const { nounsFragmentManager, owner } = await loadFixture(deployNounsFragmentManagerFixture);

      await expect(nounsFragmentManager.combineFragments([], 0)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'InvalidFragmentSize',
      );
    });
  });

  describe('Delegate Vote', function () {
    it('Should delegate vote to a new owner', async function () {
      const { nounsFragmentManager, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);
      expect(await nounsFragmentManager.votePowerOwnerOf(0)).to.equal(owner.address);
      await nounsFragmentManager.delegateVote([0], addr1.address);
      expect(await nounsFragmentManager.votePowerOwnerOf(0)).to.equal(addr1.address);
    });

    it('Should revert when caller not the owner', async function () {
      const { nounsFragmentManager, owner, addr1, addr2 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0], [500000]);
      expect(await nounsFragmentManager.votePowerOwnerOf(0)).to.equal(owner.address);
      await expect(
        nounsFragmentManager.connect(addr1).delegateVote([0], addr2.address),
      ).to.be.revertedWithCustomError(nounsFragmentManager, 'Unauthorized');
      // Ensure the vote power owner hasn't changed
      expect(await nounsFragmentManager.votePowerOwnerOf(0)).to.equal(owner.address);
    });
  });

  describe('Redeem Nouns', function () {
    it('Should redeem Nouns by burning fragments', async function () {
      const { nounsFragmentManager, nounsToken, nounsFragmentToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0], [500000]);

      // Check initial balances
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(500000);

      // Redeem the Noun & Check final balances
      await nounsFragmentManager.redeemNouns([0], ethers.parseUnits('500000', 18), []);
      expect(await nounsFragmentToken.balanceOf(owner.address)).to.equal(0);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(0);

      // Verify the Noun is no longer in the vault
      await expect(nounsFragmentManager.getNounIdAtPosition(0))
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidInput')
        .withArgs(0);
    });

    it('Should allow redeeming 2 or more Nouns with fungible tokens', async function () {
      const { nounsFragmentManager, nounsToken, nounsFungibleToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      // Deposit 4 Nouns and get 4M fungible tokens
      await nounsFragmentManager.depositNouns([0, 1, 2, 3], []);

      // Redeem Noun 1,2 using 2M fungible tokens
      await nounsFragmentManager.redeemNouns([], ethers.parseUnits('2000000', 18), [2, 1]);

      expect(await nounsToken.ownerOf(0)).to.not.equal(owner.address);
      expect(await nounsToken.ownerOf(1)).to.equal(owner.address);
      expect(await nounsToken.ownerOf(2)).to.equal(owner.address);
      expect(await nounsToken.ownerOf(3)).to.not.equal(owner.address);
    });

    it('Should revert if target positions invalid or not sorted ', async function () {
      const { nounsFragmentManager, nounsToken, nounsFungibleToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      // Deposit 4 Nouns and get 4M fungible tokens
      await nounsFragmentManager.depositNouns([0, 1, 2, 3], []);

      // Try to redeem non-existing Nouns 4
      await expect(
        nounsFragmentManager.redeemNouns([], ethers.parseUnits('3000000', 18), [4, 3, 2]),
      )
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidInput')
        .withArgs(4);

      // Try to redeem non decreasing sorted order
      await expect(
        nounsFragmentManager.redeemNouns([], ethers.parseUnits('3000000', 18), [1, 2, 3]),
      )
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidInput')
        .withArgs(2);

      // Try to redeem with insufficient fragments
      await expect(
        nounsFragmentManager.redeemNouns([], ethers.parseUnits('2999999', 18), [1, 2, 3]),
      )
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidFragmentSize')
        .withArgs(2999999);

      // Try to redeem with mismatch in noun count and target positions
      await expect(
        nounsFragmentManager.redeemNouns([], ethers.parseUnits('2000000', 18), [1, 2, 3]),
      )
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidInput')
        .withArgs(3);
    });

    it('Should revert when redeeming more than 1M for a Noun', async function () {
      const { nounsFragmentManager, nounsToken, nounsFungibleToken, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0, 1], []);
      // Attempt to redeem the Noun using 1.8M fungible tokens
      await expect(
        nounsFragmentManager.redeemNouns([], ethers.parseUnits('1800000', 18), [0]),
      ).to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidFragmentSize');
      // Check that balances remain unchanged
      expect(await nounsFungibleToken.balanceOf(owner.address)).to.equal(
        ethers.parseUnits('2000000', 18),
      );
      expect(await nounsToken.ownerOf(0)).to.not.equal(owner.address);
    });
  });

  describe('Cast Vote', function () {
    it('Should revert on invalid support', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);

      await mockNounsDaoProxy.setState(1, 1); // 1 denotes Active state
      // Try to cast a vote with invalid support (3)
      await expect(nounsFragmentManager.castVote([0], 1, 3))
        .to.be.revertedWithCustomError(nounsFragmentManager, 'InvalidInput')
        .withArgs(3);
    });

    it('Should revert if Voting Period Not Active', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);

      await mockNounsDaoProxy.setState(1, 2); // 2 denotes canceled
      await expect(nounsFragmentManager.castVote([0], 1, 2)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'VotingPeriodEnded',
      );

      await mockNounsDaoProxy.setState(1, 9); // 9 denotes Objection Period
      // voting 'abstain' is not allowed
      await expect(nounsFragmentManager.castVote([0], 1, 2)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'CanOnlyVoteAgainstDuringObjectionPeriod',
      );
    });

    it('Should revert if owner is not the vote power owner', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      await nounsFragmentManager.depositNouns([0], [500000]);

      // Delegate voting power to addr1
      await nounsFragmentManager.delegateVote([0], addr1.address);

      await mockNounsDaoProxy.setState(1, 1); // 1 denotes Active state
      // Try to cast a vote as owner (who is no longer the vote power owner)
      await expect(nounsFragmentManager.castVote([0], 1, 1)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'Unauthorized',
      );
    });
    it('Should allow vote power owner to cast vote', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0], [500000]);
      await mockNounsDaoProxy.setState(1, 1); // 1 denotes Active state
      await nounsFragmentManager.castVote([0], 1, 1);
      expect(await nounsFragmentManager.voteCountFor(1, 1)).to.equal(500000);
    });

    it('Should revert if tried to vote twice', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0], [500000]);
      await mockNounsDaoProxy.setState(1, 1); // 1 denotes Active state
      await nounsFragmentManager.castVote([0], 1, 1, 4, {});
      await expect(nounsFragmentManager.castVote([0], 1, 1)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'AlreadyVoted',
      );
    });

    it('Should relay vote if more than 1M votes', async function () {
      const { nounsFragmentManager, mockNounsDaoProxy, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );
      await nounsFragmentManager.depositNouns([0], [500000]);
      await nounsFragmentManager.connect(addr1).depositNouns([10], [500000]);

      await mockNounsDaoProxy.setState(1, 1); // 1 denotes Active state
      await nounsFragmentManager.castVote([0], 1, 1);
      expect(await nounsFragmentManager.voteCountFor(1, 1)).to.equal(500000);
      await nounsFragmentManager.connect(addr1).castVote([1], 1, 1);
      expect(await nounsFragmentManager.voteCountFor(1, 1)).to.equal(0); // vote cast, vote count reset
    });
  });

  describe('Miscellaneous', function () {
    it('Should allow owner to pause and unpause the contract', async function () {
      const { nounsFragmentManager, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      // Pause the contract
      await nounsFragmentManager.connect(owner).pause();
      expect(await nounsFragmentManager.paused()).to.be.true;

      // Try to deposit when paused (should fail)
      await expect(nounsFragmentManager.depositNouns([1], [500000])).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'EnforcedPause',
      );

      // Unpause the contract
      await nounsFragmentManager.connect(owner).unpause();
      expect(await nounsFragmentManager.paused()).to.be.false;

      // Try to deposit when unpaused (should succeed)
      await expect(nounsFragmentManager.depositNouns([1], [500000])).to.not.be.reverted;
    });

    it('Should allow owner to withdraw ETH from the contract', async function () {
      const { nounsFragmentManager, owner, addr1 } = await loadFixture(
        deployNounsFragmentManagerFixture,
      );

      // Send some ETH to the contract
      await addr1.sendTransaction({
        to: nounsFragmentManager.target,
        value: ethers.parseEther('1.0'),
      });

      const initialBalance = await ethers.provider.getBalance(owner.address);

      // Withdraw ETH
      await nounsFragmentManager.connect(owner).withdrawEth(owner.address);

      const finalBalance = await ethers.provider.getBalance(owner.address);

      // Check that the owner's balance increased (accounting for gas costs)
      expect(finalBalance).to.be.gt(initialBalance);
    });

    it('Should return correct Noun ID at a given position', async function () {
      const { nounsFragmentManager, owner } = await loadFixture(deployNounsFragmentManagerFixture);

      // Deposit some Nouns
      await nounsFragmentManager.depositNouns([0, 1, 2], [500000, 500000, 500000]);

      // Check Noun IDs at different positions
      expect(await nounsFragmentManager.getNounIdAtPosition(0)).to.equal(0);
      expect(await nounsFragmentManager.getNounIdAtPosition(1)).to.equal(1);
      expect(await nounsFragmentManager.getNounIdAtPosition(2)).to.equal(2);

      // Check for invalid position
      await expect(nounsFragmentManager.getNounIdAtPosition(3)).to.be.revertedWithCustomError(
        nounsFragmentManager,
        'InvalidInput',
      );
    });
  });
});
