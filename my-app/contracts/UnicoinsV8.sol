// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract UNCollaboration is ERC20, Ownable, ReentrancyGuard {
    using SafeMath for uint256;

    struct CollaborationTask {
        address projectManager;
        string taskDescription;
        uint256 reward;
        bool completed;
        address volunteer;
        bool authorized;
        uint256 deadline; // Add deadline field
        uint256 completionTime; // Add completion time field
    }

    struct UNicoinBalance {
        uint256 balance;
        uint256 hoursContributed;
    }

    struct StakingPosition {
        address staker;
        uint256 amount;
        uint256 startTime;
        uint256 endTime;
    }

    struct ProjectProposal {
        address proposer;
        string projectDescription;
        uint256 stakedAmount;
        bool validated;
        bool deliverablesMet;
    }

    mapping(address => UNicoinBalance) private balances;
    mapping(address => bool) public volunteers;
    mapping(address => bool) public projectManagers;
    mapping(address => StakingPosition[]) public stakingPositions;
    mapping(uint256 => ProjectProposal) public projectProposals;

    uint256 public constant TOTAL_UNICOINS = 21000000 * 10 ** 18;
    uint256 public stakingFeePercentage = 0; // Initialize staking fee to 0%

    uint256 public constant TARGET_PRICE = 1 ether; // 1 UNC = 1 ETH
    uint256 public totalDonated = 0;

    uint256 public nextProposalId = 0;

    CollaborationTask[] public tasks;

    event TaskAdded(uint256 indexed taskId, address indexed projectManager, string taskDescription, uint256 reward, address volunteer);
    event TaskCompleted(uint256 indexed taskId, address indexed volunteer, uint256 reward);
    event VolunteerAdded(address indexed volunteer);
    event ProjectManagerAdded(address indexed projectManager);
    event TokensMinted(address indexed receiver, uint256 amount);
    event StakingFeePercentageChanged(uint256 newPercentage);
    event ProjectProposalAdded(uint256 indexed proposalId, address indexed proposer, string projectDescription, uint256 stakedAmount);
    event ProjectProposalValidated(uint256 indexed proposalId, bool validated);
    event ProjectDeliverablesUpdated(uint256 indexed proposalId, bool deliverablesMet);
    event ProjectStakeForfeited(uint256 indexed proposalId, address indexed proposer, uint256 stakedAmount);

   address public organizationAccount;

    event DonationReceived(address indexed donor, uint256 amount);
    event UNicoinsMintedForProject(uint256 indexed proposalId, uint256 amount);

    constructor() ERC20("UNCollaboration Coin", "UNC") {
        _mint(msg.sender, TOTAL_UNICOINS);

        projectManagers[msg.sender] = true;
        organizationAccount = msg.sender;
        emit ProjectManagerAdded(msg.sender);
    }

    function addTask(string memory taskDescription, uint256 reward, address volunteer) public {
        require(projectManagers[msg.sender], "Only project managers can add tasks");
        uint256 taskId = tasks.length;
        tasks.push(CollaborationTask(msg.sender, taskDescription, reward, false, volunteer, false));
        emit TaskAdded(taskId, msg.sender, taskDescription, reward, volunteer);
    }

    function completeTask(uint256 taskIndex) public {
    CollaborationTask storage task= tasks[taskIndex];
    require(task.volunteer == msg.sender, "Only the assigned volunteer can complete the task");
    require(task.completed == false, "Task is already completed");
    task.completed = true;
    task.completionTime = block.timestamp; // Record completion time
    UNicoinBalance storage volunteerBalance = balances[msg.sender];
    volunteerBalance.balance = volunteerBalance.balance.add(task.reward);
    emit TaskCompleted(taskIndex, msg.sender, task.reward);
    }

    function addVolunteer(address volunteer) public {
    require(projectManagers[msg.sender], "Only project managers can add volunteers");
    volunteers[volunteer] = true;
    balances[volunteer].balance = 0;
    balances[volunteer].hoursContributed = 0;
    emit VolunteerAdded(volunteer);
    }

function addProjectManager(address projectManager) public {
    require(projectManagers[msg.sender], "Only existing project managers can add new project managers");
    projectManagers[projectManager] = true;
    emit ProjectManagerAdded(projectManager);
}

function mintTokens(address receiver, uint256 amount) public {
    require(projectManagers[msg.sender], "Only project managers can mint tokens");
    require(totalSupply().add(amount) <= TOTAL_UNICOINS, "Minting would exceed total supply");
    _mint(receiver, amount);
    emit TokensMinted(receiver, amount);
}

function setStakingFeePercentage(uint256 newPercentage) public onlyOwner {
    require(newPercentage >= 0 && newPercentage <= 100, "Invalid staking fee percentage");
    stakingFeePercentage = newPercentage;
    emit StakingFeePercentageChanged(newPercentage);
}

