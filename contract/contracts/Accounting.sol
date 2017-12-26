pragma solidity ^0.4.15;
// https://github.com/Giveth/minime/blob/master/contracts/MiniMeToken.sol

import "./MiniMeToken.sol";

/// @dev `Owned` is a base level contract that assigns an `owner` that can be
///  later changed
contract Owned {
    /// @dev `owner` is the only address that can call a function with this
    /// modifier
    modifier onlyOwner { require (msg.sender == owner); _; }

    address public owner;

    /// @notice The Constructor assigns the message sender to be `owner`
    function Owned() public { owner = msg.sender;}

    /// @notice `owner` can step down and assign some other address to this role
    /// @param _newOwner The address of the new owner. 0x0 can be used to create
    ///  an unowned neutral vault, however that cannot be undone
    function changeOwner(address _newOwner) onlyOwner public {
        owner = _newOwner;
    }
}

contract Accounting is Owned{
    
    MiniMeToken public tokenContract;   // The new token for this Campaign
    address public vaultAddress; 
  
}