import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with this account: ", deployer.address);

  const vesting = await ethers.deployContract("Vesting", [
    "0x641C0F8b889F8336A69f464ddAE3733e3dE3788A",
  ]);

  await vesting.waitForDeployment();

  console.log("Vesting:", vesting.target);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
