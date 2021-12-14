from web3 import Web3
from web3 import HTTPProvider
import yaml


# get config yaml
with open("config.yaml", "r") as stream:
    try:
        data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)

print(data)
# get abi
with open("config/abi.txt", "r") as stream:
    box_abi = stream.read()[:-1]


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
print("Contract Address: ", data["contract_address"])


# load contract with address and abi
contract = w3.eth.contract(
    # address=data["contract_address"],
    address=data["contract_address"],
    abi=box_abi
)

# construct_txn = contract.functions.test().buildTransaction({
#     'from': acct.address,
#     'nonce': w3.eth.getTransactionCount(acct.address),
#     'gas': 10000000,
#     'gasPrice': 30000000000
#     })

# signed = acct.signTransaction(construct_txn)
# tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)
# tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
# print(tx_receipt)
# print(contract.caller().version()) 
contract_caller = contract.caller() 
response = getattr(contract_caller, "version")
print(response())
