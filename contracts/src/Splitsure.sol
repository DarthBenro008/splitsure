// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Splitsure {
    // Struct to represent an expense
    struct Expense {
        address paidBy;
        uint amount;
        mapping(address => uint) splitAmount;
        bool isSettled;
    }

    // Struct to represent a group
    struct Group {
        string name;
        address[] members;
        uint expenseCount;
        mapping(uint => Expense) expenses;
    }

    // Mapping from groupId to Group struct
    mapping(uint => Group) public groups;
    uint public groupCount;

    // Mapping to keep track of individual debts
    mapping(address => mapping(address => uint)) public debts;

    // Mapping to store total amount owed and owing by each user
    mapping(address => uint) public totalOwedByUser;
    mapping(address => uint) public totalOwedToUser;

    // Mapping to track groups a user is part of
    mapping(address => uint[]) public userGroups;

    // Mapping to store reputation scores
    mapping(address => uint) public reputationScores;

    // Constant for maximum reputation score
    uint constant MAX_REPUTATION_SCORE = 1000;

    // Time window for reputation score updates (e.g., 30 days)
    uint constant REPUTATION_UPDATE_WINDOW = 30 days;

    // Mapping to store last update time for each user's reputation
    mapping(address => uint) private lastReputationUpdate;

    // Events
    event GroupCreated(
        uint indexed groupId,
        string groupName,
        address[] members
    );
    event ExpenseAdded(
        uint indexed groupId,
        address indexed paidBy,
        uint amount
    );
    event DebtSettled(
        address indexed debtor,
        address indexed creditor,
        uint amount
    );
    event GroupSettled(uint indexed groupId, address indexed settledBy);

    constructor() {
        // Initialize contract owner's reputation score
        reputationScores[msg.sender] = MAX_REPUTATION_SCORE;
    }

    // Function to create a group
    function createGroup(string memory name, address[] memory members) public {
        groupCount++;
        groups[groupCount].name = name;
        groups[groupCount].members = members;

        // Add the group to each member's list of groups
        for (uint i = 0; i < members.length; i++) {
            userGroups[members[i]].push(groupCount);
            // Initialize reputation score for new users
            if (reputationScores[members[i]] == 0) {
                reputationScores[members[i]] = MAX_REPUTATION_SCORE;
            }
        }

        emit GroupCreated(groupCount, name, members);
    }

    // Function to add an expense to a group
    // The 'splitAmounts' array must have the same length as the members of the group
    // Each member's corresponding index in the array represents how much they owe for this expense
    function addExpenseToGroup(
        uint groupId,
        uint amount,
        uint[] memory splitAmounts
    ) public payable {
        Group storage group = groups[groupId];
        require(group.members.length > 0, "Group does not exist");
        require(
            splitAmounts.length == group.members.length,
            "Incorrect split amounts"
        );
        require(
            msg.value == amount,
            "Sent value must match the expense amount"
        );

        group.expenseCount++;
        Expense storage expense = group.expenses[group.expenseCount];
        expense.paidBy = msg.sender;
        expense.amount = amount;

        uint totalSplit = 0;
        // Update each member's debt
        for (uint i = 0; i < group.members.length; i++) {
            address member = group.members[i];
            expense.splitAmount[member] = splitAmounts[i];
            if (member != msg.sender) {
                debts[member][msg.sender] += splitAmounts[i];
                totalOwedByUser[member] += splitAmounts[i];
                totalOwedToUser[msg.sender] += splitAmounts[i];
                updateReputationScores(member, msg.sender, splitAmounts[i]);
            }
            decayReputationScore(member);
            totalSplit += splitAmounts[i];
        }

        require(
            totalSplit == amount,
            "Total split must equal the expense amount"
        );

        emit ExpenseAdded(groupId, msg.sender, amount);
    }

    // Function to get basic group details
    function getGroupDetails(
        uint groupId
    ) public view returns (string memory, address[] memory, uint) {
        Group storage group = groups[groupId];
        return (group.name, group.members, group.expenseCount);
    }

    // Function to get details of a specific expense in a group
    function getExpenseDetails(
        uint groupId,
        uint expenseId
    ) public view returns (address, uint, bool) {
        Group storage group = groups[groupId];
        Expense storage expense = group.expenses[expenseId];
        return (expense.paidBy, expense.amount, expense.isSettled);
    }

    // Function to get split amounts of a specific expense for each member in a group
    function getExpenseSplit(
        uint groupId,
        uint expenseId
    ) public view returns (address[] memory, uint[] memory) {
        Group storage group = groups[groupId];
        Expense storage expense = group.expenses[expenseId];

        uint memberCount = group.members.length;
        address[] memory members = new address[](memberCount);
        uint[] memory splitAmounts = new uint[](memberCount);

        for (uint i = 0; i < memberCount; i++) {
            members[i] = group.members[i];
            splitAmounts[i] = expense.splitAmount[members[i]];
        }

        return (members, splitAmounts);
    }

    // Function to settle an individual transaction between two users
    function settleDebt(address creditor) public payable {
        uint debtAmount = debts[msg.sender][creditor];
        require(debtAmount > 0, "No debt to settle");
        require(msg.value == debtAmount, "Incorrect payment amount");

        debts[msg.sender][creditor] = 0;
        totalOwedByUser[msg.sender] = totalOwedByUser[msg.sender] > debtAmount
            ? totalOwedByUser[msg.sender] - debtAmount
            : 0;
        totalOwedToUser[creditor] = totalOwedToUser[creditor] > debtAmount
            ? totalOwedToUser[creditor] - debtAmount
            : 0;

        // Update only the debtor's score
        uint debtorScore = reputationScores[msg.sender];
        if (debtorScore < MAX_REPUTATION_SCORE) {
            reputationScores[msg.sender] = (debtorScore + debtAmount) >
                MAX_REPUTATION_SCORE
                ? MAX_REPUTATION_SCORE
                : debtorScore + debtAmount;
        }

        // Decay the scores
        decayReputationScore(msg.sender);
        decayReputationScore(creditor);

        lastReputationUpdate[msg.sender] = block.timestamp;
        lastReputationUpdate[creditor] = block.timestamp;

        payable(creditor).transfer(debtAmount);
        emit DebtSettled(msg.sender, creditor, debtAmount);
    }

    // Function to settle all expenses in a group
    function settleGroup(uint groupId) public payable {
        Group storage group = groups[groupId];
        require(group.members.length > 0, "Group does not exist");

        uint totalToSettle = 0;

        for (uint i = 1; i <= group.expenseCount; i++) {
            Expense storage expense = group.expenses[i];
            if (!expense.isSettled && expense.paidBy == msg.sender) {
                for (uint j = 0; j < group.members.length; j++) {
                    address member = group.members[j];
                    uint debt = expense.splitAmount[member];
                    if (member != msg.sender) {
                        totalToSettle += debt;
                        debts[member][msg.sender] = 0;
                        totalOwedByUser[member] = totalOwedByUser[member] > debt
                            ? totalOwedByUser[member] - debt
                            : 0;
                        totalOwedToUser[msg.sender] = totalOwedToUser[
                            msg.sender
                        ] > debt
                            ? totalOwedToUser[msg.sender] - debt
                            : 0;
                        updateReputationScores(msg.sender, member, debt);
                        decayReputationScore(member);
                    }
                }
                expense.isSettled = true;
            }
        }

        decayReputationScore(msg.sender);

        require(msg.value == totalToSettle, "Incorrect payment amount");

        emit GroupSettled(groupId, msg.sender);
    }

    // Get total amount owed by a user
    function getTotalOwedByUser(address user) public view returns (uint) {
        return totalOwedByUser[user];
    }

    // Get total amount owed to a user
    function getTotalOwedToUser(address user) public view returns (uint) {
        return totalOwedToUser[user];
    }

    // Get all groups the user is part of
    function getUserGroups(address user) public view returns (uint[] memory) {
        return userGroups[user];
    }

    // Get all members who owe money to the user
    function getDebtors(
        address creditor
    ) public view returns (address[] memory) {
        uint count;
        for (uint i = 0; i < groupCount; i++) {
            Group storage group = groups[i + 1];
            for (uint j = 0; j < group.members.length; j++) {
                if (debts[group.members[j]][creditor] > 0) {
                    count++;
                }
            }
        }

        address[] memory debtors = new address[](count);
        count = 0;

        for (uint i = 0; i < groupCount; i++) {
            Group storage group = groups[i + 1];
            for (uint j = 0; j < group.members.length; j++) {
                if (debts[group.members[j]][creditor] > 0) {
                    debtors[count] = group.members[j];
                    count++;
                }
            }
        }
        return debtors;
    }

    // Get all people to whom the user owes money
    function getCreditors(
        address debtor
    ) public view returns (address[] memory) {
        uint count;
        for (uint i = 0; i < groupCount; i++) {
            Group storage group = groups[i + 1];
            for (uint j = 0; j < group.members.length; j++) {
                if (debts[debtor][group.members[j]] > 0) {
                    count++;
                }
            }
        }

        address[] memory creditors = new address[](count);
        count = 0;

        for (uint i = 0; i < groupCount; i++) {
            Group storage group = groups[i + 1];
            for (uint j = 0; j < group.members.length; j++) {
                if (debts[debtor][group.members[j]] > 0) {
                    creditors[count] = group.members[j];
                    count++;
                }
            }
        }
        return creditors;
    }

    // Function to update reputation scores
    function updateReputationScores(
        address debtor,
        address creditor,
        uint amount
    ) internal {
        uint currentTime = block.timestamp;

        // Initialize scores if they haven't been set
        if (reputationScores[debtor] == 0) {
            reputationScores[debtor] = MAX_REPUTATION_SCORE;
        }
        if (reputationScores[creditor] == 0) {
            reputationScores[creditor] = MAX_REPUTATION_SCORE;
        }

        // Update only the debtor's score
        uint debtorScore = reputationScores[debtor];
        if (debtorScore > 0) {
            reputationScores[debtor] = debtorScore > amount
                ? debtorScore - amount
                : 0;
        }

        lastReputationUpdate[debtor] = currentTime;
        lastReputationUpdate[creditor] = currentTime;
    }

    // Function to decay reputation scores
    function decayReputationScore(address user) public {
        uint currentTime = block.timestamp;
        if (
            currentTime - lastReputationUpdate[user] >= REPUTATION_UPDATE_WINDOW
        ) {
            uint userScore = reputationScores[user];
            if (userScore > 0 && userScore < MAX_REPUTATION_SCORE) {
                // Decay the score by 10% every update window
                uint decayAmount = userScore / 10;
                reputationScores[user] = userScore > decayAmount
                    ? userScore - decayAmount
                    : 0;
            }
            lastReputationUpdate[user] = currentTime;
        }
    }

    // Function to get a user's reputation score
    function getReputationScore(address user) public view returns (uint) {
        return reputationScores[user];
    }
}
