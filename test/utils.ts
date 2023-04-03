import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
const { ethers } = require("hardhat");

export const deployMocks = async () => {
    const [owner, user] = await ethers.getSigners();

    const Factory = await ethers.getContractFactory("PancakeFactory");
    const factory = await Factory.deploy();

    const Token1 = await ethers.getContractFactory("Token1");
    const token1 = await Token1.deploy();

    const Token2 = await ethers.getContractFactory("Token2");
    const token2 = await Token2.deploy();

    const WETH = await ethers.getContractFactory("WETH");
    const weth = await WETH.deploy();

    // Give some tokens to user
    await token1
        .connect(owner)
        .transfer(await user.address, BigInt(1e2 * 1e18));
    await token2
        .connect(owner)
        .transfer(await user.address, BigInt(1e2 * 1e18));

    const Sike = await ethers.getContractFactory("Sike");
    const sike = await Sike.deploy();
    await sike.initialize(weth.address);

    const Router = await ethers.getContractFactory("PancakeRouter");
    const router = await Router.deploy(
        await factory.address,
        await weth.address
    );
    // Create pairs - 1
    await factory.createPair(token1.address, token2.address);

    let pairForToken = await factory.getPair(
        await token1.address,
        await token2.address
    );
    pairForToken = await ethers.getContractAt("PancakePair", pairForToken);

    // Create pairs - 2
    await factory.createPair(weth.address, token2.address);

    let pairForETH = await factory.getPair(
        await weth.address,
        await token2.address
    );
    pairForETH = await ethers.getContractAt("PancakePair", pairForETH);

    // Add liquidity in pool for token1-token2
    await token1
        .connect(owner)
        .approve(await router.address, BigInt(1e3 * 1e18));
    await token2
        .connect(owner)
        .approve(await router.address, BigInt(1e3 * 1e18));
    await router
        .connect(owner)
        .addLiquidity(
            token1.address,
            token2.address,
            BigInt(1e3 * 1e18),
            BigInt(1e3 * 1e18),
            0,
            0,
            owner.address,
            BigInt(1e18)
        );

    // Add liquidity in pool for WETH-token2
    await weth.connect(owner).deposit({ value: BigInt(1e3 * 1e18) });

    await weth.connect(owner).approve(await router.address, BigInt(1e3 * 1e18));
    await token2
        .connect(owner)
        .approve(await router.address, BigInt(1e3 * 1e18));

    await router
        .connect(owner)
        .addLiquidity(
            weth.address,
            token2.address,
            BigInt(1e3 * 1e18),
            BigInt(1e3 * 1e18),
            0,
            0,
            owner.address,
            BigInt(1e18)
        );

    return {
        factory,
        router,
        pairForETH,
        pairForToken,
        weth,
        sike,
        token1,
        token2,
        owner,
        user,
    };
};
