/** @type import('hardhat/config').HardhatUserConfig */
require("@nomicfoundation/hardhat-toolbox");

module.exports = {
  solidity: {
    version: "0.7.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.MAINNETURL_ALCHEMY , // Your Alchemy URL
      },
      gasPrice: "auto", // Automatically sets gas price for transactions
    },
    localhost: {
      url: "http://127.0.0.1:8545", // Local Hardhat node for testing
    },
  },
};