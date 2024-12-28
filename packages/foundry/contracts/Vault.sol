// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "forge-std/console.sol";

/**
 * @title Vault
 * @dev A smart contract that allows users to deposit and withdraw ERC20 tokens
 * Tracks balances per user and token, and includes basic security measures
 */
contract Vault is ReentrancyGuard {
    // State Variables
    address public immutable owner;

    // Mapping from token address to user address to balance
    mapping(address => mapping(address => uint256)) private balances;

    // Events
    event TokenDeposited(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    event TokenWithdrawn(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    // Constructor
    constructor(address _owner) {
        owner = _owner;
    }

    // Modifiers
    modifier isOwner() {
        require(msg.sender == owner, "Not the Owner");
        _;
    }

    /**
     * @dev Deposits tokens into the vault
     * @param token The ERC20 token address to deposit
     * @param amount The amount of tokens to deposit
     */
    function deposit(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");

        IERC20 tokenContract = IERC20(token);
        require(
            tokenContract.transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        balances[token][msg.sender] += amount;

        emit TokenDeposited(msg.sender, token, amount);
    }

    /**
     * @dev Withdraws tokens from the vault
     * @param token The ERC20 token address to withdraw
     * @param amount The amount of tokens to withdraw
     */
    function withdraw(address token, uint256 amount) external nonReentrant {
        require(token != address(0), "Invalid token address");
        require(amount > 0, "Amount must be greater than 0");
        require(balances[token][msg.sender] >= amount, "Insufficient balance");

        balances[token][msg.sender] -= amount;

        IERC20 tokenContract = IERC20(token);
        require(tokenContract.transfer(msg.sender, amount), "Transfer failed");

        emit TokenWithdrawn(msg.sender, token, amount);
    }

    /**
     * @dev Returns the balance of a specific token for a user
     * @param token The ERC20 token address
     * @param user The user address
     */
    function balanceOf(
        address token,
        address user
    ) external view returns (uint256) {
        return balances[token][user];
    }

    /**
     * @dev Allows the owner to recover accidentally sent tokens
     * @param token The ERC20 token address to recover
     */
    function recoverTokens(address token) external isOwner {
        IERC20 tokenContract = IERC20(token);
        uint256 balance = tokenContract.balanceOf(address(this));
        require(balance > 0, "No tokens to recover");
        require(
            tokenContract.transfer(owner, balance),
            "Recovery transfer failed"
        );
    }
}
