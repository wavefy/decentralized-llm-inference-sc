// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title DLLM - Decentralized LLM Inference Contract
 * @dev Contract for managing decentralized LLM inference sessions with token-based rewards
 */
contract DLLM is ReentrancyGuard, Ownable {
    using ECDSA for bytes32;
    using MessageHashUtils for bytes32;

    // =============================== Events ===============================
    
    event SessionCreated(
        uint64 indexed sessionId,
        address indexed owner,
        uint256 pricePerToken,
        uint256 maxTokens,
        address[] addresses,
        uint256[] layers,
        uint256 timestamp
    );

    event TokenClaimed(
        uint64 indexed sessionId,
        address indexed owner,
        address indexed claimer,
        uint256 tokenCount,
        uint256 totalReward,
        uint256 timestamp
    );

    event SessionUpdated(
        uint64 indexed sessionId,
        address indexed owner,
        address[] addresses
    );

    event PoolDeposit(
        address indexed owner,
        uint256 amount
    );

    // =============================== Constants ===============================
    
    uint256 public constant PRICE_PER_TOKEN = 1 * 10**18; // 1 token (assuming 18 decimals)

    // =============================== Custom Errors ===============================
    
    error SessionNotFound();
    error InsufficientTokens();
    error CannotClaimOwnTokens();
    error InvalidClaim();
    error BalanceInsufficient();
    error InvalidSignature();
    error AddressNotInSession();

    // =============================== Storage ===============================
    
    struct Session {
        uint64 sessionId;
        address owner;
        address[] addresses;
        uint256[] layers;
        uint256 pricePerToken;
        uint256 maxTokens;
        mapping(address => bool) claimed;
        address[] claimedList;
        address publicKey; // For EVM, we'll use address as public key identifier
    }

    // Token contract for rewards (e.g., USDC, USDT, or custom token)
    IERC20 public rewardToken;
    
    // Mapping from owner address to their reward pool balance
    mapping(address => uint256) public rewardPools;
    
    // Mapping from session object address to session data
    mapping(bytes32 => Session) public sessions;
    
    // Mapping to track session existence
    mapping(address => mapping(uint64 => bool)) public sessionExists;

    // =============================== Constructor ===============================
    
    constructor(address _rewardToken) Ownable(msg.sender) {
        rewardToken = IERC20(_rewardToken);
    }

    // =============================== Main Functions ===============================
    
    /**
     * @dev Deposit tokens to the reward pool
     * @param amount Amount of tokens to deposit
     */
    function deposit(uint256 amount) external nonReentrant {
        if (amount == 0) revert BalanceInsufficient();
        
        if (!rewardToken.transferFrom(msg.sender, address(this), amount)) {
            revert BalanceInsufficient();
        }
        
        rewardPools[msg.sender] += amount;
        
        emit PoolDeposit(msg.sender, amount);
    }

    /**
     * @dev Create a new inference session
     * @param sessionId Unique session identifier
     * @param maxTokens Maximum tokens that can be claimed
     * @param addresses List of addresses that can claim tokens
     * @param layers Number of layers for each address
     * @param clientPk Public key for signature verification (represented as address)
     */
    function createSession(
        uint64 sessionId,
        uint256 maxTokens,
        address[] memory addresses,
        uint256[] memory layers,
        address clientPk
    ) external nonReentrant {
        if (addresses.length != layers.length) revert InvalidClaim();
        if (sessionExists[msg.sender][sessionId]) revert InvalidClaim();
        
        // Calculate minimum required balance
        uint256 totalLayers = 0;
        for (uint256 i = 0; i < layers.length; i++) {
            totalLayers += layers[i];
        }
        uint256 minBalance = totalLayers * PRICE_PER_TOKEN * maxTokens;
        
        if (rewardPools[msg.sender] < minBalance) revert BalanceInsufficient();
        
        // Create session object address (deterministic)
        bytes32 sessionObjectAddr = generateSessionId(msg.sender, sessionId);
        
        Session storage session = sessions[sessionObjectAddr];
        session.sessionId = sessionId;
        session.owner = msg.sender;
        session.addresses = addresses;
        session.layers = layers;
        session.pricePerToken = PRICE_PER_TOKEN;
        session.maxTokens = maxTokens;
        session.publicKey = clientPk;
        
        sessionExists[msg.sender][sessionId] = true;
        
        emit SessionCreated(
            sessionId,
            msg.sender,
            PRICE_PER_TOKEN,
            maxTokens,
            addresses,
            layers,
            block.timestamp
        );
    }

    /**
     * @dev Claim tokens from a session
     * @param ownerAddress Address of the session owner
     * @param sessionId Session identifier
     * @param tokenCount Number of tokens to claim
     * @param signature Signature proving the claim
     */
    function claimTokens(
        address ownerAddress,
        uint64 sessionId,
        uint256 tokenCount,
        bytes memory signature
    ) external nonReentrant {
        bytes32 sessionObjectAddr = generateSessionId(ownerAddress, sessionId);
        if (!sessionExists[ownerAddress][sessionId]) revert SessionNotFound();
        
        Session storage session = sessions[sessionObjectAddr];
        if (session.maxTokens < tokenCount) revert InvalidClaim();
        if (session.owner == msg.sender) revert CannotClaimOwnTokens();
        if (session.claimed[msg.sender]) revert InvalidClaim();
        
        // Verify signature
        bytes32 messageHash = keccak256(abi.encodePacked(tokenCount));
        bytes32 ethSignedMessageHash = messageHash.toEthSignedMessageHash();
        address recoveredSigner = ethSignedMessageHash.recover(signature);
        if (recoveredSigner != session.publicKey) revert InvalidSignature();
        
        // Find address index and get layers
        uint256 addressIndex = type(uint256).max;
        for (uint256 i = 0; i < session.addresses.length; i++) {
            if (session.addresses[i] == msg.sender) {
                addressIndex = i;
                break;
            }
        }
        if (addressIndex == type(uint256).max) revert AddressNotInSession();
        
        uint256 layers = session.layers[addressIndex];
        uint256 totalReward = tokenCount * layers * session.pricePerToken;
        
        // Update state
        session.claimed[msg.sender] = true;
        session.claimedList.push(msg.sender);
        rewardPools[ownerAddress] -= totalReward;
        
        // Transfer reward
        if (!rewardToken.transfer(msg.sender, totalReward)) {
            revert BalanceInsufficient();
        }
        
        emit TokenClaimed(
            sessionId,
            ownerAddress,
            msg.sender,
            tokenCount,
            totalReward,
            block.timestamp
        );
    }

    // =============================== View Functions ===============================
    
    /**
     * @dev Check if a session exists
     */
    function hasSession(address signerAddress, uint64 sessionId) external view returns (bool) {
        return sessionExists[signerAddress][sessionId];
    }

    /**
     * @dev Get session details
     */
    function getSession(address signerAddress, uint64 sessionId) external view returns (
        uint64,
        address,
        address[] memory,
        uint256[] memory,
        uint256,
        uint256,
        address[] memory
    ) {
        if (!sessionExists[signerAddress][sessionId]) revert SessionNotFound();
        
        bytes32 sessionObjectAddr = generateSessionId(signerAddress, sessionId);
        Session storage session = sessions[sessionObjectAddr];
        
        return (
            session.sessionId,
            session.owner,
            session.addresses,
            session.layers,
            session.pricePerToken,
            session.maxTokens,
            session.claimedList
        );
    }

    /**
     * @dev Get reward pool balance for an address
     */
    function getBalance(address signerAddress) external view returns (uint256) {
        return rewardPools[signerAddress];
    }

    /**
     * @dev Check if an address has claimed from a session
     */
    function hasClaimed(address ownerAddress, uint64 sessionId, address claimer) external view returns (bool) {
        if (!sessionExists[ownerAddress][sessionId]) {
            return false;
        }
        
        bytes32 sessionObjectAddr = generateSessionId(ownerAddress, sessionId);
        return sessions[sessionObjectAddr].claimed[claimer];
    }

    // =============================== Helper Functions ===============================
    
    /**
     * @dev Generate deterministic session ID
     */
    function generateSessionId(address owner, uint64 sessionId) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("dllm_session", owner, sessionId));
    }

    // =============================== Admin Functions ===============================
    
    /**
     * @dev Update reward token (only owner)
     */
    function updateRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20(_rewardToken);
    }

    /**
     * @dev Emergency withdraw function (only owner)
     */
    function emergencyWithdraw(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }
}