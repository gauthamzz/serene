//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import { FlashLoanReceiverBase } from "../FlashLoanReceiverBase.sol";
import { ILendingPool, ILendingPoolAddressesProvider, IERC20, IWETH } from "../Interfaces.sol";
import { SafeMath } from "../Libraries.sol";

contract Serene is FlashLoanReceiverBase {
    using SafeMath for uint256;

    constructor(ILendingPoolAddressesProvider _addressProvider) FlashLoanReceiverBase(_addressProvider) {}

    function getWethAddress() public pure returns (address) {
        return 0xd0A1E359811322d97991E03f863a0C30C2cF029C; // Kovan WETH
    }

    function getEthAddress() public pure returns (address) {
        return 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
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

            executeLeverage(assets[i], amountOwing, params);

            IERC20(assets[i]).approve(address(LENDING_POOL), amountOwing);
        }

        return true;
    }

    function leverage(
        address debtAsset,
        address targetAsset,
        uint256 amount,
        uint256 flashAmount
    ) external payable {
        if (targetAsset == getEthAddress()) {
            require(msg.value == amount, "Serene::msg-value-mismatch");

            IWETH(getWethAddress()).deposit{value: amount}();
        }

        IERC20(targetAsset).transferFrom(msg.sender, address(this), amount);

        address receiverAddress = address(this);

        address[] memory assets = new address[](1);
        assets[0] = targetAsset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = flashAmount;

        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        address onBehalfOf = address(this);
        bytes memory params = abi.encode(debtAsset);
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

    function executeLeverage(
        address asset,
        uint256 amount,
        bytes memory params
    ) internal {
        // To implement
    }
}
