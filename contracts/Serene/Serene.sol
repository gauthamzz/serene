//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import { FlashLoanReceiverBase } from "../FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20, IWETH } from "../Interfaces.sol";
import { SafeMath } from "../Libraries.sol";

contract Serene is FlashLoanReceiverBase {
    using SafeMath for uint256;

    address public collector = 0x2b02AAd6f1694E7D9c934B7b3Ec444541286cF0f;

    constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) {}

    function getWethAddress() public pure returns (address) {
        return 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // Kovan WETH
    }

    function getEthAddress() public pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    }

    function getUniRouter() public pure returns (address) {
        return 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    )
        external
        override
        returns (bool)
    {
        for (uint i = 0; i < assets.length; i++) {
            uint amountOwing = amounts[i].add(premiums[i]);

            executeLeverage(assets[i], amountOwing, amounts[i], params);

            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function leverage(
        address debtAsset,
        address targetAsset,
        uint256 amount,
        uint256 flashAmount,
        uint256 borrowAmount
    ) external payable {
        address _targetAddress = targetAsset;
        
        if (targetAsset == getEthAddress()) {
            require(msg.value == amount, "Serene::msg-value-mismatch");

            _targetAddress = getWethAddress();

            IWETH(_targetAddress).deposit{value: amount}();
        } else {
            IERC20(targetAsset).transferFrom(msg.sender, address(this), amount);
        }

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = _targetAddress;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = abi.encode(debtAsset, borrowAmount, amount);
        uint16 referralCode = 0;

        LENDING_POOL.flashLoan(
            receiverAddress,
            assets,
            amounts,
            modes,
            onBehalfOf,
            params,
            referralCode
        );
    }

    function aaveDeposit(IERC20 token, uint256 amount) internal {
        token.approve(address(LENDING_POOL), amount);

        LENDING_POOL.deposit(address(token), amount, msg.sender, 0);
    }

    function aaveBorrow(IERC20 token, uint256 amount) internal {
        LENDING_POOL.borrow(address(token), amount, 2, 0, msg.sender);
    }

    function swap(IERC20 fromToken, IERC20 toToken, uint256 amount, uint256 minAmount) internal returns (uint256) {
        IUniswapV2Router02 uni = IUniswapV2Router02(getUniRouter());

        address[] memory path;

        if (address(fromToken) == getWethAddress() || address(toToken) == getWethAddress()) {
            path = new address[](2);
            path[0] = address(fromToken);
            path[1] = address(toToken);
        } else {
            path = new address[](3);
            path[0] = address(fromToken);
            path[1] = getWethAddress();
            path[2] = address(toToken);
        }

        fromToken.approve(address(uni), amount);

        uint256[] memory outAmounts = uni.swapExactTokensForTokens(
            amount,
            minAmount,
            path,
            address(this),
            block.timestamp + 10000
        );

        uint256 finalAmount = outAmounts[outAmounts.length - 1];

        return finalAmount;
    }

    function executeLeverage(
        address flashAsset,
        uint256 paybackAmount,
        uint256 flashAmount,
        bytes memory params
    ) internal {
        (address debtAsset, uint256 borrowAmount, uint256 userAmount) = abi.decode(params, (address, uint256, uint256));

        IERC20 flashToken = IERC20(flashAsset);
        IERC20 debtToken = IERC20(debtAsset);

        aaveDeposit(flashToken, flashAmount.add(userAmount));

        aaveBorrow(debtToken, borrowAmount);

        uint256 finalAmount = swap(debtToken, flashToken, borrowAmount, paybackAmount);

        if (finalAmount >= paybackAmount) {
            flashToken.transfer(collector, finalAmount.sub(paybackAmount));
        }
    }
}
