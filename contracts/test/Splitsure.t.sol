// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/Splitsure.sol";

contract SplitsureTest is Test {
    Splitsure public splitsure;
    address public alice;
    address public bob;
    address public carol;

    function setUp() public {
        splitsure = new Splitsure();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        carol = makeAddr("carol");

        // Give each address some ether
        vm.deal(alice, 10 ether);
        vm.deal(bob, 10 ether);
        vm.deal(carol, 10 ether);
    }

    function testCreateGroup() public {
        // Arrange: Create a group with Alice, Bob, and Carol
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;

        // Act: Call the function to create a group
        splitsure.createGroup("Vacation", members);

        // Assert: Check if the group was created successfully
        (
            string memory groupName,
            address[] memory groupMembers,
            uint expenseCount
        ) = splitsure.getGroupDetails(1);
        assertEq(groupName, "Vacation");
        assertEq(groupMembers.length, 3);
        assertEq(groupMembers[0], alice);
        assertEq(expenseCount, 0);

        // Check if the group was added to each member's list of groups
        uint[] memory aliceGroups = splitsure.getUserGroups(alice);
        assertEq(aliceGroups.length, 1);
        assertEq(aliceGroups[0], 1);
    }

    function testAddExpenseToGroup() public {
        // Arrange: Create a group and add members
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("Trip", members);

        uint[] memory splitAmounts = new uint[](3);
        splitAmounts[0] = 50; // Alice owes 50
        splitAmounts[1] = 30; // Bob owes 30
        splitAmounts[2] = 20; // Carol owes 20

        // Act: Alice adds an expense
        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts);

        // Assert: Check if the expense was added correctly
        (address paidBy, uint amount, bool isSettled) = splitsure
            .getExpenseDetails(1, 1);
        assertEq(paidBy, alice);
        assertEq(amount, 100);
        assertEq(isSettled, false);

        (
            address[] memory membersReturned,
            uint[] memory splitReturned
        ) = splitsure.getExpenseSplit(1, 1);
        assertEq(splitReturned[0], 50); // Alice's split (but she doesn't owe herself)
        assertEq(splitReturned[1], 30); // Bob owes 30
        assertEq(splitReturned[2], 20); // Carol owes 20

        // Check debts and total owed amounts
        assertEq(splitsure.debts(bob, alice), 30);
        assertEq(splitsure.debts(carol, alice), 20);
        assertEq(splitsure.getTotalOwedByUser(bob), 30);
        assertEq(splitsure.getTotalOwedToUser(alice), 50); // Alice should receive 50
        assertEq(splitsure.getTotalOwedByUser(alice), 0); // Alice doesn't owe anything
    }

    function testSettleIndividualDebt() public {
        // Arrange: Create a group and add an expense
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("Dinner", members);

        uint[] memory splitAmounts = new uint[](3);
        splitAmounts[0] = 0; // Alice paid, so she doesn't owe
        splitAmounts[1] = 30; // Bob owes 30
        splitAmounts[2] = 20; // Carol owes 20

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 50}(1, 50, splitAmounts);

        // Check initial state
        assertEq(
            splitsure.debts(bob, alice),
            30,
            "Initial debt for Bob incorrect"
        );
        assertEq(
            splitsure.getTotalOwedByUser(bob),
            30,
            "Initial total owed by Bob incorrect"
        );
        assertEq(
            splitsure.getTotalOwedToUser(alice),
            50,
            "Initial total owed to Alice incorrect"
        );

        // Act: Bob settles his debt with Alice
        vm.prank(bob);
        splitsure.settleDebt{value: 30}(alice);

        // Assert: Check if Bob's debt has been settled
        assertEq(splitsure.debts(bob, alice), 0, "Bob's debt not cleared");
        assertEq(splitsure.getTotalOwedByUser(bob), 0, "Bob still owes money");
        assertEq(
            splitsure.getTotalOwedToUser(alice),
            20,
            "Alice's total owed incorrect after settlement"
        );
    }

    function testSettleGroupExpenses() public {
        // Arrange: Create a group and add multiple expenses
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("RoadTrip", members);

        uint[] memory splitAmounts1 = new uint[](3);
        splitAmounts1[0] = 50;
        splitAmounts1[1] = 30;
        splitAmounts1[2] = 20;

        uint[] memory splitAmounts2 = new uint[](3);
        splitAmounts2[0] = 60;
        splitAmounts2[1] = 25;
        splitAmounts2[2] = 15;

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts1); // Expense 1
        vm.prank(bob);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts2); // Expense 2

        // Act: Alice settles the entire group's expenses
        vm.prank(alice);
        splitsure.settleGroup{value: 50}(1); // Alice only settles her own expense

        // Assert: Check if Alice's expense has been settled
        (, , bool isSettled1) = splitsure.getExpenseDetails(1, 1);
        (, , bool isSettled2) = splitsure.getExpenseDetails(1, 2);
        assertEq(isSettled1, true);
        assertEq(isSettled2, false); // Bob's expense should not be settled
    }

    function testGetUserGroups() public {
        // Arrange: Create multiple groups and add Alice to them
        address[] memory members1 = new address[](3);
        members1[0] = alice;
        members1[1] = bob;
        members1[2] = carol;

        splitsure.createGroup("Group1", members1);
        splitsure.createGroup("Group2", members1);

        // Act: Retrieve all groups Alice is part of
        uint[] memory aliceGroups = splitsure.getUserGroups(alice);

        // Assert: Check if Alice is part of both groups
        assertEq(aliceGroups.length, 2);
        assertEq(aliceGroups[0], 1); // Group1 ID
        assertEq(aliceGroups[1], 2); // Group2 ID
    }

    function testGetTotalOwedAndOwing() public {
        // Arrange: Create a group and add expenses
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("Games", members);

        uint[] memory splitAmounts = new uint[](3);
        splitAmounts[0] = 50;
        splitAmounts[1] = 30;
        splitAmounts[2] = 20;

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts);

        // Assert: Verify total owed and owing for each user
        assertEq(splitsure.getTotalOwedByUser(bob), 30); // Bob owes 30
        assertEq(splitsure.getTotalOwedToUser(alice), 50); // Alice should receive 50
        assertEq(splitsure.getTotalOwedByUser(alice), 0); // Alice doesn't owe anything
    }

    function testGetDebtorsAndCreditors() public {
        // Arrange: Create a group and add expenses
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("Party", members);

        uint[] memory splitAmounts = new uint[](3);
        splitAmounts[0] = 0;
        splitAmounts[1] = 60;
        splitAmounts[2] = 40;

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts);

        // Act: Get debtors and creditors
        address[] memory debtors = splitsure.getDebtors(alice);
        address[] memory creditors = splitsure.getCreditors(bob);

        // Assert: Check debtors and creditors
        assertEq(debtors.length, 2);
        assertEq(debtors[0], bob);
        assertEq(debtors[1], carol);

        assertEq(creditors.length, 1);
        assertEq(creditors[0], alice);
    }

    function testReputationScoreInitialization() public {
        assertEq(
            splitsure.getReputationScore(address(this)),
            1000,
            "Contract deployer should start with max reputation score"
        );
        assertEq(
            splitsure.getReputationScore(alice),
            0,
            "New user should start with 0 reputation score"
        );
    }

    function testReputationScoreUpdate() public {
        // Arrange: Create a group and add an expense
        address[] memory members = new address[](3);
        members[0] = alice;
        members[1] = bob;
        members[2] = carol;
        splitsure.createGroup("Dinner", members);

        uint[] memory splitAmounts = new uint[](3);
        splitAmounts[0] = 0; // Alice paid, so she doesn't owe
        splitAmounts[1] = 30; // Bob owes 30
        splitAmounts[2] = 20; // Carol owes 20

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 50}(1, 50, splitAmounts);

        // Assert: Check reputation scores immediately after adding expense
        assertEq(
            splitsure.getReputationScore(alice),
            1000,
            "Alice's score should remain max"
        );
        assertEq(
            splitsure.getReputationScore(bob),
            970,
            "Bob's score should decrease by 30"
        );
        assertEq(
            splitsure.getReputationScore(carol),
            980,
            "Carol's score should decrease by 20"
        );

        // Act: Bob settles his debt
        vm.prank(bob);
        splitsure.settleDebt{value: 30}(alice);

        // Assert: Check updated reputation scores after settling debt
        assertEq(
            splitsure.getReputationScore(alice),
            1000,
            "Alice's score should still be max"
        );
        assertEq(
            splitsure.getReputationScore(bob),
            1000,
            "Bob's score should increase to max after settling debt"
        );
        assertEq(
            splitsure.getReputationScore(carol),
            980,
            "Carol's score should remain unchanged"
        );
    }

    function testReputationScoreMaximum() public {
        // Arrange: Create a group and add multiple expenses
        address[] memory members = new address[](2);
        members[0] = alice;
        members[1] = bob;
        splitsure.createGroup("MaxTest", members);

        uint[] memory splitAmounts = new uint[](2);
        splitAmounts[0] = 0;
        splitAmounts[1] = 1000;

        // Act: Add multiple expenses
        for (uint i = 0; i < 5; i++) {
            vm.prank(alice);
            splitsure.addExpenseToGroup{value: 1000}(1, 1000, splitAmounts);
            vm.warp(block.timestamp + 31 days);
        }

        // Assert: Check that Alice's score doesn't exceed the maximum
        assertEq(
            splitsure.getReputationScore(alice),
            1000,
            "Alice's score should not exceed the maximum"
        );
    }

    function testReputationScoreDecay() public {
        // Arrange: Create a group and add an expense
        address[] memory members = new address[](2);
        members[0] = alice;
        members[1] = bob;
        splitsure.createGroup("DecayTest", members);

        uint[] memory splitAmounts = new uint[](2);
        splitAmounts[0] = 0;
        splitAmounts[1] = 100;

        vm.prank(alice);
        splitsure.addExpenseToGroup{value: 100}(1, 100, splitAmounts);

        // Assert: Check initial scores
        assertEq(
            splitsure.getReputationScore(bob),
            900,
            "Bob's initial score should be 900"
        );

        // Act: Fast forward time multiple times
        for (uint i = 0; i < 10; i++) {
            vm.warp(block.timestamp + 31 days);
            splitsure.decayReputationScore(bob);
        }

        // Assert: Check that Bob's score has decayed significantly
        assertLe(
            splitsure.getReputationScore(bob),
            350,
            "Bob's score should decay significantly over time"
        );
    }
}