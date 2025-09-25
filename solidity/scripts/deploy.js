const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Account balance:", (await ethers.provider.getBalance(deployer.address)).toString());

  // Deploy MockToken for testing
  const MockToken = await ethers.getContractFactory("MockToken");
  const mockToken = await MockToken.deploy("DLLM Token", "DLLM", 1000000);
  await mockToken.waitForDeployment();
  
  console.log("MockToken deployed to:", await mockToken.getAddress());

  // Deploy DLLM contract
  const DLLM = await ethers.getContractFactory("DLLM");
  const dllm = await DLLM.deploy(await mockToken.getAddress());
  await dllm.waitForDeployment();
  
  console.log("DLLM deployed to:", await dllm.getAddress());

  // Save deployment info
  const deploymentInfo = {
    network: hre.network.name,
    mockToken: await mockToken.getAddress(),
    dllm: await dllm.getAddress(),
    deployer: deployer.address,
    timestamp: new Date().toISOString()
  };

  console.log("\n=== Deployment Summary ===");
  console.log(JSON.stringify(deploymentInfo, null, 2));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });