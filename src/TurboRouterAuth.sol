// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {TurboMaster} from "./TurboMaster.sol";
import {TurboSafe} from "./TurboSafe.sol";

import {ENSReverseRecordAuth} from "./ens/ENSReverseRecordAuth.sol";
import {IERC4626, ERC4626RouterBase, IWETH9, PeripheryPayments} from "ERC4626/ERC4626RouterBase.sol";

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";

import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {Auth, Authority} from "solmate/auth/Auth.sol";

/**
 @title a router which can perform multiple Turbo actions between Master and the Safes
 @notice routes custom users flows between actions on the master and safes.

 Extends the ERC4626RouterBase to allow for flexible combinations of actions involving ERC4626 and permit, weth, and Turbo specific actions.

 Safe Creation has functions bundled with deposit (and optionally boost) because a newly created Safe address can only be known at runtime. 
 The caller is always atomically given the owner role of a new safe.

 Authentication requires the caller to be the owner of the Safe to perform any ERC4626 method or TurboSafe requiresAuth method. 
 Assumes the Safe's authority gives permission to call these functions to the TurboRouter.
 */
contract TurboRouterAuth is ERC4626RouterBase, ENSReverseRecordAuth {
    using SafeTransferLib for ERC20;

    TurboMaster public immutable master;

    constructor (TurboMaster _master, address _owner, Authority _authority, IWETH9 weth) Auth(_owner, _authority) PeripheryPayments(weth) {
        master = _master;
    }

    modifier authenticate(address target) {
        require(msg.sender == Auth(target).owner() || Auth(target).authority().canCall(msg.sender, target, msg.sig), "NOT_AUTHED");

        _;
    }

    function createSafe(ERC20 underlying) external requiresAuth returns (TurboSafe safe) {
        (safe, ) = master.createSafe(underlying);

        safe.setOwner(msg.sender);
    }

    function createSafeAndDeposit(ERC20 underlying, address to, uint256 amount, uint256 minSharesOut) external requiresAuth returns (TurboSafe safe) {
        (safe, ) = master.createSafe(underlying);

        // approve max from router to save depositor gas in future.
        approve(underlying, address(safe), type(uint256).max);

        super.deposit(IERC4626(address(safe)), to, amount, minSharesOut);

        safe.setOwner(msg.sender);
    }

    function createSafeAndDepositAndBoost(
        ERC20 underlying, 
        address to, 
        uint256 amount, 
        uint256 minSharesOut, 
        ERC4626 boostedVault, 
        uint256 boostedFeiAmount
    ) public requiresAuth returns (TurboSafe safe) {
        (safe, ) = master.createSafe(underlying);

        // approve max from router to save depositor gas in future.
        approve(underlying, address(safe), type(uint256).max);

        super.deposit(IERC4626(address(safe)), to, amount, minSharesOut);

        safe.boost(boostedVault, boostedFeiAmount);

        safe.setOwner(msg.sender);
    }

    function createSafeAndDepositAndBoostMany(
        ERC20 underlying, 
        address to, 
        uint256 amount, 
        uint256 minSharesOut, 
        ERC4626[] calldata boostedVaults, 
        uint256[] calldata boostedFeiAmounts
    ) public requiresAuth returns (TurboSafe safe) {
        (safe, ) = master.createSafe(underlying);

        // approve max from router to save depositor gas in future.
        approve(underlying, address(safe), type(uint256).max);

        super.deposit(IERC4626(address(safe)), to, amount, minSharesOut);

        unchecked {
            require(boostedVaults.length == boostedFeiAmounts.length, "length");
            for (uint256 i = 0; i < boostedVaults.length; i++) {
                safe.boost(boostedVaults[i], boostedFeiAmounts[i]);
            }     
        }

        safe.setOwner(msg.sender);
    }

    function deposit(IERC4626 safe, address to, uint256 amount, uint256 minSharesOut) 
        public 
        payable 
        override 
        authenticate(address(safe)) 
        returns (uint256) 
    {
        return super.deposit(safe, to, amount, minSharesOut);
    }

    function mint(IERC4626 safe, address to, uint256 shares, uint256 maxAmountIn) 
        public 
        payable 
        override 
        authenticate(address(safe)) 
        returns (uint256) 
    {
        return super.mint(safe, to, shares, maxAmountIn);
    }

    function withdraw(IERC4626 safe, address to, uint256 amount, uint256 maxSharesOut) 
        public 
        payable 
        override 
        authenticate(address(safe)) 
        returns (uint256) 
    {
        return super.withdraw(safe, to, amount, maxSharesOut);
    }

    function redeem(IERC4626 safe, address to, uint256 shares, uint256 minAmountOut) 
        public 
        payable 
        override 
        authenticate(address(safe)) 
        returns (uint256) 
    {
        return super.redeem(safe, to, shares, minAmountOut);
    }

    function slurp(TurboSafe safe, ERC4626 vault) external authenticate(address(safe)) {
        safe.slurp(vault);
    }

    function boost(TurboSafe safe, ERC4626 vault, uint256 feiAmount) public authenticate(address(safe)) {
        safe.boost(vault, feiAmount);
    }

    function less(TurboSafe safe, ERC4626 vault, uint256 feiAmount) external authenticate(address(safe)) {
        safe.less(vault, feiAmount);
    }

    function lessAll(TurboSafe safe, ERC4626 vault) external authenticate(address(safe)) {
        safe.less(vault, vault.maxWithdraw(address(safe)));
    }

    function sweep(TurboSafe safe, address to, ERC20 token, uint256 amount) external authenticate(address(safe)) {
        safe.sweep(to, token, amount);
    }

    function sweepAll(TurboSafe safe, address to, ERC20 token) external authenticate(address(safe)) {
        safe.sweep(to, token, token.balanceOf(address(safe)));
    }

    function slurpAndLessAll(TurboSafe safe, ERC4626 vault) external authenticate(address(safe)) {
        safe.slurp(vault);
        safe.less(vault, vault.maxWithdraw(address(safe)));
    }
}