function proposeProject(string memory projectDescription, uint256 stakingAmount) public nonReentrant {
    require(volunteers[msg.sender], "Only volunteers can propose projects");
    require(stakingAmount > 0, "Staking amount must be greater than 0");
    require(balanceOf(msg.sender) >= stakingAmount, "Insufficient balance");

    // Transfer tokens to this contract
    transfer(address(this), stakingAmount);

    // Create the project proposal
    uint256 proposalId = nextProposalId;
    projectProposals[proposalId] = ProjectProposal(msg.sender, projectDescription, stakingAmount, false, false);
    nextProposalId++;

    emit ProjectProposalAdded(proposalId, msg.sender, projectDescription, stakingAmount);
}
function getTaskCount() public view returns (uint256) {
    return tasks.length;
}
function getCompletedTasks(address volunteer) public view returns (uint256) {
    uint256 completedTaskCount = 0;
    for (uint256 i = 0; i < tasks.length; i++) {
        CollaborationTask storage task = tasks[i];
        if (task.volunteer == volunteer && task.completed) {
            completedTaskCount++;
        }
    }
    return completedTaskCount;
}


function validateProposal(uint256 proposalId, bool isValid) public {
    require(projectManagers[msg.sender], "Only project managers can validate proposals");
    ProjectProposal storage proposal = projectProposals[proposalId];
    require(proposal.validated == false, "Proposal is already validated");

    proposal.validated = isValid;

    emit ProjectProposalValidated(proposalId, isValid);
}

    function updateProjectDeliverables(uint256 proposalId, bool isDeliverablesMet) public {
        require(projectManagers[msg.sender], "Only project managers can update project deliverables");
        ProjectProposal storage proposal = projectProposals[proposalId];
        require(proposal.validated, "Proposal must be validated first");
        proposal.deliverablesMet = isDeliverablesMet;

            if (isDeliverablesMet) {
                // Return staked tokens to proposer
                uint256 stakingReward = proposal.stakedAmount.mul(stakingFeePercentage).div(100);
                uint256 returnedAmount = proposal.stakedAmount.sub(stakingReward);
                _transfer(address(this), proposal.proposer, returnedAmount);
                _transfer(address(this), owner(), stakingReward);
            } else {
                // Transfer staked tokens to project manager
                _transfer(address(this), msg.sender, proposal.stakedAmount);
                emit ProjectStakeForfeited(proposalId, proposal.proposer, proposal.stakedAmount);
            }

        emit ProjectDeliverablesUpdated(proposalId, isDeliverablesMet);
    }
    function setOrganizationAccount(address newOrganizationAccount) public onlyOwner {
        organizationAccount = newOrganizationAccount;
    }

    function donate(uint256 amount) public {
        require(amount > 0, "Donation amount must be greater than 0");
        _mint(organizationAccount, amount);
        emit DonationReceived(msg.sender, amount);
    }

    function mintForProject(uint256 proposalId, uint256 amount) public {
        require(msg.sender == organizationAccount, "Only the organization account can mint for projects");
        ProjectProposal storage proposal = projectProposals[proposalId];
        require(proposal.validated, "Proposal must be validated first");
        require(!proposal.deliverablesMet, "Project deliverables are already met");

        _mint(proposal.proposer, amount);
        emit UNicoinsMintedForProject(proposalId, amount);
    }

    function rebase() public onlyOwner {
        uint256 currentPrice = getCurrentPrice();
        if (currentPrice > TARGET_PRICE) {
            // Reduce the supply
            uint256 excessSupply = totalSupply().mul(currentPrice.sub(TARGET_PRICE)).div(currentPrice);
            _burn(address(this), excessSupply);
        } else if (currentPrice < TARGET_PRICE) {
            // Increase the supply
            uint256 requiredSupply = totalSupply().mul(TARGET_PRICE.sub(currentPrice)).div(TARGET_PRICE);
            _mint(address(this), requiredSupply);
        }
    }

    function getCurrentPrice() public view returns (uint256) {
        return totalDonated.mul(1 ether).div(totalSupply());
    }

    function stakeTokens(uint256 amount) public {
        require(balanceOf(msg.sender) >= amount, "Insufficient balance");
        _transfer(msg.sender, address(this), amount);
        stakingPositions[msg.sender].push(StakingPosition(msg.sender, amount, block.timestamp, 0));
    }

    function unstakeTokens(uint256 positionIndex) public {
        StakingPosition storage position = stakingPositions[msg.sender][positionIndex];
        require(position.endTime == 0, "Tokens are already unstaked");
        _transfer(address(this), msg.sender, position.amount);
        position.endTime = block.timestamp;
    }

    function stakingPositionOf(address staker, uint256 positionIndex) public view returns (uint256) {
        return stakingPositions[staker][positionIndex].amount;
    }

    function getOnTimeCompletionRate(address volunteer) public view returns (uint256) {
    uint256 completedTaskCount = 0;
    uint256 onTimeTaskCount = 0;

    for (uint256 i = 0; i < tasks.length; i++) {
        CollaborationTask storage task = tasks[i];
        if (task.volunteer == volunteer && task.completed) {
            completedTaskCount++;

            if (task.completionTime <= task.deadline) {
                onTimeTaskCount++;
            }
        }
    }

    if (completedTaskCount == 0) {
        return 0;
    }

    return onTimeTaskCount.mul(100).div(completedTaskCount);
}


}
