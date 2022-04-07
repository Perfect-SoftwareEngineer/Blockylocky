// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

contract Blockylocky {
    struct FTLockInfo {
        uint count;
        uint expiredTime;
        bool isUnLocked;
    }

    struct FTVestedLockInfo {
        uint count;
        uint unlockedCount;
        uint lockedTime;
        uint expiredTime;
    }

    struct NFTLockInfo {
        uint id;
        uint count;
        uint expiredTime;
        bool isUnLocked;
    }

    mapping(address => mapping(address => FTLockInfo)) _lockedFTInfo;

    mapping(address => mapping(address => FTVestedLockInfo)) _vestedLockFTInfo;

    mapping(address => mapping(address => NFTLockInfo)) _lockedNFTInfo;

    uint public _lockedCount;
    uint public _expiredCount; // bonus 4th requirement

    constructor() {
    }

    // scenario 1
    function lockFTToken(address ftTokenAddress_, uint lockCount_, uint expiredTime_) external {
        require(ftTokenAddress_ != address(0), "ft token address should be valid");
        require(lockCount_ > 0, "lock count should be greater than 0");
        require(expiredTime_ > block.timestamp, "expired time should be over than now");
        require(IERC20(ftTokenAddress_).allowance(msg.sender, address(this)) >= lockCount_, "not enough allowance");
        require(_lockedFTInfo[msg.sender][ftTokenAddress_].count == 0, "have already locked");

        _lockedFTInfo[msg.sender][ftTokenAddress_].count = lockCount_;
        _lockedFTInfo[msg.sender][ftTokenAddress_].isUnLocked = false;
        _lockedFTInfo[msg.sender][ftTokenAddress_].expiredTime = expiredTime_;

        IERC20(ftTokenAddress_).transferFrom(msg.sender, address(this), lockCount_);
        _lockedCount++;
    }

    function unlockFTToken(address ftTokenAddress_) external {
        require(ftTokenAddress_ != address(0), "ft token address should be valid"); 
        require(
            block.timestamp > _lockedFTInfo[msg.sender][ftTokenAddress_].expiredTime,
            "no unlocked token"
        );

        _lockedFTInfo[msg.sender][ftTokenAddress_].isUnLocked = true;

        IERC20(ftTokenAddress_).transfer(msg.sender, _lockedFTInfo[msg.sender][ftTokenAddress_].count);
        _expiredCount++;
    }

    // scenario 2
    function vestedLockFTToken(address ftTokenAddress_, uint lockCount_, uint expiredTime_) external {
        require(ftTokenAddress_ != address(0), "ft token address should be valid");
        require(lockCount_ > 0, "lock count should be greater than 0");
        require(expiredTime_ > block.timestamp, "vested expired time should be over than now");
        require(IERC20(ftTokenAddress_).allowance(msg.sender, address(this)) >= lockCount_, "not enough allowance");
        require(_vestedLockFTInfo[msg.sender][ftTokenAddress_].count == 0, "have already vested locked");

        _vestedLockFTInfo[msg.sender][ftTokenAddress_].count = lockCount_;
        _vestedLockFTInfo[msg.sender][ftTokenAddress_].unlockedCount = 0;
        _vestedLockFTInfo[msg.sender][ftTokenAddress_].lockedTime = block.timestamp;
        _vestedLockFTInfo[msg.sender][ftTokenAddress_].expiredTime = expiredTime_;

        IERC20(ftTokenAddress_).transferFrom(msg.sender, address(this), lockCount_);
        _lockedCount++;
    }

    function vestedUnLockFTToken(address ftTokenAddress_) external {
        require(ftTokenAddress_ != address(0), "ft token address should be valid"); 
        require(
            _vestedLockFTInfo[msg.sender][ftTokenAddress_].unlockedCount < _vestedLockFTInfo[msg.sender][ftTokenAddress_].count,
            "this lock have already expired"
        );
        
        uint period = _vestedLockFTInfo[msg.sender][ftTokenAddress_].expiredTime - _vestedLockFTInfo[msg.sender][ftTokenAddress_].lockedTime;

        require(
            block.timestamp > (_vestedLockFTInfo[msg.sender][ftTokenAddress_].lockedTime + (period / 4)),
            "no unlocked token"
        );

        uint unLockedCount;
        if(block.timestamp > _vestedLockFTInfo[msg.sender][ftTokenAddress_].expiredTime) {
            unLockedCount =  (_vestedLockFTInfo[msg.sender][ftTokenAddress_].count - _vestedLockFTInfo[msg.sender][ftTokenAddress_].unlockedCount);
            _vestedLockFTInfo[msg.sender][ftTokenAddress_].unlockedCount = _vestedLockFTInfo[msg.sender][ftTokenAddress_].count;
            _expiredCount++;
        } else if(block.timestamp > (_vestedLockFTInfo[msg.sender][ftTokenAddress_].lockedTime + (period / 4))) {
            unLockedCount = (_vestedLockFTInfo[msg.sender][ftTokenAddress_].count) / 4;
            _vestedLockFTInfo[msg.sender][ftTokenAddress_].unlockedCount = unLockedCount;
        } else {}

        IERC20(ftTokenAddress_).transfer(msg.sender, unLockedCount);
    }

    // scenario 3
    function lockNFTToken(address nftTokenAddress_, uint tokenId_, uint lockCount_, uint expiredTime_) external {
        require(nftTokenAddress_ != address(0), "ft token address should be valid");
        require(lockCount_ > 0, "lock count should be greater than 0");
        require(expiredTime_ > block.timestamp, "expired time should be over than now");
        require(IERC1155(nftTokenAddress_).isApprovedForAll(msg.sender, address(this)), "not approved");
        require(_lockedFTInfo[msg.sender][nftTokenAddress_].count == 0, "have already locked");

        _lockedNFTInfo[msg.sender][nftTokenAddress_].id = tokenId_;
        _lockedNFTInfo[msg.sender][nftTokenAddress_].count = lockCount_;
        _lockedNFTInfo[msg.sender][nftTokenAddress_].isUnLocked = false;
        _lockedNFTInfo[msg.sender][nftTokenAddress_].expiredTime = expiredTime_;

        IERC1155(nftTokenAddress_).safeTransferFrom(msg.sender, address(this), tokenId_, lockCount_, "");
        _lockedCount++;
    }

    function unlockNFTToken(address nftTokenAddress_) external {
        require(nftTokenAddress_ != address(0), "ft token address should be valid"); 
        require(
            block.timestamp > _lockedNFTInfo[msg.sender][nftTokenAddress_].expiredTime,
            "no unlocked token"
        );

        _lockedNFTInfo[msg.sender][nftTokenAddress_].isUnLocked = true;

        IERC1155(nftTokenAddress_).safeTransferFrom(
            address(this), 
            msg.sender, 
            _lockedNFTInfo[msg.sender][nftTokenAddress_].id, 
            _lockedNFTInfo[msg.sender][nftTokenAddress_].count,
            ""
        );
        _expiredCount++;
    }

    // bonus 3th requirement
    function activeLockCount() external view returns(uint) {
        return (_lockedCount - _expiredCount);
    }

    // bonus 5th requirement
    function ftlockRemainTime(address user_, address ftTokenContractAddress_) external view returns(uint){
        require(_lockedFTInfo[user_][ftTokenContractAddress_].expiredTime < block.timestamp, "have already expired");
        return (_lockedFTInfo[user_][ftTokenContractAddress_].expiredTime - block.timestamp);
    }

    function ftVestedlockRemainTime(address user_, address ftTokenContractAddress_) external view returns(uint){
        require(_vestedLockFTInfo[user_][ftTokenContractAddress_].expiredTime < block.timestamp, "have already expired");
        return (_vestedLockFTInfo[user_][ftTokenContractAddress_].expiredTime - block.timestamp);
    }

    function nftlockRemainTime(address user_, address ftTokenContractAddress_) external view returns(uint){
        require(_lockedNFTInfo[user_][ftTokenContractAddress_].expiredTime < block.timestamp, "have already expired");
        return (_lockedNFTInfo[user_][ftTokenContractAddress_].expiredTime - block.timestamp);
    }
}
