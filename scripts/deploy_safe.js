const { ethers } = require("hardhat");

require("dotenv").config();

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with the account:", deployer.address);

  console.log("Account balance:", (await deployer.getBalance()).toString());

  const Safe = await ethers.getContractFactory("Account");
  const Registry = await ethers.getContractFactory("SafeFactory");
  const safe = await Safe.deploy();
  const registry = await Registry.deploy();

  console.log("Safe address:", safe.address);
  console.log("Registry address:", registry.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
