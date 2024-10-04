// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol";
import "@uniswap/permit2/contracts/interfaces/IPermit2.sol";

contract SwapProtocol is Ownable {
    using SafeERC20 for IERC20;

    ISwapRouter public immutable swapRouter;
    IPermit2 public immutable permit2;
    uint256 public feePercentage = 20; // 20% fee by default
    mapping(address => uint256) public fees;

    struct SwapIntent {
        address tokenIn;
        uint256 amountIn;
        address tokenOut;
        uint256 minAmountOut;
        IPermit2.PermitTransferFrom permit;
        bytes signature;
    }

    constructor(ISwapRouter _swapRouter, IPermit2 _permit2) {
        swapRouter = _swapRouter;
        permit2 = _permit2;
    }

    function swap(SwapIntent calldata intent) external payable returns (uint256 amountOut) {
        // Transfer tokens from user to this contract using Permit2
        if (intent.tokenIn != address(0)) {
            permit2.permitTransferFrom(
                intent.permit,
                IPermit2.SignatureTransferDetails({
                    to: address(this),
                    requestedAmount: intent.amountIn
                }),
                msg.sender,
                intent.signature
            );
        } else {
            require(msg.value == intent.amountIn, "Incorrect ETH amount");
        }

        // Approve Uniswap to spend tokens
        if (intent.tokenIn != address(0)) {
            TransferHelper.safeApprove(intent.tokenIn, address(swapRouter), intent.amountIn);
        }

        // Perform swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: intent.tokenIn,
            tokenOut: intent.tokenOut,
            fee: 3000, // Assume 0.3% fee pool for simplicity
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: intent.amountIn,
            amountOutMinimum: intent.minAmountOut,
            sqrtPriceLimitX96: 0
        });

        if (intent.tokenIn == address(0)) {
            amountOut = swapRouter.exactInputSingle{value: intent.amountIn}(params);
        } else {
            amountOut = swapRouter.exactInputSingle(params);
        }

        require(amountOut >= intent.minAmountOut, "Insufficient output amount");

        // Calculate and take fee
        uint256 excess = amountOut - intent.minAmountOut;
        uint256 feeAmount = (excess * feePercentage) / 100;
        uint256 userAmount = amountOut - feeAmount;

        // Transfer tokens to user
        if (intent.tokenOut == address(0)) {
            payable(msg.sender).transfer(userAmount);
        } else {
            IERC20(intent.tokenOut).safeTransfer(msg.sender, userAmount);
        }

        // Update fee balance
        fees[intent.tokenOut] += feeAmount;

        return userAmount;
    }

    function setFeePercentage(uint256 _feePercentage) external onlyOwner {
        require(_feePercentage <= 100, "Fee percentage must be <= 100");
        feePercentage = _feePercentage;
    }

    function withdrawFees(address token, uint256 amount) external onlyOwner {
        require(amount <= fees[token], "Insufficient fee balance");
        fees[token] -= amount;
        if (token == address(0)) {
            payable(owner()).transfer(amount);
        } else {
            IERC20(token).safeTransfer(owner(), amount);
        }
    }

    receive() external payable {}
}