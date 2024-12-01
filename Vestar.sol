// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract VestarToken is ERC20, Ownable, ReentrancyGuard {
    uint256 constant TOTAL_SUPPLY = 1_000_000_000 * 10**18; // Total supply of 1 billion tokens
    uint256 constant DONATION_SUPPLY = TOTAL_SUPPLY * 47 / 100; // 47% allocated for donations
    uint256 constant DEVELOPER_SUPPLY = TOTAL_SUPPLY * 53 / 100; // 53% allocated for developers

    address public feeRecipient; // Address to receive the fee
    mapping(address => uint256) public donations; // Records the donation amount for each address
    address[] public donors; // List of donor addresses
    uint256 public totalDonations; // Total donation amount
    bool public isDonationActive = true; // Whether donation is active

    event DonationReceived(address indexed donor, uint256 amount); // Donation event
    event TokensDistributed(address indexed donor, uint256 amount); // Token distribution event
    event DonationClosed(); // Donation closed event
    event FeeWithdrawn(uint256 feeAmount); // Fee withdrawal event
    event TokensMinted(address indexed to, uint256 amount); // Token minted event
    event FeeCollected(uint256 feeAmount); // Fee collection event

    // Constructor
    constructor(
        address initialOwner,
        address _feeRecipient
    ) ERC20("Vestar", "VST") Ownable(initialOwner)  {
        require(initialOwner != address(0), "Invalid initial owner address");
        require(_feeRecipient != address(0), "Invalid fee recipient address");

        feeRecipient = _feeRecipient;

        // Mint tokens
        _mint(address(this), DONATION_SUPPLY); // Mint donation tokens to the contract
        _mint(initialOwner, DEVELOPER_SUPPLY); // Mint developer tokens (53%)
    }

    // Function to accept donations without fee
    function donate() external payable nonReentrant {
        require(isDonationActive, "Donation period is over");
        require(msg.value > 0, "ETH amount must be greater than zero");

        uint256 donationAmount = msg.value; // Donation amount is not deducted for fee

        // Record donation amount
        donations[msg.sender] += donationAmount;
        totalDonations += donationAmount; // Update total donations

        // Add donor to the list if this is the first donation
        if (donations[msg.sender] == donationAmount) {
            donors.push(msg.sender);
        }

        emit DonationReceived(msg.sender, donationAmount); // Trigger donation event
    }

    // Close the donation period
    function closeDonation() external onlyOwner {
        require(isDonationActive, "Donation period already closed");
        isDonationActive = false; // Disable donation
        distributeRemainingTokens(); // Distribute remaining tokens after donation is closed
        emit DonationClosed(); // Trigger donation closed event
    }

    // Distribute remaining tokens after donation is closed
    function distributeRemainingTokens() internal {
        uint256 remainingTokens = balanceOf(address(this)); // Get remaining tokens in the contract
        require(remainingTokens > 0, "No tokens to distribute");

        // Distribute remaining tokens proportionally based on donation amounts
        for (uint256 i = 0; i < donors.length; i++) {
            address donor = donors[i];
            uint256 donationAmount = donations[donor];
            if (donationAmount > 0) {
                uint256 userShare = (donationAmount * DONATION_SUPPLY) / totalDonations;
                _transfer(address(this), donor, userShare);
                emit TokensDistributed(donor, userShare); // Trigger distribution event
            }
        }
    }

    // Withdraw all ETH from the contract to the owner's address
    function withdrawETH() external onlyOwner nonReentrant {
        uint256 balance = address(this).balance; // Get the current ETH balance of the contract
        require(balance > 0, "No ETH to withdraw");

        (bool success, ) = owner().call{value: balance}(""); // Transfer ETH to the owner
        require(success, "Withdrawal failed");

        emit FeeWithdrawn(balance); // Trigger withdrawal event
    }

    // Override transfer function to collect 1% fee
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 100; // 1% fee
        uint256 amountAfterFee = amount - fee;

        // Collect fee
        _transfer(_msgSender(), feeRecipient, fee);
        emit FeeCollected(fee); // Trigger fee collection event

        // Perform the transfer
        return super.transfer(recipient, amountAfterFee);
    }

    // Override transferFrom function to collect 1% fee
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 fee = amount / 100; // 1% fee
        uint256 amountAfterFee = amount - fee;

        // Collect fee
        _transfer(sender, feeRecipient, fee);
        emit FeeCollected(fee); // Trigger fee collection event

        // Perform the transfer
        return super.transferFrom(sender, recipient, amountAfterFee);
    }

    // Get donation amount for a specific donor
    function getDonation(address donor) external view returns (uint256) {
        return donations[donor];
    }

    // Get total donations
    function getTotalDonations() external view returns (uint256) {
        return totalDonations;
    }

    // Mint additional tokens if needed (for owner use)
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
        emit TokensMinted(to, amount);
    }
}
