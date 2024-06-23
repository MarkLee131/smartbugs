// Be name Khoda
// Bime Abolfazl
// SPDX-License-Identifier: MIT

// =================================================================================================================
//  _|_|_|    _|_|_|_|  _|    _|    _|_|_|      _|_|_|_|  _|                                                       |
//  _|    _|  _|        _|    _|  _|            _|            _|_|_|      _|_|_|  _|_|_|      _|_|_|    _|_|       |
//  _|    _|  _|_|_|    _|    _|    _|_|        _|_|_|    _|  _|    _|  _|    _|  _|    _|  _|        _|_|_|_|     |
//  _|    _|  _|        _|    _|        _|      _|        _|  _|    _|  _|    _|  _|    _|  _|        _|           |
//  _|_|_|    _|_|_|_|    _|_|    _|_|_|        _|        _|  _|    _|    _|_|_|  _|    _|    _|_|_|    _|_|_|     |
// =================================================================================================================
// ==================== Oracle ===================
// ==============================================
// DEUS Finance: https://github.com/deusfinance

// Primary Author(s)
// Mmd: https://github.com/mmd-mostafaee

pragma solidity 0.8.12;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IMuon.sol";
import "./interfaces/IBaseV1Pair.sol";

/// @title Oracle of DeiLenderLP
/// @author DEUS Finance
/// @notice to provide LP price for DeiLenderLP
contract Oracle is AccessControl {
    IERC20 public dei;
    IERC20 public usdc;
    IERC20 public pair;

    uint256 price; // usdc

    IMuonV02 public muon;
    uint32 public appId;
    uint256 public minimumRequiredSignatures;
    uint256 public expireTime;
    uint256 public threshold;

    bytes32 public constant SETTER_ROLE = keccak256("SETTER_ROLE");

    modifier isSetter() {
        require(hasRole(SETTER_ROLE, msg.sender), "Caller is not setter");
        _;
    }

    constructor(
        IERC20 dei_,
        IERC20 usdc_,
        IERC20 pair_,
        IMuonV02 muon_,
        uint32 appId_,
        uint256 minimumRequiredSignatures_,
        uint256 expireTime_,
        uint256 threshold_,
        address admin,
        address setter
    ) {
        dei = dei_;
        usdc = usdc_;
        pair = pair_;
        muon = muon_;
        appId = appId_;
        expireTime = expireTime_;
        threshold = threshold_;

        minimumRequiredSignatures = minimumRequiredSignatures_;

        _setupRole(DEFAULT_ADMIN_ROLE, admin);
        _setupRole(SETTER_ROLE, setter);
    }

    function setMuon(IMuonV02 muon_) external isSetter {
        muon = muon_;
    }

    function setAppId(uint32 appId_) external isSetter {
        appId = appId_;
    }

    function setMinimumRequiredSignatures(uint256 minimumRequiredSignatures_)
        external
        isSetter
    {
        minimumRequiredSignatures = minimumRequiredSignatures_;
    }

    function setExpireTime(uint256 expireTime_) external isSetter {
        expireTime = expireTime_;
    }

    function setThreshold(uint256 threshold_) external isSetter {
        threshold = threshold_;
    }

    /// @notice returns on chain LP price
    function getOnChainPrice() public view returns (uint256) {
        return
            ((dei.balanceOf(address(pair)) * IBaseV1Pair(address(pair)).getAmountOut(1e18, address(dei)) * 1e12 / 1e18) + (usdc.balanceOf(address(pair)) * 1e12)) * 1e18 / pair.totalSupply();
    }

    /// @notice returns
    function getPrice(
        uint256 price,
        uint256 timestamp,
        bytes calldata reqId,
        SchnorrSign[] calldata sigs
    ) public returns (uint256) {
        require(
            timestamp + expireTime >= block.timestamp,
            "ORACLE: SIGNATURE_EXPIRED"
        );

        uint256 onChainPrice = getOnChainPrice();
        uint256 diff = onChainPrice < price ? onChainPrice * 1e18 / price : price * 1e18 / onChainPrice;
        require(
           1e18 - diff < threshold 
            ,"ORACLE: PRICE_GAP"
        );

        address[] memory pairs1 = new address[](1);
        pairs1[0] = address(pair);
        bytes32 hash = keccak256(
            abi.encodePacked(
                appId,
                address(pair),
                new address[](0),
                pairs1,
                price,
                timestamp
            )
        );

        require(
            muon.verify(reqId, uint256(hash), sigs),
            "ORACLE: UNVERIFIED_SIGNATURES"
        );

        return price;
    }
}
