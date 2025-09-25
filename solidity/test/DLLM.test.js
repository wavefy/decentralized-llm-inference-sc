const { expect } = require("chai");
const { ethers } = require("hardhat");

describe("DLLM Contract", function () {
  let dllm, mockToken;
  let owner, server1, server2, client;
  let clientPrivateKey, clientWallet;

  const PRICE_PER_TOKEN = ethers.parseEther("1");
  const INITIAL_SUPPLY = ethers.parseEther("1000000");

  beforeEach(async function () {
    [owner, server1, server2, client] = await ethers.getSigners();

    // Create a wallet for signing messages
    clientPrivateKey = "0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d";
    clientWallet = new ethers.Wallet(clientPrivateKey);

    // Deploy MockToken
    const MockToken = await ethers.getContractFactory("MockToken");
    mockToken = await MockToken.deploy("Test Token", "TEST", 1000000);
    await mockToken.waitForDeployment();

    // Deploy DLLM contract
    const DLLM = await ethers.getContractFactory("DLLM");
    dllm = await DLLM.deploy(await mockToken.getAddress());
    await dllm.waitForDeployment();

    // Distribute tokens for testing
    await mockToken.transfer(server1.address, ethers.parseEther("10000"));
    await mockToken.transfer(server2.address, ethers.parseEther("10000"));
    await mockToken.transfer(client.address, ethers.parseEther("10000"));
  });

  describe("Deployment", function () {
    it("Should set the correct reward token", async function () {
      expect(await dllm.rewardToken()).to.equal(await mockToken.getAddress());
    });

    it("Should set the correct owner", async function () {
      expect(await dllm.owner()).to.equal(owner.address);
    });
  });

  describe("Deposit", function () {
    it("Should allow users to deposit tokens", async function () {
      const depositAmount = ethers.parseEther("1000");
      
      // Approve DLLM contract to spend tokens
      await mockToken.connect(owner).approve(await dllm.getAddress(), depositAmount);
      
      // Deposit tokens
      await expect(dllm.connect(owner).deposit(depositAmount))
        .to.emit(dllm, "PoolDeposit")
        .withArgs(owner.address, depositAmount);

      expect(await dllm.getBalance(owner.address)).to.equal(depositAmount);
    });

    it("Should fail when depositing zero amount", async function () {
      await expect(dllm.connect(owner).deposit(0))
        .to.be.revertedWithCustomError(dllm, "BalanceInsufficient");
    });
  });

  describe("Create Session", function () {
    beforeEach(async function () {
      // Deposit tokens to reward pool
      const depositAmount = ethers.parseEther("1000");
      await mockToken.connect(owner).approve(await dllm.getAddress(), depositAmount);
      await dllm.connect(owner).deposit(depositAmount);
    });

    it("Should create a session successfully", async function () {
      const sessionId = 1;
      const maxTokens = 10;
      const addresses = [server1.address, server2.address];
      const layers = [10, 10];

      await expect(
        dllm.connect(owner).createSession(
          sessionId,
          maxTokens,
          addresses,
          layers,
          clientWallet.address
        )
      ).to.emit(dllm, "SessionCreated")
        .withArgs(
          sessionId,
          owner.address,
          PRICE_PER_TOKEN,
          maxTokens,
          addresses,
          layers,
          await ethers.provider.getBlock("latest").then(b => b.timestamp + 1)
        );

      expect(await dllm.hasSession(owner.address, sessionId)).to.be.true;
    });

    it("Should fail when arrays length mismatch", async function () {
      const sessionId = 1;
      const maxTokens = 10;
      const addresses = [server1.address, server2.address];
      const layers = [10]; // Wrong length

      await expect(
        dllm.connect(owner).createSession(
          sessionId,
          maxTokens,
          addresses,
          layers,
          clientWallet.address
        )
      ).to.be.revertedWithCustomError(dllm, "InvalidClaim");
    });

    it("Should fail when insufficient balance", async function () {
      const sessionId = 1;
      const maxTokens = 100; // Large amount
      const addresses = [server1.address, server2.address];
      const layers = [10, 10];

      // Required balance: 100 * (10 + 10) * 1e18 = 2000e18, but we only have 1000e18
      await expect(
        dllm.connect(owner).createSession(
          sessionId,
          maxTokens,
          addresses,
          layers,
          clientWallet.address
        )
      ).to.be.revertedWithCustomError(dllm, "BalanceInsufficient");
    });
  });

  describe("Claim Tokens", function () {
    let sessionId, maxTokens, addresses, layers;

    beforeEach(async function () {
      // Set test parameters
      sessionId = 1;
      maxTokens = 10;
      addresses = [server1.address, server2.address];
      layers = [10, 10];

      // Deposit tokens and create session
      const depositAmount = ethers.parseEther("1000");
      await mockToken.connect(owner).approve(await dllm.getAddress(), depositAmount);
      await dllm.connect(owner).deposit(depositAmount);

      await dllm.connect(owner).createSession(
        sessionId,
        maxTokens,
        addresses,
        layers,
        clientWallet.address
      );
    });

    it("Should allow valid token claim", async function () {
      const tokenCount = 1;
      
      // Sign the token count
      const messageHash = ethers.solidityPackedKeccak256(["uint256"], [tokenCount]);
      const signature = await clientWallet.signMessage(ethers.getBytes(messageHash));

      const initialBalance = await mockToken.balanceOf(server1.address);
      
      await expect(
        dllm.connect(server1).claimTokens(
          owner.address,
          sessionId,
          tokenCount,
          signature
        )
      ).to.emit(dllm, "TokenClaimed")
        .withArgs(
          sessionId,
          owner.address,
          server1.address,
          tokenCount,
          BigInt(tokenCount) * BigInt(layers[0]) * PRICE_PER_TOKEN, // total reward
          await ethers.provider.getBlock("latest").then(b => b.timestamp + 1)
        );

      // Check balances
      const expectedReward = BigInt(tokenCount) * BigInt(layers[0]) * PRICE_PER_TOKEN;
      expect(await mockToken.balanceOf(server1.address)).to.equal(initialBalance + expectedReward);
      expect(await dllm.hasClaimed(owner.address, sessionId, server1.address)).to.be.true;
    });

    it("Should fail when claiming own tokens", async function () {
      const tokenCount = 1;
      
      const messageHash = ethers.solidityPackedKeccak256(["uint256"], [tokenCount]);
      const signature = await clientWallet.signMessage(ethers.getBytes(messageHash));

      await expect(
        dllm.connect(owner).claimTokens(
          owner.address,
          sessionId,
          tokenCount,
          signature
        )
      ).to.be.revertedWithCustomError(dllm, "CannotClaimOwnTokens");
    });

    it("Should fail when claiming twice", async function () {
      const tokenCount = 1;
      
      const messageHash = ethers.solidityPackedKeccak256(["uint256"], [tokenCount]);
      const signature = await clientWallet.signMessage(ethers.getBytes(messageHash));

      // First claim
      await dllm.connect(server1).claimTokens(
        owner.address,
        sessionId,
        tokenCount,
        signature
      );

      // Second claim should fail
      await expect(
        dllm.connect(server1).claimTokens(
          owner.address,
          sessionId,
          tokenCount,
          signature
        )
      ).to.be.revertedWithCustomError(dllm, "InvalidClaim");
    });

    it("Should fail with invalid signature", async function () {
      const tokenCount = 1;
      
      // Create a valid signature but for different data
      const wrongData = 999;
      const messageHash = ethers.solidityPackedKeccak256(["uint256"], [wrongData]);
      const wrongSignature = await clientWallet.signMessage(ethers.getBytes(messageHash));

      await expect(
        dllm.connect(server1).claimTokens(
          owner.address,
          sessionId,
          tokenCount,
          wrongSignature
        )
      ).to.be.revertedWithCustomError(dllm, "InvalidSignature");
    });
  });

  describe("View Functions", function () {
    it("Should return correct session details", async function () {
      const sessionId = 1;
      const maxTokens = 10;
      const addresses = [server1.address, server2.address];
      const layers = [10, 10];

      // Deposit and create session
      const depositAmount = ethers.parseEther("1000");
      await mockToken.connect(owner).approve(await dllm.getAddress(), depositAmount);
      await dllm.connect(owner).deposit(depositAmount);

      await dllm.connect(owner).createSession(
        sessionId,
        maxTokens,
        addresses,
        layers,
        clientWallet.address
      );

      const session = await dllm.getSession(owner.address, sessionId);
      
      expect(session[0]).to.equal(sessionId); // sessionId
      expect(session[1]).to.equal(owner.address); // owner
      expect(session[2]).to.deep.equal(addresses); // addresses
      expect(session[3].map(n => Number(n))).to.deep.equal(layers); // layers
      expect(session[4]).to.equal(PRICE_PER_TOKEN); // pricePerToken
      expect(session[5]).to.equal(maxTokens); // maxTokens
      expect(session[6]).to.deep.equal([]); // claimedList (empty initially)
    });
  });
});