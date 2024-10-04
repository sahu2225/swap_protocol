// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/SwapProtocol.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import "@uniswap/permit2/contracts/interfaces/IPermit2.sol";

contract SwapProtocolTest is Test {
    SwapProtocol public swapProtocol;
    ISwapRouter public swapRouter;
    IPermit2 public permit2;
    IERC20 public tokenA;
    IERC20 public tokenB;

    address public user = address(1);
    uint256 public constant INITIAL_BALANCE = 1000 ether;

    function setUp() public {
        // Deploy mock contracts
        swapRouter = ISwapRouter(deployCode("MockSwapRouter.sol"));
        permit2 = IPermit2(deployCode("MockPermit2.sol"));
        tokenA = IERC20(deployCode("MockERC20.sol", abi.encode("Token A", "TKNA")));
        tokenB = IERC20(deployCode("MockERC20.sol", abi.encode("Token B", "TKNB")));

        // Deploy SwapProtocol
        swapProtocol = new SwapProtocol(swapRouter, permit2);

        // Setup initial balances
        deal(address(tokenA), user, INITIAL_BALANCE);
        deal(address(tokenB), address(swapRouter), INITIAL_BALANCE);
        deal(user, INITIAL_BALANCE);
    }

    function testSwapERC20() public {
        vm.startPrank(user);

        uint256 amountIn = 100 ether;
        uint256 minAmountOut = 90 ether;
        uint256 expectedAmountOut = 95 ether;

        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(tokenA),
            amountIn: amountIn,
            tokenOut: address(tokenB),
            minAmountOut: minAmountOut,
            permit: IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: address(tokenA),
                    amount: amountIn
                }),
                nonce: 0,
                deadline: block.timestamp + 1 hours
            }),
            signature: abi.encodePacked(bytes32(0), bytes32(0), uint8(0))
        });

        tokenA.approve(address(permit2), amountIn);

        uint256 userAmountOut = swapProtocol.swap(intent);

        assertEq(tokenA.balanceOf(user), INITIAL_BALANCE - amountIn, "Incorrect tokenA balance after swap");
        assertEq(tokenB.balanceOf(user), userAmountOut, "Incorrect tokenB balance after swap");
        assertEq(userAmountOut, expectedAmountOut, "Incorrect amount out");

        vm.stopPrank();
    }

    function testSwapETH() public {
        vm.startPrank(user);

        uint256 amountIn = 1 ether;
        uint256 minAmountOut = 1800 ether; // Assuming 1 ETH = 2000 TKNB
        uint256 expectedAmountOut = 1900 ether;

        SwapProtocol.SwapIntent memory intent = SwapProtocol.SwapIntent({
            tokenIn: address(0), // ETH
            amountIn: amountIn,
            tokenOut: address(tokenB),
            minAmountOut: minAmountOut,
            permit: IPermit2.PermitTransferFrom({
                permitted: IPermit2.TokenPermissions({
                    token: address(0),
                    amount: 0
                }),
                nonce: 0,
                deadline: 0
            }),
            signature: ""
        });

        uint256 userAmountOut = swapProtocol.swap{value: amountIn}(intent);

        assertEq(user.balance, INITIAL_BALANCE - amountIn, "Incorrect ETH balance after swap");
        assertEq(tokenB.balanceOf(user), userAmountOut, "Incorrect tokenB balance after swap");
        assertEq(userAmountOut, expectedAmountOut, "Incorrect amount out");

        vm.stopPrank();
    }
}