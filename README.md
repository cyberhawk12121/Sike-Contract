# Sike 
This repository contains the code for smart contract Sike. The contract containes two things - 
1. Path finding algorithm for finding the best path from the given list of DEXs and list of mid-tokens (path tokens).
2. Swapping the trade paths that was found by the algorithm (or any swap paths).

## How it works?
1. We feed the function `getBestPath()` function with multiple data, the important ones are the token you want to swap, amount, and list of DEXs you want to go through to find the best path.
2. The function then figures out first the depth of search for swap trades, based on that it moves forward.
3. From the list of DEX it first finds out which DEX is giving the best trade results for the first level (`inputToken -> pathToken1`)
4. Then we go with multi-paths and find out the best there, best amount we got from last one to next level (`pathToken1 -> pathToken2`)
5. Then we go to the last level and find which DEX is giving the best amount output for that input amount (`pathToken2 -> outputToken`).

So, in this manner we follow the greedy approach. We don't do all the possible combinations and find out which one is giving the best results but just go by the results of the current best and move forward with that hoping we'd get the best final output.

* Time Complexity - 

Let `n` = Length of midTokens (Usually it's 5-6)

Let `m` = Length of DEXs (routers) (Usually it's 10-15)

Number of calls = (n * m) * ((n-1) * m) = (n^2 * m^2)
Also, m > n:

Time Complexity is `O(m^2)`

## Use these commands to get started
1. Install using `yarn install`
2. Compile `yarn hardhat compile`
3. Test `yarn hardhat test`
