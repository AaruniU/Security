Arithmetic Overflow and Underflow

Prior to v0.8.1, Solidity contracts were vulnerable to over/underflow attacks. This vulnerability caused mathematical operations of +, - and * to be exploited if the attacker can control the value of at least one operand. A demo for over/underflow behaviour is provided below:

// SPDX-License-Identifier: MIT
pragma solidity 0.6.10;

contract Test
{
    // Overflow: Passing (255, 1) will return 0
    function add(uint8 x, uint8 y) pure public returns(uint8)
    {
        return x + y;
    }
    
    // Underflow: Passing (0, 1) will return 255
    function sub(uint8 x, uint8 y) pure public returns(uint8)
    {
        return x - y;
    }  
}

To see the vulnerability in action, lets see the contract from one of the Ethernaut Challenges:

pragma solidity ^0.4.18;

contract Token {

  mapping(address => uint) balances;
  uint public totalSupply;

  function Token(uint _initialSupply) {
    balances[msg.sender] = totalSupply = _initialSupply;
  }

  function transfer(address _to, uint _value) public returns (bool) {
    require(balances[msg.sender] - _value >= 0);
    balances[msg.sender] -= _value;
    balances[_to] += _value;
    return true;
  }

  function balanceOf(address _owner) public constant returns (uint balance) {
    return balances[_owner];
  }
}

The transfer() is vulnerable to over/underflow attack as the attacker controls the value of _value. If a sender with zero Token balance in the contract calls the transfer() with, say _value = 1:

// 0-1 = 115792089237316195423570985008687907853269984665640564039457584007913129639935 > 0 so evaluates to true
require(balances[msg.sender] - _value >= 0);

// balances[msg.sender] = 0 - 1 = 115792089237316195423570985008687907853269984665640564039457584007913129639935. That's a lot of free tokens.
balances[msg.sender] -= _value;

// balances[_to] = 0 + 1
balances[_to] += _value;

Again, this vulnerability can not be exploited with Solidity 0.8.1^ as the transaction would just revert upon detecting an over/underflow.
