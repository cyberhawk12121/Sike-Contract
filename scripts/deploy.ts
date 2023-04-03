const { ethers, upgrades } = require("hardhat");
require("@openzeppelin/hardhat-upgrades");

// Define the implementation contract

// Set up the wallet
async function main() {

    const WETH = "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c";
    const [deployer] = await ethers.getSigners();
    console.log("deployer address ", deployer.address);

    const SikeImplementation = await ethers.getContractFactory(
        "Sike"
    );

    // Deploy the upgradeable proxy
    const proxy = await upgrades.deployProxy(
        SikeImplementation,
        [10, 3, WETH]
    );

    console.log("Proxy deployed to:", proxy.address);
    console.log(
        "Verify using this command: npx hardhat verify --network bsc_mainnet",
        await proxy.address
    );

    // Upgrade the proxy with the implementation contract
}

// Execute the script
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
