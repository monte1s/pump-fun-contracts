// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Sp33dFun} from "./Sp33dFun.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {Sp33dFunToken} from "./Sp33dFunToken.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {IDexHandler} from "./interfaces/IDexHandler.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Sp33dFunPool is Initializable, ReentrancyGuardUpgradeable {
    using SafeERC20 for IERC20;
    using Address for address payable;

    uint256 public constant BPS = 10000;
    uint256 public constant FEE_BPS = 50; // 0.5% fee
    address public constant WETH =
        address(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    BondingCurve.Liquidity internal liq;
    IERC20 public token;
    Sp33dFun public factory;
    IDexHandler public dexHandler;
    address payable public feeReceiver;

    bool public locked;
    uint32 public lastUpdateTime;

    error Pool_SlippageError();
    error Pool_PoolLocked();

    event Bought(
        uint256 ethAmount,
        uint256 tokenAmount,
        uint256 reserveEth,
        uint256 reserveToken
    );
    event Sold(
        uint256 tokenAmount,
        uint256 ethAmount,
        uint256 reserveEth,
        uint256 reserveToken
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event Locked();

    enum Style {
        Moon,
        Balanced,
        Steady
    }

    constructor() {
        _disableInitializers();
    }

    modifier lockLiquidity() {
        if (locked) revert Pool_PoolLocked();
        _;
        lastUpdateTime = uint32(block.timestamp);
        if (liq.reserveEth >= liq.maxEth) _lockLiquidity();
    }

    function initialize(
        address _token,
        address _feeReceiver,
        address _dexHandler,
        bytes memory _poolParams
    ) public initializer {
        factory = Sp33dFun(payable(msg.sender));
        dexHandler = IDexHandler(_dexHandler);
        feeReceiver = payable(_feeReceiver);
        token = IERC20(_token);
        lastUpdateTime = uint32(block.timestamp);

        uint256 _tokenSupply = IERC20(_token).balanceOf(address(this));

        Style style = abi.decode(_poolParams, (Style));

        (uint256 virtualEth, uint256 maxEth) = _paramsForStyle(style);

        uint256 _inflatedTokenSupply = BondingCurve._getInflatedTokenSupply(
            _tokenSupply,
            virtualEth,
            maxEth
        );
        liq = BondingCurve.Liquidity({
            reserveToken: _inflatedTokenSupply,
            reserveEth: virtualEth,
            initialRealToken: _tokenSupply,
            initialInflatedToken: _inflatedTokenSupply,
            virtualEth: virtualEth,
            maxEth: maxEth,
            k: _inflatedTokenSupply * virtualEth
        });
    }

    function buy(
        uint256 minOut
    )
        external
        payable
        nonReentrant
        lockLiquidity
        returns (uint256 tokenAmount)
    {
        uint256 value = _takeEthFee(msg.value);
        tokenAmount = BondingCurve.getTokenOut(value, liq);
        if (tokenAmount < minOut) revert Pool_SlippageError();

        liq.reserveEth += value;
        liq.reserveToken -= tokenAmount;

        IERC20(token).safeTransfer(msg.sender, tokenAmount);

        emit Bought(msg.value, tokenAmount, liq.reserveEth, liq.reserveToken);
        emit Sync(uint112(liq.reserveEth), uint112(liq.reserveToken));
        emit Swap(msg.sender, msg.value, 0, 0, tokenAmount, msg.sender);
    }

    function buyTokenAmount(
        uint256 tokenAmount
    ) external payable nonReentrant lockLiquidity returns (uint256 ethAmount) {
        uint256 value = _takeEthFee(msg.value);
        ethAmount = BondingCurve.getEthIn(tokenAmount, liq);
        if (ethAmount > value) revert Pool_SlippageError();

        liq.reserveEth += ethAmount;
        liq.reserveToken -= tokenAmount;

        IERC20(token).safeTransfer(msg.sender, tokenAmount);
        if (ethAmount < value) {
            payable(msg.sender).sendValue(value - ethAmount);
        }

        emit Bought(ethAmount, tokenAmount, liq.reserveEth, liq.reserveToken);
        emit Sync(uint112(liq.reserveEth), uint112(liq.reserveToken));
        emit Swap(msg.sender, ethAmount, 0, 0, tokenAmount, msg.sender);
    }

    function sellTokenAmount(
        uint256 tokenAmount,
        uint256 minEth
    ) external nonReentrant lockLiquidity returns (uint256 ethAmount) {
        tokenAmount = _takeTokenFee(tokenAmount);
        ethAmount = BondingCurve.getEthOut(tokenAmount, liq);
        if (ethAmount < minEth) revert Pool_SlippageError();

        liq.reserveEth -= ethAmount;
        liq.reserveToken += tokenAmount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).sendValue(ethAmount);

        emit Sold(tokenAmount, ethAmount, liq.reserveEth, liq.reserveToken);
        emit Sync(uint112(liq.reserveEth), uint112(liq.reserveToken));
        emit Swap(msg.sender, 0, tokenAmount, ethAmount, 0, msg.sender);
    }

    function sellEthAmount(
        uint256 ethAmount,
        uint256 maxToken
    ) external nonReentrant lockLiquidity returns (uint256 tokenAmount) {
        tokenAmount = BondingCurve.getTokenIn(ethAmount, liq);
        // add fee
        uint256 tokenAmountPlusFee = ((tokenAmount * BPS) / (BPS - FEE_BPS)) +
            1; // 0.04% fee, rounding error
        if (tokenAmountPlusFee > maxToken) revert Pool_SlippageError();
        tokenAmount = _takeTokenFee(tokenAmountPlusFee);

        liq.reserveEth -= ethAmount;
        liq.reserveToken += tokenAmount;

        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenAmount);
        payable(msg.sender).sendValue(ethAmount);

        emit Sold(tokenAmount, ethAmount, liq.reserveEth, liq.reserveToken);
        emit Sync(uint112(liq.reserveEth), uint112(liq.reserveToken));
        emit Swap(msg.sender, 0, tokenAmount, ethAmount, 0, msg.sender);
    }

    function _lockLiquidity() internal {
        // lock liquidity
        locked = true;

        payable(address(dexHandler)).sendValue(address(this).balance);
        IERC20(address(token)).safeTransfer(
            address(dexHandler),
            token.balanceOf(address(this))
        );

        Sp33dFunToken(address(token)).onSaleEnd(); // allow adding liquidity
        dexHandler.handleLiquidity(address(token));

        emit Locked();
    }

    function getLiquidity()
        external
        view
        returns (BondingCurve.Liquidity memory)
    {
        return liq;
    }

    function _takeTokenFee(
        uint256 amount
    ) internal returns (uint256 amountWithFee) {
        uint256 fee = (amount * FEE_BPS) / BPS;
        token.safeTransferFrom(msg.sender, feeReceiver, fee);
        return amount - fee;
    }

    function _takeEthFee(
        uint256 amount
    ) internal returns (uint256 amountWithFee) {
        uint256 fee = (amount * FEE_BPS) / BPS;
        feeReceiver.sendValue(fee);
        return amount - fee;
    }

    function _paramsForStyle(
        Style style
    ) internal pure returns (uint256 virtualEth, uint256 maxEth) {
        if (style == Style.Moon) return (2500 ether, 10000 ether);
        if (style == Style.Balanced) return (7000 ether, 15000 ether);
        return (30000 ether, 50000 ether);
    }

    // uniswap compatibility
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast)
    {
        return (
            uint112(liq.reserveEth),
            uint112(liq.reserveToken),
            lastUpdateTime
        );
    }

    function token0() external pure returns (address) {
        return WETH;
    }

    function token1() external view returns (address) {
        return address(token);
    }
}
