// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IPermit} from "./interfaces/IPermit.sol";
import {IUniswapV2Router02} from "./interfaces/IUniswapV2Router.sol";
import "./interfaces/ISupport.sol";
import {SwapParams, DEXParams, Response} from "./Types/types.sol";

/**
    @notice Sike: This contract allows users to find the best path between two tokens that would give the maximum possible
    return for a swap and does the swap as well.
    @dev The path finding algorithm can be found in the form of `view` functions and rest all are related to swapping
 */
contract Sike is OwnableUpgradeable, PausableUpgradeable {
    event Swap(address token1, address token2, uint256 amount);
    /** 
        @notice WETH address for BSC chain
    */
    address private WETH;
    /**
        @dev MAX_DEPTH represents the maximum depth we're willing to go to find the path of trade
        E.g. Input -> Token1 -> Token2 -> Output, here depth = 2 (which is the max depth we go right now) 
    */
    uint256 private MAX_DEPTH;
    /**
        @notice Total number of mid path tokens we're trying, in order to find the best path
    */
    uint256 private MAX_MIDTOKEN_LENGTH;

    /// @notice ___gap variable to avoid storage clashes
    uint256[49] private __gap;

    /**
        @notice sets the aforementioned variables
    */
    function initialize(
        uint256 _MAX_MIDTOKEN_LENGTH,
        uint256 _MAX_DEPTH,
        address _WETH
    ) external initializer {
        MAX_MIDTOKEN_LENGTH = _MAX_MIDTOKEN_LENGTH;
        MAX_DEPTH = _MAX_DEPTH;
        WETH = _WETH;
    }

    receive() external payable {}

    /**
        @notice Swap function that will allow us to swap the entire path of the token to reach a particular output (token)
        @dev A list of `SwapParams` struct are passed, each of which contains enough information to do a swap between a pair of tokens.
        The next SwapParams then does the next swap in the queue until all are complete and desired out tokens are received.
        @param _sParams A list of `SwapParams` struct
    */
    function swap(SwapParams[] memory _sParams) external payable {
        uint256 pathLength = _sParams.length;

        // Perform swap only once if array length is 1
        if (pathLength == 1) {
            _sParams[0].to = msg.sender;
            singleSwap(_sParams[0], msg.sender);
        }
        require(pathLength <= MAX_DEPTH, "Sike: Max path length exceeded");

        // Perform multiple swaps
        if (pathLength > 1) {
            uint256 beforeBalance;
            uint256 afterBalance;
            for (uint64 i = 0; i < pathLength; ) {
                beforeBalance = IERC20(_sParams[i].path[1]).balanceOf(
                    address(this)
                );
                if (i == pathLength - 1) {
                    _sParams[i].to = msg.sender;
                    singleSwap(_sParams[i], address(this));
                } else if (i == 0) {
                    _sParams[i].to = address(this);
                    singleSwap(_sParams[i], msg.sender);
                    afterBalance = IERC20(_sParams[i].path[1]).balanceOf(
                        address(this)
                    );
                    _sParams[i + 1].amountIn = afterBalance - beforeBalance;
                } else {
                    _sParams[i].to = address(this);
                    singleSwap(_sParams[i], address(this));
                    afterBalance = IERC20(_sParams[i].path[1]).balanceOf(
                        address(this)
                    );
                    _sParams[i + 1].amountIn = afterBalance - beforeBalance;
                }

                unchecked {
                    i++;
                }
            }
        }
        emit Swap(
            _sParams[0].path[0],
            _sParams[pathLength - 1].path[1],
            _sParams[0].amountIn
        );
    }

    /**
        @notice Function to do one swap at a time
        @param _params A struct containing all the necessary variables to do a swap on the given pair
        @param _to The address that will be sending the tokens to this address to swap (if required, not in case of native coin)
    */
    function singleSwap(SwapParams memory _params, address _to) public payable {
        if (_params.isETHSwap == true) {
            if (_params.path[0] != WETH) {
                // this contract approving the router contract to spend _amountIn
                IERC20(_params.path[0]).approve(
                    address(_params.router),
                    _params.amountIn
                );
            }
            swapEthAndToken(_params);
        } else {
            if (_to != address(this)) {
                uint256 beforeBalance = IERC20(_params.path[0]).balanceOf(
                    address(this)
                );
                IERC20(_params.path[0]).transferFrom(
                    _to,
                    address(this),
                    _params.amountIn
                );
                // Use the amount that got in the contract
                uint256 afterBalance = IERC20(_params.path[0]).balanceOf(
                    address(this)
                );
                // Check if the token supports fee on transfer or not
                if (!_params.supportFee) {
                    require(
                        (afterBalance - beforeBalance) == _params.amountIn,
                        "Sike: Invalid fee flag"
                    );
                } else {
                    _params.amountIn = afterBalance - beforeBalance;
                }
            }

            // this contract approving the router contract to spend _amountIn
            IERC20(_params.path[0]).approve(
                address(_params.router),
                _params.amountIn
            );
            swapTokenAndToken(_params);
        }
    }

    /**
        @notice A helper function do a swap between token and ETH
    */
    function swapEthAndToken(SwapParams memory _params) public payable {
        // Eth and token pair combinations
        if (_params.path[0] == WETH && _params.supportFee) {
            _params.router.swapExactETHForTokensSupportingFeeOnTransferTokens{
                value: _params.amountIn
            }(_params.amountOutMin, _params.path, _params.to, _params.deadline);
        } else if (
            _params.path[0] != WETH &&
            _params.supportFee == true &&
            _params.inputExact == true
        ) {
            _params.router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                _params.amountIn,
                _params.amountOutMin,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else if (
            _params.path[0] == WETH && !_params.supportFee && _params.inputExact
        ) {
            _params.router.swapExactETHForTokens{value: _params.amountIn}(
                _params.amountOutMin,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else if (
            _params.path[0] != WETH &&
            !_params.supportFee &&
            !_params.inputExact
        ) {
            _params.router.swapTokensForExactETH(
                _params.amountOutMin,
                _params.amountIn,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else if (
            _params.path[0] == WETH &&
            !_params.supportFee &&
            !_params.inputExact
        ) {
            _params.router.swapETHForExactTokens{value: _params.amountIn}(
                _params.amountOutMin,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else if (
            _params.path[0] != WETH && !_params.supportFee && _params.inputExact
        ) {
            _params.router.swapExactTokensForETH(
                _params.amountIn,
                _params.amountOutMin,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else {
            revert("Sike: Invalid Params");
        }
    }

    /**
        @notice A helper function do a swap between token and ETH
    */
    function swapTokenAndToken(SwapParams memory _params) private {
        // Token to token combinations
        if (_params.supportFee) {
            _params
                .router
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _params.amountIn,
                    _params.amountOutMin,
                    _params.path,
                    _params.to,
                    _params.deadline
                );
        } else if (!_params.supportFee && !_params.inputExact) {
            _params.router.swapTokensForExactTokens(
                _params.amountOutMin,
                _params.amountIn,
                _params.path,
                _params.to,
                _params.deadline
            );
        } else if (!_params.supportFee && _params.inputExact) {
            _params.router.swapExactTokensForTokens(
                _params.amountIn,
                _params.amountOutMin,
                _params.path,
                _params.to,
                _params.deadline
            );
        }
    }

    //                                                                         ||
    // ======================================================================= ||
    // ======================================================================= ||                                                                               //
    // =================== PATH FINDING (HELPER) FUNCTIONS ===================== ||
    //                                                                         ||

    /**
        @notice The main function which returns the data for path that the token pair should follow to get best trade output
        @dev We follow a greedy approach 
        1. Find out which DEX in the `dexList` is giving the best result for all the individual token pairs
        2. Then we swap accross all the pairs
        E.g. Input --router1--> Token1 --router2--> Token2 --router3--> Output
        Meaning swap- (Input, Token1) with router1, (Token1, Token2) with router2 and (Token2, Output) with router3 to get best result
    */
    function getBestPath(
        uint256 _amountIn,
        address _inToken,
        address _outToken,
        address[] calldata midTokens,
        DEXParams[] calldata dexList
    ) external view returns (Response memory response) {
        require(
            midTokens.length <= MAX_MIDTOKEN_LENGTH,
            "Sike: Exceeded depth list"
        );
        // TODO: require for DexList too
        (uint256 amount1, address router1) = getMaxAmount(
            dexList,
            _amountIn,
            [_inToken, _outToken]
        );
        if (response.maxAmt < amount1) {
            response.maxAmt = amount1;
            response.router[0] = router1;
        }
        uint8 len = uint8(midTokens.length);

        for (uint8 i = 0; i < len; i++) {
            if (midTokens[i] != _inToken && midTokens[i] != _outToken) {
                singleCalcHelper(
                    _amountIn,
                    _inToken,
                    _outToken,
                    midTokens[i],
                    dexList,
                    response
                );
                for (uint8 j = 1; j < len; j++) {
                    if (
                        midTokens[i] != _inToken &&
                        midTokens[i] != midTokens[j] &&
                        midTokens[j] != _outToken
                    ) {
                        multiCalcHelper(
                            _amountIn,
                            _inToken,
                            _outToken,
                            midTokens[i],
                            midTokens[j],
                            dexList,
                            response
                        );
                    }
                }
            }
        }
        return response;
    }

    function singleCalcHelper(
        uint256 _amountIn,
        address _inToken,
        address _outToken,
        address midToken,
        DEXParams[] calldata dexList,
        Response memory response
    ) private view {
        uint256 amountOut1;
        address router1;
        uint256 amountOut2;
        address router2;

        if (_amountIn > 0) {
            (amountOut1, router1) = getMaxAmount(
                dexList,
                _amountIn,
                [_inToken, midToken]
            );
        }

        if (amountOut1 > 0) {
            (amountOut2, router2) = getMaxAmount(
                dexList,
                amountOut1,
                [midToken, _outToken]
            );
        }

        if (response.maxAmt < amountOut2) {
            response.pathAddr1 = midToken;
            response.maxAmt1 = amountOut1;
            response.maxAmt = amountOut2;
            response.router[0] = router1;
            response.router[1] = router2;
        }
    }

    /*  
        TODO: Optimization - Remove the call of getMaxAmount() which finds for (inToken, midToken_i), because singleCalcHelper() is 
        already finding that.
    */
    function multiCalcHelper(
        uint256 _amountIn,
        address _inToken,
        address _outToken,
        address midTokens_i,
        address midTokens_j,
        DEXParams[] calldata dexList,
        Response memory response
    ) private view {
        uint256[3] memory amountOut;
        address[3] memory router;

        if (_amountIn > 0) {
            (amountOut[0], router[0]) = getMaxAmount(
                dexList,
                _amountIn,
                [_inToken, midTokens_i]
            );
        }

        if (amountOut[0] > 0) {
            (amountOut[1], router[1]) = getMaxAmount(
                dexList,
                amountOut[0],
                [midTokens_i, midTokens_j]
            );
        }
        if (amountOut[1] > 0) {
            (amountOut[2], router[2]) = getMaxAmount(
                dexList,
                amountOut[1],
                [midTokens_j, _outToken]
            );
        }

        if (response.maxAmt < amountOut[2]) {
            response.pathAddr1 = midTokens_i;
            response.pathAddr2 = midTokens_j;
            response.maxAmt1 = amountOut[0];
            response.maxAmt2 = amountOut[1];
            response.maxAmt = amountOut[2];
            response.router[0] = router[0];
            response.router[1] = router[1];
            response.router[2] = router[2];
        }
    }

    /**
        @notice A helper function find which DEX from the `dexList`would give the best output amount for the token pair
    */
    function getMaxAmount(
        DEXParams[] calldata _param,
        uint256 _amountIn,
        address[2] memory path
    ) public view returns (uint256 maxAmount, address maxRouter) {
        address[] memory path_ = new address[](2);
        path_[0] = (path[0]);
        path_[1] = (path[1]);
        for (uint8 i = 0; i < _param.length; ) {
            // step1 : get pair
            address pair = _param[i].factory.getPair(path[0], path_[1]);

            if (pair != address(0)) {
                // step2 : get reserve
                (uint112 reserve0, uint112 reserve1, ) = IPair(pair)
                    .getReserves();

                //step3 : get token0 for reserve compare
                address token0 = IPair(pair).token0();

                //step4 : reserve compare
                uint256 reserve = (token0 == path_[0])
                    ? uint256(reserve0)
                    : uint256(reserve1);
                // if we have amountIn > reserves then do:
                if (reserve > _amountIn) {
                    uint256 amountOut = (
                        _param[i].router.getAmountsOut(_amountIn, path_)
                    )[1];

                    if (amountOut > maxAmount) {
                        maxAmount = amountOut;
                        maxRouter = address(_param[i].router);
                    }
                }
            }
            unchecked {
                i++;
            }
        }

        return (maxAmount, maxRouter);
    }
}
