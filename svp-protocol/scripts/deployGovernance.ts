import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  const Timelock = await ethers.getContractFactory("Timelock");
  const timelock = await Timelock.deploy(deployer.address);
  await timelock.deployed();
  console.log("Timelock deployed to:", timelock.address);

  const GovernanceSnapshot = await ethers.getContractFactory("GovernanceTokenSnapshot");
  const governanceSnapshot = await GovernanceSnapshot.deploy(deployer.address, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
  await governanceSnapshot.deployed();
  console.log("GovernanceTokenSnapshot deployed to:", governanceSnapshot.address);

  const SVPGovernance = await ethers.getContractFactory("SVPGovernanceEnhanced");
  const svpGovernance = await SVPGovernance.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
  await svpGovernance.deployed();
  console.log("SVPGovernanceEnhanced deployed to:", svpGovernance.address);

  // Wire roles: grant timelock proposer/executor if needed
  console.log("Deployment complete. Update addresses via admin setters where required.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
