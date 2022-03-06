import { HardhatUserConfig } from 'hardhat/config';
import '@typechain/hardhat';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.10',
      },
      {
        version: '0.7.60',
      },
      {
        version: '0.7.0',
      }
    ],
    settings: {
      evmVersion: 'london',
      optimizer: { enabled: true, runs: 200 },
    },
  },
  typechain: {
    target: 'ethers-v5',
  },
  networks: {
    ganache: {
      url: `http://${process.env.GANACHE_HOST || 'localhost'}:8545`,
    },
    hardhat: {
      blockGasLimit: 15000000,
      accounts: {
         count: 1,
       }
    },
  },
  paths: {
    sources: 'src/',
    artifacts: './artifacts',
  },
  external: {
    command: 'node ./src/scripts/compileHasher.js',
    targets: [
      {
        path: './out/Hasher.sol/Hasher.json',
      },
    ],
  },
};

export default config;
