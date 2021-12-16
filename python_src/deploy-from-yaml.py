from web3 import Web3
from web3 import HTTPProvider
import yaml


# get config yaml
with open("config/config.yaml", "r") as stream:
    try:
        data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)


# get abi
with open("config/abi.txt", "r") as stream:
    box_abi = stream.read()[:-1]


# get bytecode
with open("config/bytecode.txt", "r") as stream:
    box_bytecode = stream.read()[:-1]


# connect to node
w3 = Web3(HTTPProvider(data["nodeip"]))


# check connection
is_connect = w3.isConnected()
if not is_connect:
    print("Is connected?:",w3.isConnected())
    raise Exception("Can't connect to node")
print("Is connected?:",w3.isConnected())


# get account by private key
acct = w3.eth.account.privateKeyToAccount(data["private_key"])
print("Address: ", acct.address)


# create contract with abi and bytecode
contract = w3.eth.contract(
    abi=box_abi,
    bytecode=box_bytecode
)


# check if there are agrs or not
if data["args"] == None:
    construct_txn = contract.constructor().buildTransaction({
        'from': acct.address,
        'nonce': w3.eth.getTransactionCount(acct.address),
        'value': w3.toWei(str(data["value"]), 'ether'),
        'gas': int(data["gas"]),
        'gasPrice': int(data["gasPrice"])})
else:
    construct_txn = contract.constructor(*data["args"]).buildTransaction({
        'from': acct.address,
        'nonce': w3.eth.getTransactionCount(acct.address),
        'value': w3.toWei(str(data["value"]), 'ether'),
        'gas': int(data["gas"]),
        'gasPrice': int(data["gasPrice"])})


signed = acct.signTransaction(construct_txn)    
tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)
tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
print(tx_receipt)
print("---------------------------------")
print(f"Contract Address: {tx_receipt['contractAddress']}")
print("---------------------------------")
print(f"contract_address has been modified.")


with open('./config/config.yaml') as database:
    data = yaml.safe_load((database))
    data['contract_address'] = tx_receipt['contractAddress']
with open("./config/config.yaml", "w") as f:
    yaml.dump(data, f)
