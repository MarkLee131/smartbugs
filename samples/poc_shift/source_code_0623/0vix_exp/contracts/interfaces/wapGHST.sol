// SPDX-License-Identifier: agpl-3.0
pragma solidity 0.8.13;

import {IERC4626} from "./IERC4626.sol";

/**
 * @title WrappedAToken
 * @notice Wrapper token that allows to deposit tokens on the Aave protocol and receive
 * a token which balance doesn't increase automatically, but uses an ever-increasing exchange rate.
 * @dev Complies with EIP-4626, but reverts on mint and withdraw. Only deposit and redeem are available.
 * @author Aavegotchi
 **/
interface IwapGHST is IERC4626 {

/** @param assets Number of tokens to enter the pool with in ATokens */
    function enter(uint256 assets) external ;

/** @param shares Number of tokens to redeem for in wrapped tokens */
    function leave(uint256 shares) external ;

/** @notice Deposits from underlying */
    function enterWithUnderlying(uint256 assets) external returns (uint256 shares) ;

/** @notice Withdraws to underlying */
    function leaveToUnderlying(uint256 shares) external returns (uint256 assets) ;

}