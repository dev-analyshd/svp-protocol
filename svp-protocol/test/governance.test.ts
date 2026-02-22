import { expect } from "chai";
import { ethers } from "hardhat";

describe("Phase 5 Governance - basic scaffold", function () {
  it("deploys governance contracts and allows admin setters", async function () {
    const [owner, other] = await ethers.getSigners();

    const Timelock = await ethers.getContractFactory("Timelock");
    const timelock = await Timelock.deploy(owner.address);
    await timelock.deployed();

    const Snapshot = await ethers.getContractFactory("GovernanceTokenSnapshot");
    const snapshot = await Snapshot.deploy(owner.address, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
    await snapshot.deployed();

    const Governance = await ethers.getContractFactory("SVPGovernanceEnhanced");
    const governance = await Governance.deploy(ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero, ethers.constants.AddressZero);
    await governance.deployed();

    // Deploy SVP tokens and mock valuation for test wiring
    const SVPToken = await ethers.getContractFactory("SVPToken");
    const svpToken = await SVPToken.deploy("SVP Token", "SVP", owner.address, "", ethers.utils.parseUnits("1000000", 18));
    await svpToken.deployed();
    await svpToken.mint(owner.address, ethers.utils.parseUnits("1000", 18));

    const SVP1400 = await ethers.getContractFactory("SVPToken1400");
    const svp1400 = await SVP1400.deploy(owner.address, "SVP1400", "SVP1400", ethers.utils.parseUnits("1000000", 18));
    await svp1400.deployed();

    const MockVal = await ethers.getContractFactory("MockValuationEngine");
    const mockVal = await MockVal.deploy();
    await mockVal.deployed();

    await governance.setTokenAddresses(svpToken.address, svpToken.address, svp1400.address);
    await governance.setValuationEngine(mockVal.address);

    // Admin should be able to set valuation engine
    await expect(governance.connect(owner).setValuationEngine(owner.address)).to.not.be.reverted;

    // Non-admin cannot set valuation engine
    await expect(governance.connect(other).setValuationEngine(other.address)).to.be.reverted;

    // Token addresses setter (admin)
    await expect(governance.connect(owner).setTokenAddresses(owner.address, owner.address, owner.address)).to.not.be.reverted;

    // Check getters return defaults
    const params = await governance.getGovernanceParams();
    expect(params.votingDelay.toNumber()).to.be.greaterThan(0);

    // --- Extended lifecycle test using snapshots and timelock ---
    // Lower proposal threshold for test
    await governance.connect(owner).setProposalThreshold(1);

    // Wire snapshot contract
    await governance.connect(owner).setSnapshotContract(snapshot.address);

    // Create a snapshot for proposal 0
    await snapshot.connect(owner).createSnapshot(0);
    const currentId = (await snapshot.getCurrentSnapshotId()).toNumber();
    const snapshotId = currentId - 1;

    // Record owner voting power in snapshot (e.g., 1000 units)
    const vp = ethers.BigNumber.from("1000");
    await snapshot.connect(owner).recordUserSnapshot(owner.address, snapshotId, vp, vp, ethers.constants.WeiPerEther);

    // Create a simple proposal (target=owner, no-op)
    const targets = [owner.address];
    const values = [0];
    const signatures = [""];
    const calldatas = ["0x"];

    await governance.connect(owner).createProposal("Test", "Lifecycle test", targets, values, signatures, calldatas);
    const proposalId = (await governance.latestProposalIds(owner.address)).toNumber();

    // Attach snapshot and activate proposal
    await governance.connect(owner).attachSnapshotAndActivate(proposalId, snapshotId);

    // Cast a FOR vote
    await governance.connect(owner).castVote(proposalId, 1);

    // Fast-forward past voting period
    const gp = await governance.getGovernanceParams();
    await ethers.provider.send("evm_increaseTime", [gp.votingPeriod.toNumber() + 5]);
    await ethers.provider.send("evm_mine", []);

    // Queue the proposal (owner has TIMELOCK_ADMIN_ROLE per constructor)
    await governance.connect(owner).queueProposal(proposalId);

    // Fast-forward past timelock delay
    await ethers.provider.send("evm_increaseTime", [gp.timelockDelay.toNumber() + 5]);
    await ethers.provider.send("evm_mine", []);

    // Execute proposal
    await governance.connect(owner).executeProposal(proposalId);
  });
});
