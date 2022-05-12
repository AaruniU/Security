Prior to Solidity v0.5.0, Smart Contracts suffered from vulnerability resulting from attacker using a shorter than required address as function parameter. The vulnerability resulted from EVM's tendency to append zero's at the end of calldata in case a parameter(in this case, an address) was shorter in length than it is by definition. 

Looking at example presented at: https://github.com/sigp/solidity-security-blog#8-short-addressparameter-attack-1

Consider the transfer() of an ERC20 contract: function transfer(address to, uint tokens) public returns (bool success);

Suppose the attacker passes an address that is only 19 Bytes long. So the EVM would append extra an 00 at the end of calldata to preserve the size of calldata:

Calldata with a 20 Byte address:: 
a9059cbb000000000000000000000000deaddeaddeaddeaddeaddeaddeaddeaddeaddead0000000000000000000000000000000000000000000000056bc75e2d63100000

Calldata with a 19 Byte address:
a9059cbb000000000000000000000000deaddeaddeaddeaddeaddeaddeaddeaddeadde0000000000000000000000000000000000000000000000056bc75e2d6310000000

Note the 20 Byte address 000000000000000000000000deaddeaddeaddeaddeaddeaddeaddeaddeaddead is longer than the 19 Byte address 000000000000000000000000deaddeaddeaddeaddeaddeaddeaddeaddeadde. Also the last parameter (uint tokens) has changed from 0000000000000000000000000000000000000000000000056bc75e2d63100000 (100 tokens) to 00000000000000000000000000000000000000000000056bc75e2d6310000000 (25600 tokens)

However, with Solidity version >= 0.5.0, the transaction would simply revert if a parameter is shorter than expected:
https://ethereum.stackexchange.com/a/77210
