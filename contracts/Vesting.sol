// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

// OpenZeppelin dependencies
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title Vesting
 */
contract Vesting is Ownable, ReentrancyGuard {
    struct VestingPlan {
        address beneficiary;       
        // cliff time of the vesting start in seconds since the UNIX epoch
        uint256 cliff;    
        // start time of the vesting period in seconds since the UNIX epoch
        uint256 start;   
        // start time of TGE
        uint256 launch;    
        // duration of the vesting period in seconds
        uint256 duration;  
        // duration of a slice period for the vesting in seconds
        uint256 interval;   
        // whether or not the vesting is revocable
        bool canRevoke;
        // total amount of tokens to be released at the end of the vesting
        uint256 totalAmount;
        // percentage to be released at TGE
        uint256 launchPercent;
        // amount of tokens released
        uint256 released;
        // whether or not the vesting has been revoked
        bool revoked;
    }

    IERC20 public immutable token;

    bytes32[] private planIds;
    mapping(bytes32 => VestingPlan) private plans;
    uint256 private totalAmountVested;
    mapping(address => uint256) private vestingCount;

    modifier activePlan(bytes32 planId) {
        require(!plans[planId].revoked, "Plan is revoked");
        _;
    }

    constructor(address token_) Ownable(msg.sender) {
        require(token_ != address(0x0), "Invalid token address");
        token = IERC20(token_);
    }

    receive() external payable {}

    fallback() external payable {}

    function addPlan(
        address _beneficiary,
        uint256 _start,
        uint256 _cliff,
        uint256 _launch,
        uint256 _duration,
        uint256 _interval,
        uint256 _launchPercent,
        bool _canRevoke,
        uint256 _amount
    ) external onlyOwner {
        require(getAvailableAmount() >= _amount, "Insufficient tokens");
        require(_duration > 0, "Duration must be > 0");
        require(_launch > 0, "Launch must be > 0");
        require(_amount > 0, "Amount must be > 0");
        require(_interval >= 1, "Interval must be >= 1");
        require(_duration >= _cliff, "Duration must be >= cliff");

        bytes32 planId = getNextPlanId(_beneficiary);
        uint256 cliffTime = _start + _cliff;
        uint256 launchTime = _start + _launch;

        plans[planId] = VestingPlan(
            _beneficiary,
            cliffTime,
            _start,
            launchTime,
            _duration,
            _interval,
            _canRevoke,
            _amount,
            _launchPercent,
            0,
            false
        );

        totalAmountVested += _amount;
        planIds.push(planId);
        vestingCount[_beneficiary]++;
    }

    function cancelPlan(
        bytes32 planId
    ) external onlyOwner activePlan(planId) {
        VestingPlan storage plan = plans[planId];
        require(plan.canRevoke, "Plan cannot be revoked");

        uint256 releasableAmount = calculateReleasable(plan);
        if (releasableAmount > 0) {
            releaseTokens(planId, releasableAmount);
        }

        uint256 remainingAmount = plan.totalAmount - plan.released;
        totalAmountVested -= remainingAmount;
        plan.revoked = true;
    }

    function withdrawFunds(uint256 amount) external nonReentrant onlyOwner {
        require(getAvailableAmount() >= amount, "Insufficient funds");
        token.transfer(msg.sender, amount);
    }

    function releaseTokens(
        bytes32 planId,
        uint256 amount
    ) public nonReentrant activePlan(planId) {
        VestingPlan storage plan = plans[planId];
        bool isAuthorized = (msg.sender == plan.beneficiary || msg.sender == owner());
        
        require(isAuthorized, "Only beneficiary or owner can release tokens");
        uint256 releasableAmount = calculateReleasable(plan);
        require(releasableAmount >= amount, "Not enough vested tokens");

        plan.released += amount;
        totalAmountVested -= amount;
        token.transfer(payable(plan.beneficiary), amount);
    }

    function getPlanCount(address _beneficiary) external view returns (uint256) {
        return vestingCount[_beneficiary];
    }

    function getPlanId(uint256 index) external view returns (bytes32) {
        require(index < getPlanTotal(), "Index out of bounds");
        return planIds[index];
    }

    function getPlanByAddressAndIndex(
        address holder,
        uint256 index
    ) external view returns (VestingPlan memory) {
        return getPlan(computePlanId(holder, index));
    }

    function getTotalVested() external view returns (uint256) {
        return totalAmountVested;
    }

    function getPlanTotal() public view returns (uint256) {
        return planIds.length;
    }

    function getReleasableAmount(
        bytes32 planId
    )
        external
        view
        activePlan(planId)
        returns (uint256)
    {
        VestingPlan storage plan = plans[planId];
        return calculateReleasable(plan);
    }

    function getPlan(
        bytes32 planId
    ) public view returns (VestingPlan memory) {
        return plans[planId];
    }

    function getAvailableAmount() public view returns (uint256) {
        return token.balanceOf(address(this)) - totalAmountVested;
    }

    function getNextPlanId(address holder) public view returns (bytes32) {
        return computePlanId(holder, vestingCount[holder]);
    }

    function getLastPlan(address holder) external view returns (VestingPlan memory) {
        return plans[computePlanId(holder, vestingCount[holder] - 1)];
    }

    function computePlanId(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    function calculateReleasable(
        VestingPlan memory plan
    ) internal view returns (uint256) {
        uint256 currentTime = block.timestamp;

        if (currentTime < plan.cliff || currentTime < plan.launch || plan.revoked) {
            return 0;
        } else if (currentTime >= plan.start + plan.duration) {
            return plan.totalAmount - plan.released;
        } else {
            uint256 launchAmount = (plan.totalAmount * plan.launchPercent) / 100;
            uint256 remainingAmount = plan.totalAmount - launchAmount;
            uint256 elapsedTime = currentTime - plan.start;
            uint256 elapsedPeriods = elapsedTime / plan.interval;
            uint256 vestedTime = elapsedPeriods * plan.interval;

            uint256 vestedAmount = (remainingAmount * vestedTime) / plan.duration;
            return vestedAmount + launchAmount - plan.released;
        }
    }
}
