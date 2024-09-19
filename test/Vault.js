const { expect } = require('chai');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('Vault contract', function () {
  async function deployVaultFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const Vault = await ethers.getContractFactory('Vault');
    const vault = await Vault.deploy();
    await vault.waitForDeployment();

    const MockNounsToken = await ethers.getContractFactory('MockNounsToken');
    const mockNounsToken = await MockNounsToken.deploy();
    await mockNounsToken.waitForDeployment();

    const MockNounsDaoProxy = await ethers.getContractFactory('MockNounsDaoProxy');
    const mockNounsDaoProxy = await MockNounsDaoProxy.deploy();
    await mockNounsDaoProxy.waitForDeployment();

    await vault.initialize(mockNounsToken.target, mockNounsDaoProxy.target);

    return { vault, mockNounsToken, mockNounsDaoProxy, owner, addr1, addr2 };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { vault, owner } = await loadFixture(deployVaultFixture);
      expect(await vault.owner()).to.equal(owner.address);
    });

    it('Should not allow re-initialization', async function () {
      const { vault, mockNounsToken, mockNounsDaoProxy } = await loadFixture(deployVaultFixture);
      await expect(
        vault.initialize(mockNounsToken.target, mockNounsDaoProxy.target),
      ).to.be.revertedWith('Already initialized');
    });
  });

  describe('Functionality', function () {
    it('Should allow owner to cast vote', async function () {
      const { vault, mockNounsDaoProxy, owner, addr1 } = await loadFixture(deployVaultFixture);
      await expect(vault.castVote(1, 1, 0, addr1.address)).to.not.be.reverted;
    });

    it('Should not allow non-owner to cast vote', async function () {
      const { vault, addr1 } = await loadFixture(deployVaultFixture);
      await expect(vault.connect(addr1).castVote(1, 1, 0, addr1.address))
        .to.be.revertedWithCustomError(vault, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });

    it('Should allow owner to transfer Noun', async function () {
      const { vault, mockNounsToken, owner, addr1 } = await loadFixture(deployVaultFixture);
      await mockNounsToken.mint(vault.target);
      await expect(vault.transferNoun(0, addr1.address)).to.not.be.reverted;
      expect(await mockNounsToken.ownerOf(0)).to.equal(addr1.address);
    });

    it('Should not allow non-owner to transfer Noun', async function () {
      const { vault, mockNounsToken, addr1 } = await loadFixture(deployVaultFixture);
      await mockNounsToken.mint(vault.target);
      await expect(vault.connect(addr1).transferNoun(0, addr1.address))
        .to.be.revertedWithCustomError(vault, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });
    it('Should return the correct version', async function () {
      const { vault } = await loadFixture(deployVaultFixture);
      expect(await vault.version()).to.equal(1);
    });
  });
});
