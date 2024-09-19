const { expect } = require('chai');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('NounsFragmentToken contract', function () {
  async function deployNounsFragmentTokenFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const MockNounsToken = await ethers.getContractFactory('MockNounsToken');
    const mockNounsToken = await MockNounsToken.deploy();
    await mockNounsToken.waitForDeployment();

    const MockNounsDescriptor = await ethers.getContractFactory('MockNounsDescriptor');
    const mockNounsDescriptor = await MockNounsDescriptor.deploy();
    await mockNounsDescriptor.waitForDeployment();

    const NounsFragmentToken = await ethers.getContractFactory('NounsFragmentToken');
    const proxyRegistryAddress = '0xabcdefabcdefabcdefabcdefabcdefabcdefabcd'; // Replace with actual address
    const nounsFragmentToken = await NounsFragmentToken.deploy(
      owner.address,
      mockNounsDescriptor.target,
      mockNounsToken.target,
      proxyRegistryAddress,
    );
    await nounsFragmentToken.waitForDeployment();

    return { nounsFragmentToken, mockNounsToken, owner, addr1, addr2, addrs };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { nounsFragmentToken, owner } = await loadFixture(deployNounsFragmentTokenFixture);
      expect(await nounsFragmentToken.owner()).to.equal(owner.address);
    });

    it('Should have correct name and symbol', async function () {
      const { nounsFragmentToken } = await loadFixture(deployNounsFragmentTokenFixture);
      expect(await nounsFragmentToken.name()).to.equal('Nouns Fragment Token');
      expect(await nounsFragmentToken.symbol()).to.equal('NOUNFT');
    });
  });

  describe('Minting', function () {
    it('Should allow owner to mint tokens', async function () {
      const { nounsFragmentToken, owner, addr1 } = await loadFixture(
        deployNounsFragmentTokenFixture,
      );
      await nounsFragmentToken.mint(addr1.address, 100);
      expect(await nounsFragmentToken.balanceOf(addr1.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(100);
    });

    it('Should allow owner to mint tokens with a specific seed', async function () {
      const { nounsFragmentToken, mockNounsToken, owner, addr1, addr2 } = await loadFixture(
        deployNounsFragmentTokenFixture,
      );

      await nounsFragmentToken.mint(addr1.address, 100);
      await nounsFragmentToken.mint(addr2.address, 150, 0, {});

      // Check if the token was minted correctly
      expect(await nounsFragmentToken.balanceOf(addr2.address)).to.equal(1);
      expect(await nounsFragmentToken.fragmentCountOf(1)).to.equal(150);

      // Fetch the seed for token 0
      const seedForToken0 = await nounsFragmentToken.seeds(0);

      // Check if the seed for token 1 matches the seed for token 0
      const seedForToken1 = await nounsFragmentToken.seeds(1);
      expect(seedForToken1.background).to.equal(seedForToken0.background);
      expect(seedForToken1.body).to.equal(seedForToken0.body);
      expect(seedForToken1.accessory).to.equal(seedForToken0.accessory);
      expect(seedForToken1.head).to.equal(seedForToken0.head);
      expect(seedForToken1.glasses).to.equal(seedForToken0.glasses);
    });

    it('Should not allow non-owner to mint tokens', async function () {
      const { nounsFragmentToken, addr1, addr2 } = await loadFixture(
        deployNounsFragmentTokenFixture,
      );
      await expect(nounsFragmentToken.connect(addr1).mint(addr2.address, 100))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });
  });

  describe('Burning', function () {
    async function mintTokenFixture() {
      const deployFixture = await loadFixture(deployNounsFragmentTokenFixture);
      await deployFixture.nounsFragmentToken.mint(deployFixture.addr1.address, 100);
      return deployFixture;
    }

    it('Should allow owner to burn tokens', async function () {
      const { nounsFragmentToken, addr1 } = await loadFixture(mintTokenFixture);
      await nounsFragmentToken.burn(0);
      expect(await nounsFragmentToken.balanceOf(addr1.address)).to.equal(0);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(0);
      await expect(nounsFragmentToken.ownerOf(0))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'ERC721NonexistentToken')
        .withArgs(0);
    });

    it('Should not allow non-owner to burn tokens', async function () {
      const { nounsFragmentToken, addr1 } = await loadFixture(mintTokenFixture);
      await expect(nounsFragmentToken.connect(addr1).burn(0))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });

    it('Should not allow owner to burn non-existent tokens', async function () {
      const { nounsFragmentToken } = await loadFixture(mintTokenFixture);
      await expect(nounsFragmentToken.burn(1))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'ERC721NonexistentToken')
        .withArgs(1);
    });
  });

  describe('Updating Fragment Count', function () {
    async function mintTokenFixture() {
      const deployFixture = await loadFixture(deployNounsFragmentTokenFixture);
      await deployFixture.nounsFragmentToken.mint(deployFixture.addr1.address, 100);
      return deployFixture;
    }

    it('Should allow owner to update fragment count', async function () {
      const { nounsFragmentToken } = await loadFixture(mintTokenFixture);
      await nounsFragmentToken.updateFragmentCount(0, 200);
      expect(await nounsFragmentToken.fragmentCountOf(0)).to.equal(200);
    });

    it('Should emit NounFTUpdated event when updating fragment count', async function () {
      const { nounsFragmentToken } = await loadFixture(mintTokenFixture);
      await expect(nounsFragmentToken.updateFragmentCount(0, 200))
        .to.emit(nounsFragmentToken, 'NounFTUpdated')
        .withArgs(0, 100, 200);
    });

    it('Should not allow non-owner to update fragment count', async function () {
      const { nounsFragmentToken, addr1 } = await loadFixture(mintTokenFixture);
      await expect(nounsFragmentToken.connect(addr1).updateFragmentCount(0, 200))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });

    it('Should not allow updating fragment count for non-existent token', async function () {
      const { nounsFragmentToken } = await loadFixture(mintTokenFixture);
      await expect(nounsFragmentToken.updateFragmentCount(1, 200))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'ERC721NonexistentToken')
        .withArgs(1);
    });
  });

  describe('Miscellaneous Tests', function () {
    async function deployFixture() {
      return await loadFixture(deployNounsFragmentTokenFixture);
    }

    it('Should return the correct token URI', async function () {
      const { nounsFragmentToken, addr1 } = await deployFixture();
      await nounsFragmentToken.mint(addr1.address, 100);
      const tokenURI = await nounsFragmentToken.tokenURI(0);
      expect(tokenURI).to.be.a('string');
      // Note: The exact content of the tokenURI depends on the descriptor implementation
    });

    it('Should return the correct data URI', async function () {
      const { nounsFragmentToken, addr1 } = await deployFixture();
      await nounsFragmentToken.mint(addr1.address, 100);
      const dataURI = await nounsFragmentToken.dataURI(0);
      expect(dataURI).to.be.a('string');
      // Note: The exact content of the dataURI depends on the descriptor implementation
    });

    it('Should return the correct next token ID', async function () {
      const { nounsFragmentToken, addr1 } = await deployFixture();
      expect(await nounsFragmentToken.nextTokenId()).to.equal(0);
      await nounsFragmentToken.mint(addr1.address, 100);
      expect(await nounsFragmentToken.nextTokenId()).to.equal(1);
    });

    it('Should allow setting a new descriptor', async function () {
      const { nounsFragmentToken, addr1 } = await deployFixture();
      await expect(nounsFragmentToken.setDescriptor(addr1.address))
        .to.emit(nounsFragmentToken, 'DescriptorUpdated')
        .withArgs(addr1.address);
      expect(await nounsFragmentToken.descriptor()).to.equal(addr1.address);
    });

    it('Should not allow non-owner to set a new descriptor', async function () {
      const { nounsFragmentToken, addr1, addr2 } = await deployFixture();
      await expect(nounsFragmentToken.connect(addr2).setDescriptor(addr1.address))
        .to.be.revertedWithCustomError(nounsFragmentToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr2.address);
    });
  });
});
