// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";

import {CERC20} from "./CERC20.sol";

/// @title Comptroller
/// @author Compound Labs and Rari Capital
/// @notice Minimal Compound/Fuse Comptroller interface.
interface Comptroller {
    /// @notice Maps underlying tokens to their equivalent cTokens in a pool.
    /// @param token The underlying token to find the equivalent cToken for.
    /// @return The equivalent cToken for the given underlying token.
    function cTokensByUnderlying(ERC20 token) external view returns (CERC20);

    /// @notice Whitelists or blacklists a user from accessing the cTokens in the pool.
    /// @param users The users to whitelist or blacklist.
    /// @param enabled Whether to whitelist or blacklist each user.
    /// @return An error code, or 0 if the update was successful.
    function _setWhitelistStatuses(address[] calldata users, bool[] calldata enabled) external returns (uint256);
}
