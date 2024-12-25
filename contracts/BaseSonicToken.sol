// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {ERC20BurnableUpgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import {IDexHandler} from "./interfaces/IDexHandler.sol";

contract BaseSonicToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable // not upgradeable, just cloneable
{
    address public WETH;

    enum DexType {
        UniV2,
        Solidly
    }

    error PoolingNotAllowed();
    error Bad_Supply();
    error Unauthorized();

    address public pair;
    address public sonicPool;
    bool public allowAddLiquidity;

    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory _name,
        string memory _decimals,
        address _sonicPool,
        address _dexHandler,
        uint256 _initialSupply,
        address rewardReceiver
    ) external initializer returns (uint256 reward) {
        if (
            _initialSupply < 1e18 ||
            _initialSupply > 100_000_000_000_000_000_000 ether
        ) revert Bad_Supply();

        __ERC20_init(_name, _decimals);
        sonicPool = _sonicPool;
        pair = IDexHandler(_dexHandler).createPair(address(this));
        // 1% vested to creator
        reward = _initialSupply / 100;
        _mint(rewardReceiver, reward); // creator fee
        _mint(_sonicPool, _initialSupply - reward);
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override {
        if (!allowAddLiquidity && to == pair && from != sonicPool)
            revert PoolingNotAllowed();

        super._update(from, to, value);
    }

    function onSaleEnd() external virtual {
        if (msg.sender != sonicPool) revert Unauthorized();
        allowAddLiquidity = true;
    }
}
