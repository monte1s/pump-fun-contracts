// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.13;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {PausableUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {Sp33dFunPool} from "./Sp33dFunPool.sol";
import {Sp33dFunToken} from "./Sp33dFunToken.sol";

contract Ownable {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = msg.sender;
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract Sp33dFun is Ownable, Initializable, PausableUpgradeable {
    using Address for address payable;

    struct Token {
        address instance;
        address sp33dFunPool;
        address owner;
        uint32 poolType;
        uint32 tokenType;
        uint32 dexHandler;
        string name;
        string symbol;
        uint256 maxSupply;
    }

    // templates for each pool type
    address[] public tokenImplementations;
    address[] public sp33dFunPoolImplementations;
    address[] public dexHandlers;

    Token[] internal tokens;
    mapping(address => uint256) public tokenIndexes;
    // uniswap compatibility
    mapping(address => mapping(address => address)) public getPair;
    address[] public allPairs;

    address public feeTo;
    uint256 public LAUNCH_FEE = 0.0001 ether;
    uint256 public MAX_SUPPLY = 1000000000 ether;

    error BadUpgrade();
    error UnknownPoolType();
    error InvalidParams();
    error OwnershipTransferFailed();
    error FeeMismatch();
    error UnauthorizedClaim();

    event Launched(
        address owner,
        string name,
        string symbol,
        uint256 maxSupply,
        address token,
        address pool,
        address dexHandler
    );
    event PairCreated(
        address token0,
        address token1,
        address pair,
        uint256 tokenId
    );

    constructor() {
        _disableInitializers();
    }

    receive() external payable {}

    function initialize(
        address[] memory _tokenImpls,
        address[] memory _poolImpls,
        address[] memory _dexHandlers,
        address _feeTo
    ) public onlyOwner {
        // Initialize contract
        tokenImplementations = _tokenImpls;
        sp33dFunPoolImplementations = _poolImpls;
        dexHandlers = _dexHandlers;
        feeTo = _feeTo;
    }

    // token creator functions

    function launch(
        address tokenOwner,
        string memory name,
        string memory symbol,
        bytes memory poolParams,
        address rewardReceiver,
        uint32 poolType,
        uint32 tokenType,
        uint32 dexHandler
    ) external payable whenNotPaused {
        if (msg.value != LAUNCH_FEE) revert FeeMismatch();

        address instance;
        address sp33dFunPool;
        address dexHandlerAddress = dexHandlers[dexHandler];

        {
            // avoid stack too deep
            address tokenImpl = tokenImplementations[tokenType];
            address poolImpl = sp33dFunPoolImplementations[poolType];

            if (
                tokenImpl == address(0) ||
                poolImpl == address(0) ||
                dexHandlerAddress == address(0)
            ) revert InvalidParams();

            // Launch token
            instance = Clones.clone(tokenImpl);
            sp33dFunPool = Clones.clone(poolImpl);
        }

        Sp33dFunToken(instance).initialize(
            name,
            symbol,
            sp33dFunPool,
            dexHandlerAddress,
            MAX_SUPPLY,
            rewardReceiver
        );

        tokens.push(
            Token({
                instance: instance,
                sp33dFunPool: sp33dFunPool,
                owner: tokenOwner,
                poolType: poolType,
                tokenType: tokenType,
                dexHandler: dexHandler,
                name: name,
                symbol: symbol,
                maxSupply: MAX_SUPPLY
            })
        );
        tokenIndexes[instance] = tokens.length - 1;

        address baseToken = Sp33dFunPool(sp33dFunPool).token0();

        // uniswap compatibility
        getPair[baseToken][address(instance)] = sp33dFunPool;
        getPair[address(instance)][baseToken] = sp33dFunPool;
        allPairs.push(sp33dFunPool);

        Sp33dFunPool(sp33dFunPool).initialize(
            instance,
            feeTo,
            dexHandlerAddress,
            poolParams
        );

        emit Launched(
            tokenOwner,
            name,
            symbol,
            MAX_SUPPLY,
            instance,
            sp33dFunPool,
            dexHandlerAddress
        );

        // uniswap compatibility
        emit PairCreated(
            baseToken,
            address(instance),
            sp33dFunPool,
            tokens.length - 1
        );
    }

    function launchPermissioned(
        address tokenOwner,
        address token,
        address pool
    ) external onlyOwner {
        // Launch token
        tokens.push(
            Token({
                instance: token,
                sp33dFunPool: pool,
                owner: tokenOwner,
                poolType: type(uint32).max,
                tokenType: type(uint32).max,
                dexHandler: type(uint32).max,
                name: Sp33dFunToken(token).name(),
                symbol: Sp33dFunToken(token).symbol(),
                maxSupply: Sp33dFunToken(token).totalSupply()
            })
        );

        address baseToken = Sp33dFunPool(pool).token0();

        tokenIndexes[token] = tokens.length - 1;

        // uniswap compatibility
        getPair[baseToken][token] = pool;
        getPair[token][baseToken] = pool;
        allPairs.push(pool);

        emit Launched(
            tokenOwner,
            Sp33dFunToken(token).name(),
            Sp33dFunToken(token).symbol(),
            Sp33dFunToken(token).totalSupply(),
            token,
            pool,
            address(0)
        );

        // uniswap compatibility
        emit PairCreated(baseToken, token, pool, tokens.length - 1);
    }

    function transferTokenOwnership(uint256 id, address newOwner) external {
        if (id >= tokens.length) revert OwnershipTransferFailed();
        if (tokens[id].owner != msg.sender) revert OwnershipTransferFailed();
        Token storage token = tokens[id];
        token.owner = newOwner;
    }

    // admin functions

    function setLaunchFee(uint256 _fee) external onlyOwner {
        if (_fee > 100 ether) revert("fee too high");
        LAUNCH_FEE = _fee;
    }

    function claimLaunchTaxes() external onlyOwner {
        payable(owner()).sendValue(address(this).balance);
    }

    function togglePause() external onlyOwner {
        if (paused()) _unpause();
        else _pause();
    }

    function updateMaxSupply(uint256 _maxSupply) external onlyOwner {
        MAX_SUPPLY = _maxSupply;
    }

    // view functions

    function getToken(uint256 id) external view returns (Token memory) {
        if (id >= tokens.length)
            return
                Token(address(0), address(0), address(0), 0, 0, 0, "", "", 0);
        return tokens[id];
    }

    function allPairsLength() external view returns (uint256) {
        return tokens.length;
    }

    function feeToSetter() external view returns (address) {
        return owner();
    }
}
