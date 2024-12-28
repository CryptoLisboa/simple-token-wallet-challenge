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
    uint256 public constant MINIMUM_BALANCE = 1; // Minimum balance to keep tracking a token
    
    // Mapping from token address to user address to balance
    mapping(address => mapping(address => uint256)) private _balances;
    
    // Mapping to track which tokens a user has interacted with
    mapping(address => address[]) private _userTokens;
    // Mapping to check if a token is already tracked for a user
    mapping(address => mapping(address => bool)) private _hasToken;

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

    event TokenUntracked(
        address indexed user,
        address indexed token
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
     * @dev Internal function to track tokens for a user
     * @param user The user address
     * @param token The token address
     */
    function _trackUserToken(address user, address token) private {
        if (!_hasToken[user][token]) {
            _userTokens[user].push(token);
            _hasToken[user][token] = true;
        }
    }

    /**
     * @dev Internal function to remove a token from user's tracking list
     * @param user The user address
     * @param token The token address
     */
    function _untrackUserToken(address user, address token) private {
        if (_hasToken[user][token]) {
            // Find and remove the token from the array
            address[] storage userTokenList = _userTokens[user];
            for (uint256 i = 0; i < userTokenList.length; i++) {
                if (userTokenList[i] == token) {
                    // Move the last element to the position being deleted
                    if (i != userTokenList.length - 1) {
                        userTokenList[i] = userTokenList[userTokenList.length - 1];
                    }
                    // Remove the last element
                    userTokenList.pop();
                    break;
                }
            }
            _hasToken[user][token] = false;
            emit TokenUntracked(user, token);
        }
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
        
        _balances[token][msg.sender] += amount;
        _trackUserToken(msg.sender, token);
        
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
        require(_balances[token][msg.sender] >= amount, "Insufficient balance");
        
        uint256 remainingBalance = _balances[token][msg.sender] - amount;
        _balances[token][msg.sender] = remainingBalance;
        
        // If balance falls below minimum, untrack the token
        if (remainingBalance < MINIMUM_BALANCE) {
            _untrackUserToken(msg.sender, token);
        }
        
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
        return _balances[token][user];
    }

    /**
     * @dev Returns all tokens that a user has a non-zero balance of
     * @param user The user address to check
     * @return tokens Array of token addresses
     * @return tokenBalances Array of corresponding token balances
     */
    function getUserTokens(address user) external view returns (
        address[] memory tokens,
        uint256[] memory tokenBalances
    ) {
        address[] memory allTokens = _userTokens[user];
        uint256 nonZeroCount = 0;

        // First pass: count non-zero balances
        for (uint256 i = 0; i < allTokens.length; i++) {
            if (_balances[allTokens[i]][user] > 0) {
                nonZeroCount++;
            }
        }

        // Allocate arrays with exact size
        tokens = new address[](nonZeroCount);
        tokenBalances = new uint256[](nonZeroCount);
        
        // Second pass: fill arrays
        uint256 currentIndex = 0;
        for (uint256 i = 0; i < allTokens.length; i++) {
            uint256 balance = _balances[allTokens[i]][user];
            if (balance > 0) {
                tokens[currentIndex] = allTokens[i];
                tokenBalances[currentIndex] = balance;
                currentIndex++;
            }
        }
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
