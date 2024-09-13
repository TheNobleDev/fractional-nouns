// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const { ethers, upgrades, hre } = require('hardhat');

main();

async function upgrade() {
  const NounsFragmentManager = await ethers.getContractFactory('NounsFragmentManager');
  const nounsFragmentManager = await upgrades.upgradeProxy(
    '0x4Df1Da96fD0a7F56380bAD3bab47898de4F6DFF8',
    NounsFragmentManager,
  );
  await nounsFragmentManager.waitForDeployment();
  console.log('NounsFragmentManager upgraded');
}

async function main() {
  const [deployer] = await ethers.getSigners();

  let descriptorAddress = '0x79E04ebCDf1ac2661697B23844149b43acc002d5';
  let nounsTokenAddress = '0x4C4674bb72a096855496a7204962297bd7e12b85';
  let proxyRegistryAddress = '0x152E981d511F8c0865354A71E1cb84d0FB318470';
  let nounsDaoProxy = '0x35d2670d7C8931AACdd37C89Ddcb0638c3c44A57';

  const NounsFragmentToken = await ethers.getContractFactory('NounsFragmentToken');
  const NounsFungibleToken = await ethers.getContractFactory('NounsFungibleToken');
  const NounsFragmentManager = await ethers.getContractFactory('NounsFragmentManager');

  console.log('Deploying NounsFragmentToken...');
  const nounsFragmentToken = await NounsFragmentToken.deploy(
    deployer.address, // initialOwner
    descriptorAddress, // _descriptor
    nounsTokenAddress, // _nounsToken
    proxyRegistryAddress, // _proxyRegistry
  );
  console.log('Deploying NounsFungibleToken...');
  const nounsFungibleToken = await NounsFungibleToken.deploy(
    deployer.address, // initialOwner
  );

  await nounsFragmentToken.waitForDeployment();
  console.log('NounsFragmentToken deployed to:', await nounsFragmentToken.getAddress());
  await nounsFungibleToken.waitForDeployment();
  console.log('NounsFungibleToken deployed to:', await nounsFungibleToken.getAddress());

  console.log('Deploying NounsFragmentManager...');
  const nounsFragmentManager = await upgrades.deployProxy(NounsFragmentManager, [
    deployer.address,
    nounsTokenAddress,
    '0x661290d6f8c8490419cd5d92f01d507f402189c1',
    '0x826595D1c7D3506c808263d28Fde788f4d140B0f',
    nounsDaoProxy,
  ]);
  await nounsFragmentManager.waitForDeployment();
  console.log('NounsFragmentManager deployed to:', await nounsFragmentManager.getAddress());

  // console.log('Verifying contracts...');

  // await hre.run('verify:verify', {
  //   address: '0x661290d6f8c8490419cd5d92f01d507f402189c1',
  //   constructorArguments: [
  //     deployer.address, // initialOwner
  //     descriptorAddress, // _descriptor
  //     nounsTokenAddress, // _nounsToken
  //     proxyRegistryAddress, // _proxyRegistry
  //   ],
  // });
  // console.log('NounsFragmentToken verified');

  // await hre.run('verify:verify', {
  //   address: '0x826595D1c7D3506c808263d28Fde788f4d140B0f',
  //   constructorArguments: [
  //     deployer.address, // initialOwner
  //   ],
  // });
  // console.log('NounsFungibleToken verified');

  // await hre.run('verify:verify', {
  //   address: '0x1c83F10AFa8cfd7c48Ba0075682faD0a98Ed7E33',
  //   constructorArguments: [],
  // });
  // console.log('NounsFragmentManager verified');

  // Set up any necessary permissions or initializations here
  await nounsFragmentToken.transferOwnership(await nounsFragmentManager.getAddress());
  await nounsFungibleToken.transferOwnership(await nounsFragmentManager.getAddress());
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch(error => {
  console.error(error);
  process.exitCode = 1;
});
