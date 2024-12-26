// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {IDexHandler} from "./interfaces/IDexHandler.sol";
import {ISolidlyRouter} from "./interfaces/ISolidlyRouter.sol";
import {ISolidlyFactory} from "./interfaces/ISolidlyFactory.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Sp33dFun} from "./Sp33dFun.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

struct Referral {
    address agent;
    uint percent;
}

interface ILocker {
    function createLockWithReferralFor(
        address _lp,
        uint _amt,
        uint _exp,
        address _to,
        Referral memory _ref
    ) external returns (address _locker, uint _ID);
}

contract EqualizerHandler is IDexHandler, Ownable {
    using SafeERC20 for IERC20;

    ISolidlyRouter constant router =
        ISolidlyRouter(0xcC6169aA1E879d3a4227536671F85afdb2d23fAD);
    ISolidlyFactory constant factory =
        ISolidlyFactory(0xDDD9845Ba0D8f38d3045f804f67A1a8B9A528FcC);
    ILocker constant locker =
        ILocker(0x4Eb733172B17F0eA9d5620aDAd62B5072eBd739b);
    address constant WETH = address(0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38);

    address public referrer;
    address public sp33dCouncil;

    mapping(address => address) public lockerForToken;
    mapping(address => uint) public lockerIdForToken;

    bool public releaseToCouncil = false;

    Sp33dFun sp33dFun;

    constructor(Sp33dFun _sp33dFun) Ownable(msg.sender) {
        sp33dFun = _sp33dFun;
        referrer = address(msg.sender);
        sp33dCouncil = address(msg.sender);
    }

    receive() external payable {}

    function handleLiquidity(address token) external {
        IERC20(token).approve(
            address(router),
            IERC20(token).balanceOf(address(this))
        );
        (, , uint amount) = router.addLiquidityETH{
            value: address(this).balance
        }(
            address(token),
            false,
            IERC20(token).balanceOf(address(this)),
            0,
            0,
            address(this), // keep the LP tokens
            block.timestamp
        );
        uint256 tokenId = sp33dFun.tokenIndexes(address(token));
        address owner = sp33dFun.getToken(tokenId).owner;

        address lp = factory.getPair(address(token), router.weth(), false);
        IERC20(lp).approve(address(locker), amount);
        Referral memory referral = Referral(referrer, 0.1 ether);

        address lockOwner = releaseToCouncil ? address(sp33dCouncil) : owner;
        uint256 releaseTime = releaseToCouncil
            ? block.timestamp + 30 days
            : type(uint256).max;

        (address _lockerAddress, uint256 _lockerId) = locker
            .createLockWithReferralFor(
                lp,
                amount,
                releaseTime,
                lockOwner,
                referral
            );
        lockerForToken[token] = _lockerAddress;
        lockerIdForToken[token] = _lockerId;
    }

    function createPair(address token) external returns (address) {
        return factory.createPair(token, WETH, false);
    }

    function setReleaseToCouncil(bool _releaseToCouncil) external onlyOwner {
        releaseToCouncil = _releaseToCouncil;
    }

    function updateSp33dFun(Sp33dFun _sp33dFun) external onlyOwner {
        sp33dFun = _sp33dFun;
    }

    function updateReferrer(address _referrer) external onlyOwner {
        referrer = _referrer;
    }

    function updateSp33dCouncil(address _sp33dCouncil) external onlyOwner {
        sp33dCouncil = _sp33dCouncil;
    }
}
