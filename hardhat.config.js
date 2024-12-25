require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-verify");
require('dotenv').config()

const PRIVATE_KEY = process.env.PRIVATE_KEY;

module.exports = {
  solidity: "0.8.28",
  networks: {
    mainbsc: {
      url: `https://bsc-rpc.publicnode.com`,
      accounts: [PRIVATE_KEY],
    },
    testbsc: {
      url: `https://bsc-testnet-rpc.publicnode.com`,
      accounts: [PRIVATE_KEY],
    },
    sonic: {
      url: `https://rpc.soniclabs.com`,
      chainId: 146,
      accounts: [PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      bscTestnet: process.env.BSC_API_KEY,
      bsc: process.env.BSC_API_KEY,
      sonic: process.env.SONIC_API_KEY
    },
    customChains: [
      {
        network: "sonic",
        chainId: 146,
        urls: {
          apiURL: "https://api.sonicscan.org/api",
          browserURL: "https://sonicscan.org"
        }
      },
      {
        network: "sonicTestnet",
        chainId: 57054,
        urls: {
          apiURL: "https://api-testnet.sonicscan.org/api",
          browserURL: "https://testnet.sonicscan.org"
        }
      }
    ]
  },
  sourcify: {
    enabled: true,
  },
};
