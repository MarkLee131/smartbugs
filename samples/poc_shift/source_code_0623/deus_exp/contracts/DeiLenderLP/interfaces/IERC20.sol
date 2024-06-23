// SPDX-License-Identifier: GPL-2.0-or-later

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function totalSupply() external view returns (uint256);
}
