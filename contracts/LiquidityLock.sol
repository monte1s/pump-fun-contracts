// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LiquidityLock {
    // Define the Referral struct
    struct Referral {
        address agent; // Address of the referral agent
        uint256 amount;
    }

    // Define the Lock struct
    struct Lock {
        address token; // Address of the locked token (LP token)
        uint256 amount; // Amount of tokens locked
        uint256 releaseTime; // Time at which tokens can be withdrawn
        address owner; // Owner of the locked tokens
        bool isWithdrawn; // Status of the lock (if tokens have been withdrawn)
        Referral referral; // Referral information
    }

    // Mapping to store locks by ID
    mapping(uint256 => Lock) public locks;
    uint256 public lockCount; // Counter to track number of locks

    event TokensLocked(
        uint256 lockId,
        address indexed owner,
        address token,
        uint256 amount,
        uint256 releaseTime,
        Referral referral
    );
    event TokensWithdrawn(
        uint256 lockId,
        address indexed owner,
        uint256 amount
    );
    event ReferralPaid(address indexed agent, uint256 amount);

    // Function to create a lock with referral
    function createLockWithReferralFor(
        address _token,
        uint256 _amount,
        uint256 _releaseTime,
        address _owner,
        Referral memory _referral // Include referral parameter
    ) external {
        require(_amount > 0, "Amount must be greater than 0");
        require(
            _releaseTime > block.timestamp,
            "Release time must be in the future"
        );

        // Transfer the tokens to this contract
        IERC20(_token).transferFrom(msg.sender, address(this), _amount);

        // Create a new lock
        locks[lockCount] = Lock({
            token: _token,
            amount: _amount,
            releaseTime: _releaseTime,
            owner: _owner,
            isWithdrawn: false,
            referral: _referral // Store the referral info
        });

        emit TokensLocked(
            lockCount,
            _owner,
            _token,
            _amount,
            _releaseTime,
            _referral
        );
        lockCount++;
    }

    // Function to withdraw tokens after the lock period has ended
    function withdraw(uint256 _lockId) external payable {
        Lock storage lock = locks[_lockId];
        require(msg.sender == lock.owner, "Not the owner");
        require(block.timestamp >= lock.releaseTime, "Lock period not over");
        require(!lock.isWithdrawn, "Tokens already withdrawn");

        // Ensure the owner has sent enough Ether for the referral payment
        require(
            msg.value >= lock.referral.amount,
            "Insufficient ETH sent for referral"
        );

        // Mark the lock as withdrawn
        lock.isWithdrawn = true;

        // Transfer the locked tokens back to the owner
        IERC20(lock.token).transfer(lock.owner, lock.amount);

        // Pay the referral agent
        payable(lock.referral.agent).transfer(lock.referral.amount);
        emit ReferralPaid(lock.referral.agent, lock.referral.amount);

        emit TokensWithdrawn(_lockId, lock.owner, lock.amount);
    }
}
