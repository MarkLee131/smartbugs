// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../Strategy.sol";
import "../connectors/Chainlink.sol";
import "../connectors/Thena.sol";
import "../connectors/Wombat.sol";

import "hardhat/console.sol";

contract StrategyThenawUsdrUsdc is Strategy {
    // --- structs

    struct StrategyParams {
        address busdToken;
        address usdcToken;
        address wUsdr;
        address the;
        address pair;
        address router;
        address gauge;
        address wombatPool;
        address wombatRouter;
        address oracleBusd;
        address oracleUsdc;
    }

    // --- params

    IERC20 public busd;
    IERC20 public usdc;
    IERC20 public wUsdr;
    IERC20 public the;

    IPair public pair;
    IRouter public router;
    IGaugeV2 public gauge;
    IPool public wombatPool;

    IWombatRouter public wombatRouter;

    IPriceFeed public oracleBusd;
    IPriceFeed public oracleUsdc;

    uint256 public busdDm;
    uint256 public usdcDm;

    uint256 public wUsdrDm;
    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() public initializer {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {
       // console.log("set params");
        busd = IERC20(params.busdToken);
        usdc = IERC20(params.usdcToken);
        wUsdr = IERC20(params.wUsdr);
        the = IERC20(params.the);
        pair = IPair(params.pair);
        router = IRouter(params.router);
        gauge = IGaugeV2(params.gauge);
        wombatPool = IPool(params.wombatPool);
        wombatRouter = IWombatRouter(params.wombatRouter);
        oracleBusd = IPriceFeed(params.oracleBusd);
        oracleUsdc = IPriceFeed(params.oracleUsdc);

        busdDm = 10 ** IERC20Metadata(params.busdToken).decimals();
        usdcDm = 10 ** IERC20Metadata(params.usdcToken).decimals();
        wUsdrDm = 10 ** IERC20Metadata(params.wUsdr).decimals();

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(address _asset, uint256 _amount) internal override {
        require(_asset == address(busd), "Non-compatible token");

        // get the reserves
        (uint256 reservewUsdr, uint256 reserveUsdc, ) = pair.getReserves();
  

        // the amount of busd to start
        uint256 busdBalance = busd.balanceOf(address(this));
        // console.log("busd balance to swap for stake");
        // console.log(busdBalance);

        // swap busd for usdc    //path/pool/amt/min/to/
        uint256 usdcBalanceOracle = ChainlinkLibrary.convertTokenToToken(
            busdBalance,
            busdDm,
            usdcDm,
            oracleBusd,
            oracleUsdc
        );

        WombatLibrary.swapExactTokensForTokens(
            wombatRouter,
            address(busd),
            address(usdc),
            address(wombatPool),
            busdBalance,
            OvnMath.subBasisPoints(usdcBalanceOracle, swapSlippageBP),
            address(this)
        );
        // console.log("swapped for usdc");
        uint256 usdcQty = usdc.balanceOf(address(this));
        // console.log(usdcQty);
        // console.log(usdcDm);
    

        // get swap amounts for the pair
        uint256 wUsdrSwap = ThenaLibrary.getAmountToSwap(
            router,
            address(usdc),
            address(wUsdr),
            pair.isStable(),
            usdcQty,
            reserveUsdc,
            reservewUsdr,
            usdcDm,
            wUsdrDm
        );
        // console.log("amount wUsdr ToSwap");
        wUsdrSwap = wUsdrSwap;
        // console.log(wUsdrSwap);
        
        // uint256  = busd.balanceOf(address(this));
        // console.log("wUsdr swap");
        // console.log(address(usdc));
        // console.log(address(wUsdr));
        // console.log('selling usdc:');
        // console.log(wUsdrSwap); // in usdc decimals (18)
        // console.log('for');
        // console.log(OvnMath.subBasisPoints(wUsdrSwap/1000000000, 780));

        uint256 swap = ThenaLibrary.swap(
            router,
            address(usdc),
            address(wUsdr),
            pair.isStable(),
            wUsdrSwap,
            OvnMath.subBasisPoints((wUsdrSwap/1000000000), 780), //5.8 percent
            address(this)
        );
        // console.log("swapped for wUsdr");
        // console.log(swap);

        // usdcQty will the amount returned from selling the busd

        uint256 wUsdrQty = wUsdr.balanceOf(address(this));
        usdcQty = usdc.balanceOf(address(this));
        // console.log("amounts to deposit to LP");
        // console.log(usdcQty);
        // console.log(wUsdrQty);

        usdc.approve(address(router), usdcQty);
        wUsdr.approve(address(router), wUsdrQty);

        uint256 output = ThenaLibrary.getAmountOut(
            router,
            address(usdc),
            address(wUsdr),
            pair.isStable(),
            usdcQty
        );

        // console.log("amount out");
        // console.log(output);
        if (output > wUsdrQty) {
            // console.log("not enough wUsdr");
            output = ThenaLibrary.getAmountOut(
                router,
                address(wUsdr),
                address(usdc),
                pair.isStable(),
                wUsdrQty
            );

            router.addLiquidity(
                address(usdc),
                address(wUsdr),
                pair.isStable(),
                output,
                wUsdrQty,
                OvnMath.subBasisPoints(output, swapSlippageBP),
                OvnMath.subBasisPoints(wUsdrQty, swapSlippageBP),
                address(this),
                block.timestamp
            );
        } else {
            // console.log("deposit lp");
            // console.log(usdcQty);
            // console.log(output);
            router.addLiquidity(
                address(usdc),
                address(wUsdr),
                pair.isStable(),
                usdcQty,
                wUsdrQty,
                0,
                0,
                address(this),
                block.timestamp
            );
        }

        // deposit to gauge
        uint256 lpBalance = pair.balanceOf(address(this));
        // console.log("lpBalance");
        // console.log(lpBalance);
        pair.approve(address(gauge), lpBalance);
        gauge.deposit(lpBalance);
    }

    function _unstake(
       address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(busd), "Some token not compatible");

        // get amount LP tokens to unstake
        uint256 totalLpBalance = pair.totalSupply();
        (uint256 reserveUsdc, uint256 reservewUsdr, ) = pair.getReserves();

        uint256 lpTokensToWithdraw = ThenaLibrary.getAmountLpTokens(
            router,
            address(wUsdr),
            address(usdc),
            pair.isStable(),
            // add 1e13 to _amount for smooth withdraw
            _amount + 1e13,
            totalLpBalance,
            reservewUsdr,
            reserveUsdc,
            wUsdrDm,
            usdcDm
        );
        uint256 lpBalance = gauge.balanceOf(address(this));
        if (lpTokensToWithdraw > lpBalance) {
            lpTokensToWithdraw = lpBalance;
        }

        // withdraw from gauge
        gauge.withdraw(lpTokensToWithdraw);

        // remove liquidity
        (uint256 usdcLpBalance, uint256 wUsdrLPBalance) = router
            .quoteRemoveLiquidity(
                address(usdc),
                address(wUsdr),
                pair.isStable(),
                lpTokensToWithdraw
            );
        pair.approve(address(router), lpTokensToWithdraw);
        router.removeLiquidity(
            address(usdc),
            address(wUsdr),
            pair.isStable(),
            lpTokensToWithdraw,
            OvnMath.subBasisPoints(usdcLpBalance, swapSlippageBP),
            OvnMath.subBasisPoints(wUsdrLPBalance, swapSlippageBP),
            address(this),
            block.timestamp
        );

        // swap usdc to busd
        uint256 usdcBalance = usdc.balanceOf(address(this));
        console.log('liquidity removed wUsdr.  Balance of usdc is %s',usdcBalance);
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdc),
            address(busd),
            address(wombatPool),
            usdcBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdcBalance,
                usdcDm,
                busdDm,
                oracleUsdc,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdc),
                address(busd),
                address(wombatPool),
                usdcBalance,
                OvnMath.subBasisPoints(busdBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        // swap wUsdr to busd
        uint256 wUsdrBalance = wUsdr.balanceOf(address(this));
        console.log('liquidity removed wUsdr.  Balance of wUsdr is %s',wUsdrBalance);
        busdBalanceOut = ThenaLibrary.getAmountOut(
            router,
            address(wUsdr),
            address(usdc),
            address(busd),
            pair.isStable(),
            true, // all routes are stable
            wUsdrBalance
        );
        console.log('trying to swap for busd.  swapping %s for a minimum of %s',wUsdrBalance,OvnMath.subBasisPoints((busdBalanceOut), 180));
        if (busdBalanceOut > 0) {
          //  console.log(usdPlusBalance);
            ThenaLibrary.swap(
                router,
                address(wUsdr),
                address(usdc),
                address(busd),
                pair.isStable(),
                true,
                wUsdrBalance,
                OvnMath.subBasisPoints((busdBalanceOut), 180),
                address(this)
            );
        }
        console.log('swapped for %s',busd.balanceOf(address(this)));
        return busd.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {
        require(_asset == address(busd), "Some token not compatible");

        uint256 lpBalance = gauge.balanceOf(address(this));

        // withdraw from gauge
        gauge.withdraw(lpBalance);

        // remove liquidity
        (uint256 usdtLpBalance, uint256 busdLpBalance) = router
            .quoteRemoveLiquidity(
                address(usdc),
                address(busd),
                pair.isStable(),
                lpBalance
            );
        pair.approve(address(router), lpBalance);
        router.removeLiquidity(
            address(usdc),
            address(busd),
            pair.isStable(),
            lpBalance,
            OvnMath.subBasisPoints(usdtLpBalance, swapSlippageBP),
            OvnMath.subBasisPoints(busdLpBalance, swapSlippageBP),
            address(this),
            block.timestamp
        );

        // swap usdt to busd
        uint256 usdtBalance = usdc.balanceOf(address(this));
        uint256 busdBalanceOut = WombatLibrary.getAmountOut(
            wombatRouter,
            address(usdc),
            address(busd),
            address(wombatPool),
            usdtBalance
        );
        if (busdBalanceOut > 0) {
            uint256 busdBalanceOracle = ChainlinkLibrary.convertTokenToToken(
                usdtBalance,
                usdcDm,
                busdDm,
                oracleUsdc,
                oracleBusd
            );
            WombatLibrary.swapExactTokensForTokens(
                wombatRouter,
                address(usdc),
                address(busd),
                address(wombatPool),
                usdtBalance,
                OvnMath.subBasisPoints(busdBalanceOracle, swapSlippageBP),
                address(this)
            );
        }

        return busd.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue(true);
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue(false);
    }

    function _totalValue(bool nav) internal view returns (uint256) {
        uint256 busdBalance = busd.balanceOf(address(this));
        uint256 usdcBalance = usdc.balanceOf(address(this));
        uint256 wUsdrBalance = wUsdr.balanceOf(address(this));

        uint256 lpBalance = gauge.balanceOf(address(this));

        if (lpBalance > 0) {
            (uint256 usdcLpBalance, uint256 wUsdrLpBalance) = router
                .quoteRemoveLiquidity(
                    address(usdc),
                    address(wUsdr),
                    pair.isStable(),
                    lpBalance
                );
            // console.log('lp balance');
            // console.log(usdcLpBalance);
            // console.log(wUsdrLpBalance);

            usdcBalance += usdcLpBalance;
            wUsdrBalance += wUsdrLpBalance;
        }

        if (usdcBalance > 0) {
            // console.log('get nav of usdtBalance');
            // console.log('busd before');
            // console.log(busdBalance);
            if (nav) {
                busdBalance += ChainlinkLibrary.convertTokenToToken(
                    usdcBalance,
                    usdcDm,
                    busdDm,
                    oracleUsdc,
                    oracleBusd
                );
            } else {
                busdBalance += WombatLibrary.getAmountOut(
                    wombatRouter,
                    address(usdc),
                    address(busd),
                    address(wombatPool),
                    usdcBalance
                );
            }

            // console.log('busd after');
            // console.log(busdBalance);
        }

        if (wUsdrBalance > 0) {
          //  console.log('get nav of wUsdr Balance');
            // if (nav) {
            //     busdBalance += ChainlinkLibrary.convertTokenToToken(
            //         usdPlusBalance,
            //         usdtDm,
            //         usdPlusDm,
            //         oracleUsdt,
            //         oracleBusd
            //     );
            // } else {
            // console.log('busd before');
            // console.log(busdBalance);
            // console.log('converting wUsdr balance of');
            // console.log(wUsdrBalance);

            // convert to usdc in pool
            uint256 usdcToConvert = ThenaLibrary.getAmountOut(
                router,
                address(wUsdr),
                address(usdc),
                pair.isStable(),
                wUsdrBalance
            );

                // console.log('wUsdr as USDC');
                // console.log(usdcToConvert);
                // convert to busd
                busdBalance += WombatLibrary.getAmountOut(
                    wombatRouter,
                    address(usdc),
                    address(busd),
                    address(wombatPool),
                    usdcToConvert
                );
            
        }
        // console.log("TOTAL VALUE FROM WUSDR");
        // console.log(busdBalance);
        return busdBalance;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // console.log("claimrewards");
        // claim rewards
        uint256 lpBalance = gauge.balanceOf(address(this));
        if (lpBalance > 0) {
            gauge.getReward();
        }

        // sell rewards
        uint256 totalBusd;

        uint256 theBalance = the.balanceOf(address(this));
        // console.log('$the to sell');
        // console.log(theBalance);
        if (theBalance > 0) {
            uint256 theAmountOut = ThenaLibrary.getAmountOut(
                router,
                address(the),
                address(busd),
                false,
                theBalance
            );
            if (theAmountOut > 0) {
                totalBusd += ThenaLibrary.swap(
                    router,
                    address(the),
                    address(busd),
                    false,
                    theBalance,
                    OvnMath.subBasisPoints(theAmountOut, 10),
                    address(this)
                );
            }
        }

        if (totalBusd > 0) {
            busd.transfer(_to, totalBusd);
        }

        return totalBusd;
    }
}
