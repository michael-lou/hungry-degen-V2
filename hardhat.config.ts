import '@nomicfoundation/hardhat-chai-matchers';
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';
import '@typechain/hardhat';
import 'hardhat-abi-exporter';
import { HardhatUserConfig } from 'hardhat/config';

// 动态导入 zkSync 插件（仅在需要时）
const isZkSyncNetwork = process.env.HARDHAT_NETWORK?.includes('abstract') || false;

if (isZkSyncNetwork) {
  console.log('Loading zkSync plugins for network:', process.env.HARDHAT_NETWORK);
  require("@matterlabs/hardhat-zksync");
} else {
  console.log('Using standard EVM configuration for network:', process.env.HARDHAT_NETWORK);
}

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.22',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
      viaIR: true, // 启用 Intermediate Representation 以获得更好的优化
    },
  },
  // zksolc 配置只在 zkSync 网络时启用
  ...(isZkSyncNetwork && {
    zksolc: {
      version: '1.5.3',
      settings: {
        // find all available options in the official documentation
        // https://docs.zksync.io/build/tooling/hardhat/hardhat-zksync-solc#configuration
        codegen: 'evmla', // 使用与标准 EVM 兼容的代码生成
      },
    },
  }),
  networks: {
    // Local Hardhat network
    localhost: {
      url: 'http://127.0.0.1:8545',
      chainId: 31337,
    },
    
    // HyperEVM Networks (使用保守的 gas 限制)
    hyperevmTestnet: {
      url: 'https://rpc.hyperliquid-testnet.xyz/evm',
      chainId: 998,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      gas: 6000000, // 更保守的 gas 限制
    },
    hyperevmMainnet: {
      url: 'https://rpc.hyperliquid.xyz', 
      chainId: 999,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    
    // Base Networks
    baseSepolia: {
      url: 'https://sepolia.base.org',
      chainId: 84532,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 2000000000, // 2 gwei - 提高 gas 价格
      gas: 6000000,
      timeout: 60000, // 60秒超时
    },
    baseMainnet: {
      url: 'https://mainnet.base.org',
      chainId: 8453,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      gasPrice: 1000000000, // 1 gwei
      gas: 6000000,
    },
    
    // Abstract Networks (keeping existing)
    abstractTestnet: {
      url: 'https://api.testnet.abs.xyz',
      ethNetwork: 'sepolia',
      zksync: true,
      chainId: 11124,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    abstractMainnet: {
      url: 'https://api.mainnet.abs.xyz',
      ethNetwork: 'mainnet',
      zksync: true,
      chainId: 2741,
      accounts: process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  abiExporter: {
    path: './abi',
    clear: true,
    flat: true,
    only: [],
    // 或者排除某些合约
    // except: ['ERC20'],
    spacing: 2,
    format: 'json', // 也支持 "minimal"
    runOnCompile: true,
  },
};

export default config;
