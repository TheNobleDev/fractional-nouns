const { expect } = require('chai');
const { loadFixture } = require('@nomicfoundation/hardhat-toolbox/network-helpers');

describe('NounsFungibleToken contract', function () {
  async function deployNounsFungibleTokenFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const NounsFungibleToken = await ethers.getContractFactory('NounsFungibleToken');
    const nounsFungibleToken = await NounsFungibleToken.deploy(owner.address);
    await nounsFungibleToken.waitForDeployment();

    return { nounsFungibleToken, owner, addr1, addr2, addrs };
  }

  describe('Deployment', function () {
    it('Should set the right owner', async function () {
      const { nounsFungibleToken, owner } = await loadFixture(deployNounsFungibleTokenFixture);
      expect(await nounsFungibleToken.owner()).to.equal(owner.address);
    });

    it('Should have correct name and symbol', async function () {
      const { nounsFungibleToken } = await loadFixture(deployNounsFungibleTokenFixture);
      expect(await nounsFungibleToken.name()).to.equal('Nouns Fungible Token');
      expect(await nounsFungibleToken.symbol()).to.equal('$⌐◧-◧');
    });
  });

  describe('Minting', function () {
    it('Should allow owner to mint tokens', async function () {
      const { nounsFungibleToken, owner, addr1 } = await loadFixture(
        deployNounsFungibleTokenFixture,
      );
      await nounsFungibleToken.mint(addr1.address, 100);
      expect(await nounsFungibleToken.balanceOf(addr1.address)).to.equal(100);
    });

    it('Should not allow non-owner to mint tokens', async function () {
      const { nounsFungibleToken, addr1 } = await loadFixture(deployNounsFungibleTokenFixture);
      await expect(nounsFungibleToken.connect(addr1).mint(addr1.address, 100))
        .to.be.revertedWithCustomError(nounsFungibleToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });
  });

  describe('Burning', function () {
    it('Should allow owner to burn tokens', async function () {
      const { nounsFungibleToken, owner, addr1 } = await loadFixture(
        deployNounsFungibleTokenFixture,
      );
      await nounsFungibleToken.mint(addr1.address, 100);
      await nounsFungibleToken.burn(addr1.address, 50);
      expect(await nounsFungibleToken.balanceOf(addr1.address)).to.equal(50);
    });

    it('Should not allow non-owner to burn tokens', async function () {
      const { nounsFungibleToken, owner, addr1 } = await loadFixture(
        deployNounsFungibleTokenFixture,
      );
      await nounsFungibleToken.mint(addr1.address, 100);
      await expect(nounsFungibleToken.connect(addr1).burn(addr1.address, 50))
        .to.be.revertedWithCustomError(nounsFungibleToken, 'OwnableUnauthorizedAccount')
        .withArgs(addr1.address);
    });

    it('Should not allow burning more tokens than owned', async function () {
      const { nounsFungibleToken, owner, addr1 } = await loadFixture(
        deployNounsFungibleTokenFixture,
      );
      await nounsFungibleToken.mint(addr1.address, 100);
      await expect(nounsFungibleToken.burn(addr1.address, 150)).to.be.revertedWithCustomError(
        nounsFungibleToken,
        'ERC20InsufficientBalance',
      );
    });
  });
});
