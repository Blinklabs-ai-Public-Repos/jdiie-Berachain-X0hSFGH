// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract LoyaltyToken is ERC20, ERC20Burnable, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    bool public transferable;
    uint256 public lockPeriod;
    mapping(address => uint256) public lockedBalances;
    mapping(address => uint256) public lockEndTimes;

    event TokensLocked(address indexed user, uint256 amount, uint256 unlockTime);
    event TokensUnlocked(address indexed user, uint256 amount);

    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {
        transferable = true;
        lockPeriod = 30 days;
    }

    function setTransferable(bool _transferable) external onlyOwner {
        transferable = _transferable;
    }

    function setLockPeriod(uint256 _lockPeriod) external onlyOwner {
        lockPeriod = _lockPeriod;
    }

    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function lockTokens(uint256 amount) external {
        require(balanceOf(_msgSender()) >= amount, "Insufficient balance");
        _transfer(_msgSender(), address(this), amount);
        lockedBalances[_msgSender()] += amount;
        lockEndTimes[_msgSender()] = block.timestamp + lockPeriod;
        emit TokensLocked(_msgSender(), amount, lockEndTimes[_msgSender()]);
    }

    function unlockTokens() external {
        require(block.timestamp >= lockEndTimes[_msgSender()], "Tokens are still locked");
        uint256 amount = lockedBalances[_msgSender()];
        require(amount > 0, "No tokens to unlock");
        lockedBalances[_msgSender()] = 0;
        _transfer(address(this), _msgSender(), amount);
        emit TokensUnlocked(_msgSender(), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, amount);
        require(transferable || from == address(0) || to == address(0), "Transfers are currently disabled");
    }
}

contract LoyaltyProgram is ERC721, Ownable {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    LoyaltyToken public loyaltyToken;
    bool public transferable;
    mapping(uint256 => uint256) public tokenValues;

    event RewardMinted(address indexed to, uint256 tokenId, uint256 value);
    event RewardRedeemed(address indexed from, uint256 tokenId, uint256 value);

    constructor(string memory name_, string memory symbol_, address _loyaltyTokenAddress) ERC721(name_, symbol_) {
        loyaltyToken = LoyaltyToken(_loyaltyTokenAddress);
        transferable = true;
    }

    function setTransferable(bool _transferable) external onlyOwner {
        transferable = _transferable;
    }

    function mintNFTReward(address to, uint256 value) external onlyOwner {
        _tokenIdCounter.increment();
        uint256 tokenId = _tokenIdCounter.current();
        _safeMint(to, tokenId);
        tokenValues[tokenId] = value;
        emit RewardMinted(to, tokenId, value);
    }

    function mintTokenReward(address to, uint256 amount) external onlyOwner {
        loyaltyToken.mint(to, amount);
    }

    function redeemNFTReward(uint256 tokenId) external {
        require(ownerOf(tokenId) == _msgSender(), "Not the owner of this NFT");
        uint256 value = tokenValues[tokenId];
        delete tokenValues[tokenId];
        _burn(tokenId);
        loyaltyToken.mint(_msgSender(), value);
        emit RewardRedeemed(_msgSender(), tokenId, value);
    }

    function redeemTokenReward(uint256 amount) external {
        loyaltyToken.burnFrom(_msgSender(), amount);
    }

    function _beforeTokenTransfer(address from, address to, uint256 tokenId, uint256 batchSize)
        internal
        override
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
        require(transferable || from == address(0) || to == address(0), "Transfers are currently disabled");
    }
}