const { ethers } = require("hardhat");

async function main() {
  const [signer] = await ethers.getSigners();

  // Replace with actual deployed contract addresses
  const MOCK_TOKEN_ADDRESS = "0x..."; // Replace with actual address
  const DLLM_ADDRESS = "0x..."; // Replace with actual address

  const mockToken = await ethers.getContractAt("MockToken", MOCK_TOKEN_ADDRESS);
  const dllm = await ethers.getContractAt("DLLM", DLLM_ADDRESS);

  console.log("Interacting with contracts...");
  console.log("MockToken at:", MOCK_TOKEN_ADDRESS);
  console.log("DLLM at:", DLLM_ADDRESS);

  // Example: Mint tokens from faucet
  console.log("\n=== Minting tokens from faucet ===");
  const faucetAmount = ethers.parseEther("100");
  const tx1 = await mockToken.faucet(faucetAmount);
  await tx1.wait();
  console.log("Minted", ethers.formatEther(faucetAmount), "tokens");

  // Example: Approve and deposit
  console.log("\n=== Depositing to reward pool ===");
  const depositAmount = ethers.parseEther("50");
  const tx2 = await mockToken.approve(DLLM_ADDRESS, depositAmount);
  await tx2.wait();
  
  const tx3 = await dllm.deposit(depositAmount);
  await tx3.wait();
  console.log("Deposited", ethers.formatEther(depositAmount), "tokens to reward pool");

  // Check balance
  const balance = await dllm.getBalance(signer.address);
  console.log("Current reward pool balance:", ethers.formatEther(balance), "tokens");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });