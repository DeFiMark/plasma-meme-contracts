require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
let secret = require("./secret");
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    hardhat: {
      chainId: 8453//137//8453//137//8453//56
    },
    bscTestnet: {
      url: 'https://data-seed-prebsc-2-s1.binance.org:8545/',
      accounts: [secret.key]
    },
    bscMainnet: {
      url: 'https://bnb-mainnet.g.alchemy.com/v2/BI5XlYByNdQfh3hcluwetuwR9KzTSn01',
      accounts: [secret.key]
    },
    polygonTestnet: {
      url: 'https://polygon-mumbai-bor-rpc.publicnode.com/',
      accounts: [secret.key]
    },
    polygonMainnet: {
      url: 'https://polygon-rpc.com/',//'https://polygon-bor-rpc.publicnode.com',
      accounts: [secret.key],
      // chainId: 137
    },
    baseMainnet: {
      url: 'https://base-mainnet.g.alchemy.com/v2/BI5XlYByNdQfh3hcluwetuwR9KzTSn01',
      accounts: [secret.key],
      chainId: 8453
    }
  },
  etherscan: {
    apiKey: secret.basescanAPI,//polygonAPI,//basescanAPI,//polygonAPI//bscscanAPI
    customChains: [
      {
        network: "base",
        chainId: 8453,
        urls: {
          apiURL: "https://api.basescan.org/api",
          browserURL: "https://basescan.org/"
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
      {
        version: "0.8.20",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
            details: {
              yul: false
            }
          }
        }
      }
    ]
  }
};
