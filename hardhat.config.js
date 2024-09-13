require('@nomicfoundation/hardhat-toolbox');
require('@openzeppelin/hardhat-upgrades');
require('@nomicfoundation/hardhat-verify');
require('dotenv').config();

module.exports = {
  defaultNetwork: 'sepolia',
  networks: {
    sepolia: {
      url: process.env.SEPOLIA_URL || '',
      maxFeePerGas: 25 * 1e9, // 25 gwei
      maxPriorityFeePerGas: 1 * 1e9, // 1 gwei
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    mainnet: {
      url: process.env.MAINNET_URL || '',
      maxFeePerGas: 20 * 1e9, // 20 gwei
      maxPriorityFeePerGas: 1 * 1e9, // 1 gwei
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  solidity: {
    version: '0.8.20',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 40000,
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY,
  },
};
