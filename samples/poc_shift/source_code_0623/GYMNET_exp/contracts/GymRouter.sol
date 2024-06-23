// SPDX-License-Identifier: MIT

pragma solidity 0.8.15;

import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IPancakeRouter02.sol";

/**
 * @notice Accountant contract:
 *   Stores information about user tokens rewarded
 */
contract GymRouter is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public routerAddress;
    address public WETH;
    uint256 public commission; // in 1e18

    function initialize(
        address _routerAddress,
        address _weth,
        uint256 _commission
    ) external initializer {
        
        routerAddress = _routerAddress;
        WETH = _weth;
        commission = _commission;

        __Ownable_init();
        __ReentrancyGuard_init();
    }

    receive() external payable {}

    fallback() external payable {}

    function setCommission(uint256 _commission) external onlyOwner {
        commission = _commission;
    }

    function setRouterAddress(address _routerAddress) external onlyOwner {
        routerAddress = _routerAddress;
    }

    function setWETHAddress(address _weth) external onlyOwner {
        WETH = _weth;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        uint256 tokenACommission = (amountADesired * commission) / 1e18;
        uint256 tokenBCommission = (amountBDesired * commission) / 1e18;
        IERC20Upgradeable(tokenA).safeTransferFrom(to, address(this), amountADesired);
        IERC20Upgradeable(tokenB).safeTransferFrom(to, address(this), amountBDesired);
        IERC20Upgradeable(tokenA).safeIncreaseAllowance(routerAddress, amountADesired - tokenACommission);
        IERC20Upgradeable(tokenB).safeIncreaseAllowance(routerAddress, amountBDesired - tokenBCommission);
        (amountA, amountB, liquidity) = IPancakeRouter02(routerAddress).addLiquidity(
            tokenA,
            tokenB, 
            amountADesired - tokenACommission,
            amountBDesired - tokenBCommission,
            amountAMin,
            amountBMin,
            to,
            block.timestamp + 300
        );
    }

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity)
    {
        uint256 tokenCommission = (amountTokenDesired * commission) / 1e18;
        uint256 ethCommission = (msg.value * commission) / 1e18;
        IERC20Upgradeable(token).safeTransferFrom(to, address(this), amountTokenDesired);
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transfer failed.");
        IERC20Upgradeable(token).safeIncreaseAllowance(routerAddress, amountTokenDesired - tokenCommission);
        (amountToken, amountETH, liquidity) = IPancakeRouter02(routerAddress).addLiquidityETH{value: (msg.value - ethCommission)}(
            token,
            amountTokenDesired - tokenCommission, 
            amountTokenMin,
            amountETHMin,
            to,
            block.timestamp + 300
        );
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to
    ) external returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = IPancakeRouter02(routerAddress).removeLiquidity(
            tokenA,
            tokenB, 
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            block.timestamp + 300
        );
        uint256 tokenACommission = (amountA * commission) / 1e18;
        uint256 tokenBCommission = (amountB * commission) / 1e18;
        amountA -= tokenACommission;
        amountB -= tokenBCommission;
        IERC20Upgradeable(tokenA).safeTransfer(to, amountA);
        IERC20Upgradeable(tokenB).safeTransfer(to, amountB);
    }

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to
    ) external returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = IPancakeRouter02(routerAddress).removeLiquidityETH(
            token,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + 300
        );
        uint256 tokenCommission = (amountToken * commission) / 1e18;
        uint256 ethCommission = (amountETH * commission) / 1e18;
        amountToken -= tokenCommission;
        amountETH -= ethCommission;
        IERC20Upgradeable(token).safeTransfer(to, amountToken);
        payable(to).transfer(amountETH);
    }

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB) {
        (amountA, amountB) = IPancakeRouter02(routerAddress).removeLiquidityWithPermit(
            tokenA,
            tokenB, 
            liquidity,
            amountAMin,
            amountBMin,
            address(this),
            block.timestamp + 300,
            approveMax,
            v,
            r,
            s
        );
        uint256 tokenACommission = (amountA * commission) / 1e18;
        uint256 tokenBCommission = (amountB * commission) / 1e18;
        amountA -= tokenACommission;
        amountB -= tokenBCommission;
        IERC20Upgradeable(tokenA).safeTransfer(to, amountA);
        IERC20Upgradeable(tokenB).safeTransfer(to, amountB);
    }

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH) {
        (amountToken, amountETH) = IPancakeRouter02(routerAddress).removeLiquidityWithPermit(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            block.timestamp + 300,
            approveMax,
            v,
            r,
            s
        );
        uint256 tokenCommission = (amountToken * commission) / 1e18;
        uint256 ethCommission = (amountETH * commission) / 1e18;
        amountToken -= tokenCommission;
        amountETH -= ethCommission;
        IERC20Upgradeable(token).safeTransfer(to, amountToken);
        payable(to).transfer(amountETH);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external returns (uint256[] memory amounts) {
        uint256 tokenACommission = (amountIn * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (amountIn * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        IERC20Upgradeable(path[0]).safeTransferFrom(to, address(this), amountIn);
        IERC20Upgradeable(path[0]).safeIncreaseAllowance(routerAddress, amountIn - tokenACommission);
        amounts = IPancakeRouter02(routerAddress).swapExactTokensForTokens(
            amountIn - tokenACommission,
            amountOutMin, 
            path,
            to,
            block.timestamp + 300
        );
    }

    // function swapTokensForExactTokens(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts) {
    //     uint256 tokenBCommission = (amountOut * commission) / 1e18;
    //     IERC20Upgradeable(path[0]).safeTransferFrom(to, address(this), amountOut);
    //     IERC20Upgradeable(path[1]).safeIncreaseAllowance(routerAddress, amountInMax);
    //     amounts = IPancakeRouter02(routerAddress).swapTokensForExactTokens(
    //         amountOut - tokenBCommission,
    //         amountInMax,
    //         path,
    //         to,
    //         deadline
    //     );
    // }

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable returns (uint256[] memory amounts) {
        uint256 ethCommission = (msg.value * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (msg.value * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transfer failed.");
        amounts = IPancakeRouter02(routerAddress).swapExactETHForTokens{value: msg.value - ethCommission}(
            amountOutMin,
            path,
            to,
            block.timestamp + 300
        );
    }

    // function swapTokensForExactETH(
    //     uint256 amountOut,
    //     uint256 amountInMax,
    //     address[] calldata path,
    //     address to,
    //     uint256 deadline
    // ) external returns (uint256[] memory amounts) {
    //     uint256 tokenBCommission = (amountOut * commission) / 1e18;
    //     IERC20Upgradeable(path[0]).safeTransferFrom(to, address(this), amountOut);
    //     IERC20Upgradeable(path[1]).safeIncreaseAllowance(routerAddress, amountInMax);
    //     amounts = IPancakeRouter02(routerAddress).swapTokensForExactETH(
    //         amountOut - tokenBCommission,
    //         amountInMax,
    //         path,
    //         to,
    //         deadline
    //     );
    // }

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external returns (uint256[] memory amounts) {
        uint256 tokenACommission = (amountIn * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (amountIn * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        IERC20Upgradeable(path[0]).safeTransferFrom(to, address(this), amountIn);
        IERC20Upgradeable(path[0]).safeIncreaseAllowance(routerAddress, amountIn - tokenACommission);
        amounts = IPancakeRouter02(routerAddress).swapExactTokensForETH(
            amountIn - tokenACommission,
            amountOutMin, 
            path,
            to,
            block.timestamp + 300
        );
    }

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to
    ) external payable returns (uint256[] memory amounts) {
        uint256 ethCommission = (msg.value * commission) / 1e18;
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transfer failed.");
        amounts = IPancakeRouter02(routerAddress).swapETHForExactTokens{value: (msg.value - ethCommission)}(
            amountOut,
            path,
            to,
            block.timestamp + 300
        );
        payable(to).transfer(msg.value - ethCommission - amounts[0]);
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external {
        uint256 tokenACommission = (amountIn * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (amountIn * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        IERC20Upgradeable(path[0]).safeTransferFrom(to, msg.sender, amountIn);
        IERC20Upgradeable(path[0]).safeIncreaseAllowance(routerAddress, amountIn - tokenACommission);
        IPancakeRouter02(routerAddress).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn - tokenACommission,
            amountOutMin, 
            path,
            to,
            block.timestamp + 300
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external payable {
        uint256 ethCommission = (msg.value * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (msg.value * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        (bool success, ) = address(this).call{value: msg.value}("");
        require(success, "Transfer failed.");
        IPancakeRouter02(routerAddress).swapExactETHForTokensSupportingFeeOnTransferTokens{value: msg.value - ethCommission}(
            amountOutMin,
            path,
            to,
            block.timestamp + 300
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to
    ) external {
        uint256 tokenACommission = (amountIn * commission) / 1e18;
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        require(amountOutMin >= (amountIn * outAmount * 90) / 1e20, "GymRouter: Must be greater than 90% of out amount");
        IERC20Upgradeable(path[0]).safeTransferFrom(to, address(this), amountIn);
        IERC20Upgradeable(path[0]).safeIncreaseAllowance(routerAddress, amountIn - tokenACommission);
        IPancakeRouter02(routerAddress).swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountIn - tokenACommission,
            amountOutMin, 
            path,
            to,
            block.timestamp + 300
        );
    }

    function exactAmountOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns(uint256){
        uint256 outAmount = IPancakeRouter02(routerAddress).getAmountsOut(1e18, path)[1];
        return amountIn * outAmount / 1e18;
    }

    function withdrawETH(uint256 _amt, address _to) external onlyOwner {
        uint256 amount = address(this).balance > _amt ? _amt : address(this).balance;
        payable(_to).transfer(amount);
    }

    function withdrawStuckAmt(address _token, uint256 _amt) external onlyOwner {
        IERC20Upgradeable(_token).transfer(owner(), _amt);
    }
}
