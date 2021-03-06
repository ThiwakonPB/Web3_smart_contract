# Web3 smart contract
Python web3 script to help quickly deploy and test vyper smart contracts.

## Prerequisite
Python 3.9.7 or above <br>
Vyper 0.3.0

## Set up
Set target node ip and private key that will be used to pay the gas fees. <br>
<br>
Set node ip
```
python vyper.py nodeip  http://10.66.67.6:8545
```
Set account that is already filled with crypto currency 
```
python vyper.py private_key 7dfa0e753d3b9c6e3b2c76360f28cc4623c867acc8f7b041d8828ef9b8d6ddfd
```
<br>
Once these attributes have been set, move your vyper smart contracts to ./vyper_src and you're good to go. Or you can use the example_contract.vy to test. <br>
<br>

## Commands
If you just want to compile the contract and print the byte code and abi<br>
```
python vyper.py compile example_contract.vy
```
Compile and deploy the contract to the node. This will save the contract address returned in the config file to be used when interacting with the contract.
```
python vyper.py deploy example_contract.vy
```

## Other configuration commands
These commands are use to change specific configuration such as gas price.<br>

```
python vyper.py gas 100000
```
