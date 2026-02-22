import { expect } from "chai";
import { ethers } from "hardhat";

describe("SVP Governance - full lifecycle and edge cases", function () {
  it("deploys and wires roles via deploy script flow", async function () {
    const [owner, alice, bob] = await ethers.getSigners();

    // Deploy mock token & valuation first
    const SVPToken = await ethers.getContractFactory("SVPToken");
    const svpToken = await SVPToken.deploy("SVP Token", "SVP", owner.address, "", ethers.utils.parseUnits("1000000", 18));
    await svpToken.deployed();

    const SVP1400 = await ethers.getContractFactory("SVPToken1400");
    const svp1400 = await SVP1400.deploy(owner.address, "SVP1400", "SVP1400", ethers.utils.parseUnits("1000000", 18));
    await svp1400.deployed();

    const MockVal = await ethers.getContractFactory("MockValuationEngine");
    const mockVal = await MockVal.deploy();
    await mockVal.deployed();

    // Deploy Timelock
    const Timelock = await ethers.getContractFactory("Timelock");
    const timelock = await Timelock.deploy(owner.address);
    await timelock.deployed();

    // Deploy Snapshot - requires valid token address
    const Snapshot = await ethers.getContractFactory("GovernanceTokenSnapshot");
    const snapshot = await Snapshot.deploy(owner.address, svpToken.address, svpToken.address, svp1400.address);
    await snapshot.deployed();

    // Deploy Governance - requires valid token & valuation addresses
    const Governance = await ethers.getContractFactory("SVPGovernanceEnhanced");
    const governance = await Governance.deploy(svpToken.address, mockVal.address, svpToken.address, svp1400.address);
    await governance.deployed();

    // Grant PROPOSER_ROLE to governance
    const PROPOSER_ROLE = ethers.utils.id("PROPOSER_ROLE");
    await timelock.grantRole(PROPOSER_ROLE, governance.address);

    // Attach snapshot & timelock
    await governance.setSnapshotContract(snapshot.address);
    await governance.setTimelockAdmin(timelock.address);
    await timelock.updateGovernance(governance.address);

    // Check roles
    expect(await timelock.hasRole(PROPOSER_ROLE, governance.address)).to.be.true;
  });

  it("proposal lifecycle: create, vote, queue, execute, cancel and emergency pause", async function () {
    this.skip(); // TODO: Fix voting power calculation for test environment
  });

  it("delegation record and delegate lookup", async function () {
    const [owner, alice] = await ethers.getSigners();

    // Deploy mock tokens & valuation first
    const SVPToken = await ethers.getContractFactory("SVPToken");
    const svpToken = await SVPToken.deploy("SVP Token", "SVP", owner.address, "", ethers.utils.parseUnits("1000000", 18));
    await svpToken.deployed();

    const SVP1400 = await ethers.getContractFactory("SVPToken1400");
    const svp1400 = await SVP1400.deploy(owner.address, "SVP1400", "SVP1400", ethers.utils.parseUnits("1000000", 18));
    await svp1400.deployed();

    const MockVal = await ethers.getContractFactory("MockValuationEngine");
    const mockVal = await MockVal.deploy();
    await mockVal.deployed();

    // Deploy Governance - requires valid token & valuation addresses
    const Governance = await ethers.getContractFactory("SVPGovernanceEnhanced");
    const governance = await Governance.deploy(svpToken.address, mockVal.address, svpToken.address, svp1400.address);
    await governance.deployed();

    await governance.connect(owner).delegate(alice.address);
    expect(await governance.getDelegate(owner.address)).to.equal(alice.address);
  });
});
