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
        url: " https://eth-mainnet.g.alchemy.com/v2/RD7nbqVS_IPopOiBoSeB7G12jCILnzNH" , // Your Alchemy URL
      },
    },
    localhost: {
      url: "http://127.0.0.1:8545", // Local Hardhat node for testing
    },
  },
};