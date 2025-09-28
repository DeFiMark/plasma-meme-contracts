require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
let secret = require("./secret");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      chainId: 9745
    },
    plasma: {
      url: 'https://rpc.plasma.to',
      accounts: [secret.key],
      chainId: 9745
    },
  },
  etherscan: {
    apiKey: {
      plasma: 'plasma',
    },
    customChains: [
      {
        network: "plasma",
        chainId: 9745,
        urls: {
          apiURL: "https://api.routescan.io/v2/network/mainnet/evm/9745/etherscan",
          browserURL: "https://plasmaexplorer.io"
        }
      }
    ]
  },
  solidity: {
    compilers: [
      {
        version: "0.8.28",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false
            }
          }
        }
      },
      // {
      //   version: "0.8.20",
      //   settings: {
      //     optimizer: {
      //       enabled: true,
      //       runs: 200,
      //       details: {
      //         yul: false
      //       }
      //     }
      //   }
      // }
    ]
  }
};