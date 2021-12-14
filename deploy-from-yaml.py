from web3 import Web3
from web3 import HTTPProvider
import yaml


# get config yaml
with open("config.yaml", "r") as stream:
    try:
        data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)


# connect to node
w3 = Web3(HTTPProvider(data["nodeip"]))


# check connection
is_connect = w3.isConnected()
if not is_connect:
    print("Is connected?:",w3.isConnected())
    raise Exception("Can't connect")
print("Is connected?:",w3.isConnected())


# get account by private key
acct = w3.eth.account.privateKeyToAccount(data["private_key"])
print("Address: ", acct.address)


# create contract with abi and bytecode
contract = w3.eth.contract(
    abi=data["abi"],
    bytecode=data["bytecode"]
)


# check if there are agrs or not
if data["args"] == None:
    construct_txn = contract.constructor().buildTransaction({
        'from': acct.address,
        'nonce': w3.eth.getTransactionCount(acct.address),
        'value': w3.toWei(str(data["value"]), 'ether'),
        'gas': 9000000,
        'gasPrice': 30000000000})
else:
    construct_txn = contract.constructor(*data["args"]).buildTransaction({
        'from': acct.address,
        'nonce': w3.eth.getTransactionCount(acct.address),
        'value': w3.toWei(str(data["value"]), 'ether'),
        'gas': 9000000,
        'gasPrice': 30000000000})


signed = acct.signTransaction(construct_txn)    
tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)
tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
print(tx_receipt)
print("---------------------------------")
print(f"Contract Address: {tx_receipt['contractAddress']}")
print("---------------------------------")

