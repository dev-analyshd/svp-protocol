import { ethers } from "hardhat";

async function main() {
  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with:", deployer.address);

  // Deploy Timelock (initial governance is deployer)
  const Timelock = await ethers.getContractFactory("Timelock");
  const timelock = await Timelock.deploy(deployer.address);
  await timelock.deployed();
  console.log("Timelock deployed to:", timelock.address);

  // Deploy Snapshot contract
  const Snapshot = await ethers.getContractFactory("GovernanceTokenSnapshot");
  const snapshot = await Snapshot.deploy(deployer.address, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
  await snapshot.deployed();
  console.log("GovernanceTokenSnapshot deployed to:", snapshot.address);

  // Deploy Governance
  const Gov = await ethers.getContractFactory("SVPGovernanceEnhanced");
  const governance = await Gov.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
  await governance.deployed();
  console.log("SVPGovernanceEnhanced deployed to:", governance.address);

  // Deploy SVPToken (ERC20) and SVPToken1400
  const SVPToken = await ethers.getContractFactory("SVPToken");
  const svpToken = await SVPToken.deploy("SVP Token", "SVP", deployer.address, "", ethers.utils.parseUnits("1000000", 18));
  await svpToken.deployed();
  console.log("SVPToken deployed to:", svpToken.address);

  const SVP1400 = await ethers.getContractFactory("SVPToken1400");
  const svp1400 = await SVP1400.deploy(deployer.address, "SVP1400", "SVP1400", ethers.utils.parseUnits("1000000", 18));
  await svp1400.deployed();
  console.log("SVPToken1400 deployed to:", svp1400.address);

  // Mint some tokens to deployer for governance demonstration
  await svpToken.mint(deployer.address, ethers.utils.parseUnits("10000", 18));
  console.log("Minted 10k SVP to deployer");

  // Deploy a mock valuation engine
  const MockVal = await ethers.getContractFactory("MockValuationEngine");
  const mockVal = await MockVal.deploy();
  await mockVal.deployed();
  console.log("MockValuationEngine deployed to:", mockVal.address);

  // Wire token and valuation addresses into governance
  await governance.setTokenAddresses(svpToken.address, svpToken.address, svp1400.address);
  await governance.setValuationEngine(mockVal.address);
  console.log("Governance wired to token and valuation engine");

  // Grant PROPOSER_ROLE on timelock to governance
  const PROPOSER_ROLE = ethers.utils.id("PROPOSER_ROLE");
  await timelock.grantRole(PROPOSER_ROLE, governance.address);
  console.log("Granted PROPOSER_ROLE to governance on timelock");

  // Set snapshot contract on governance
  await governance.setSnapshotContract(snapshot.address);
  console.log("Attached snapshot to governance");

  // Set timelock admin on governance
  await governance.setTimelockAdmin(timelock.address);
  console.log("Timelock admin set on governance");

  // Update timelock governance pointer to governance contract
  await timelock.updateGovernance(governance.address);
  console.log("Timelock governance updated to governance contract");

  console.log("Deployment and wiring complete. Update token addresses and valuation engine with admin as needed.");
}

main().catch((err) => {
  console.error(err);
  process.exitCode = 1;
});
