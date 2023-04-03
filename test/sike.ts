import { expect } from "chai";
import { loadFixture } from "@nomicfoundation/hardhat-network-helpers";
import { expectRevert } from "@openzeppelin/test-helpers";
const { ethers } = require("hardhat");

import { deployMocks } from "./utils";

describe("Test Aggregator", () => {
    // Test 1: Do a normal swap between token1 and token2
    it("Successful: Test swap", async () => {
        const {
            factory,
            router,
            pairForToken,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            false,
            false,
            true,
            BigInt(1e16),
            0,
            BigInt(1e18),
            [await token1.address, await token2.address],
            user.address,
        ];

        await token1.connect(user).approve(await router.address, BigInt(1e16));

        await token1
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e16));

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, { value: 0 });
    });

    // Test 2: Do multiple swaps passing an array in the function
    it("Successful: Do token-to-token swap with supporting fee", async () => {
        const {
            factory,
            router,
            pairForToken,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            false,
            true,
            true,
            BigInt(1e16),
            0,
            BigInt(1e18),
            [await token1.address, await token2.address],
            user.address,
        ];

        await token1.connect(user).approve(await router.address, BigInt(1e16));

        await token1
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e16));

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, { value: 0 });
    });

    it("Successful: Do Balance Check token-to-token swap with supporting fee", async () => {
        const {
            factory,
            router,
            pairForToken,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            false,
            true,
            true,
            BigInt(1e16),
            0,
            BigInt(1e18),
            [await token1.address, await token2.address],
            user.address,
        ];

        await token1.connect(user).approve(await router.address, BigInt(1e16));

        await token1
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e16));

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, { value: 0 });
    });

    it("Successful: Does ETH-to-Token swap supporting fee", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            true,
            true,
            true,
            BigInt(1e16),
            0,
            BigInt(1e18),
            [await weth.address, await token2.address],
            user.address,
        ];

        await weth.connect(user).approve(await router.address, BigInt(1e16));

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, {
                value: BigInt(1e16),
            });
    });

    it("Successful: Does ETH-to-Token swap NOT supporting fee with input_exact==true", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            true,
            false,
            true,
            BigInt(1e16),
            0,
            BigInt(1e18),
            [await weth.address, await token2.address],
            user.address,
        ];

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, {
                value: BigInt(1e16),
            });
    });

    it("Successful: Does ETH-to-Token swap NOT supporting fee with input_exact== false", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            true,
            false,
            false,
            BigInt(1e17),
            BigInt(1e10),
            BigInt(1e18),
            [await weth.address, await token2.address],
            user.address,
        ];

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, {
                value: BigInt(1e17),
            });
    });

    it("successful: Does ETH-to-Token1-to-token2 multi path swap with input_exact== false", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let swapParams = [
            await router.address,
            true,
            false,
            false,
            BigInt(1e16),
            BigInt(1e10),
            BigInt(1e18),
            [await weth.address, await token2.address, await token1.address],
            user.address,
        ];

        await weth.connect(user).approve(await router.address, BigInt(1e16));
        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, {
                value: BigInt(1e16),
            });
    });

    it("Successful: Does token1-to-Token2-to-ETH multi path swap with input_exact== true", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let path = [
            await token1.address,
            await token2.address,
            await weth.address,
        ];
        let amountOut = await router.getAmountsOut(BigInt(1e14), path);

        let swapParams = [
            await router.address,
            false,
            false,
            true,
            BigInt(1e14),
            0,
            amountOut[2],
            path,
            user.address,
        ];

        await token1
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e16));

        await supremeSwap
            .connect(user)
            .singleSwap(swapParams, await user.address, { value: 0 });
    });

    it("Fail: Does token1-to-ETH Pair not Exist", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let path = [await token1.address, await weth.address];

        let swapParams = [
            await router.address,
            true,
            false,
            false,
            BigInt(1e14),
            0,
            BigInt(1e14),
            path,
            user.address,
        ];

        await token1
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e16));

        await expectRevert.unspecified(
            supremeSwap
                .connect(user)
                .singleSwap(swapParams, await user.address, { value: 0 })
        );
    });

    it("Fail: Does token2-to-ETH insufficient Amount", async () => {
        const {
            factory,
            router,
            pairForETH,
            supremeSwap,
            token1,
            token2,
            owner,
            user,
            weth,
        } = await loadFixture(deployMocks);

        let path = [await token2.address, await weth.address];

        let swapParams = [
            await router.address,
            true,
            false,
            false,
            BigInt(1e19),
            BigInt(1e17),
            BigInt(1e19),
            path,
            owner.address,
        ];

        await token2
            .connect(user)
            .approve(await supremeSwap.address, BigInt(1e19));
        let balancebefore = await token2.balanceOf(await user.address);
        await token2.connect(user).transfer(await owner.address, balancebefore);
        let balanceafter = await token2.balanceOf(await user.address);

        await expectRevert.unspecified(
            supremeSwap
                .connect(user)
                .singleSwap(swapParams, await user.address, { value: 0 })
        ); // TransferHelper: TRANSFER_FROM_FAILED
    });

    // Test 3: Fails - When data that is passed is incorrect =========== ADD MULTIPLE TESTS ============
    it("Fails: Do multiple swap", async () => {
        const { factory, router, pairForETH, supremeSwap } = await loadFixture(
            deployMocks
        );
    });
});
