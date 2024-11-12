import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import dotenv from "dotenv";

dotenv.config();

const config: HardhatUserConfig = {
  solidity: "0.8.24",
  networks: {
    sepolia: {
      chainId: 11155111,
      accounts: [process.env.PRIVATE_KEY ?? ""],
      url: "https://1rpc.io/sepolia",
      timeout: 60000000000,
    },
    mainnet: {
      chainId: 1,
      accounts: [process.env.PRIVATE_KEY ?? ""],
      url: "https://rpc.ankr.com/eth",
      timeout: 60000000000,
    },
  },
  etherscan: {
    apiKey: {
      sepolia: process.env.ETH_API_KEY ?? "",
      mainnet: process.env.ETH_API_KEY ?? "",
    },
  },
  sourcify: {
    enabled: true,
  },
};

export default config;
