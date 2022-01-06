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


# connect to node
w3 = Web3(HTTPProvider(data["nodeip"]))


# check connection
is_connect = w3.isConnected()
if not is_connect:
    print("Is connected?:",w3.isConnected())
    raise Exception("Can't connect")
print("IP: ",data["nodeip"])
print("Is connected?:",w3.isConnected())


# get account by private key
acct = w3.eth.account.privateKeyToAccount(data["private_key"])
print("Address: ", acct.address)
print("Contract Address: ", data["contract_address"])


# load contract with address and abi
contract = w3.eth.contract(
    address=data["contract_address"],
    abi=box_abi
)


# send transaction
if data["function_transaction"]: 
    contract_function = getattr(contract.functions, data["function_transaction"])
    if data["args"]: # with args
        construct_txn = contract_function(*data["args"]).buildTransaction({
            'from': acct.address,
            'nonce': w3.eth.getTransactionCount(acct.address),
            'value': w3.toWei(str(data["value"]), 'ether'),
            'gas': int(data["gas"]),
            'gasPrice': int(data["gasPrice"])
            })
    else: # no args
        construct_txn = contract_function().buildTransaction({
            'from': acct.address,
            'nonce': w3.eth.getTransactionCount(acct.address),
            'value': w3.toWei(str(data["value"]), 'ether'),
            'gas': int(data["gas"]),
            'gasPrice': int(data["gasPrice"])
            })
    signed = acct.signTransaction(construct_txn)
    tx_hash = w3.eth.sendRawTransaction(signed.rawTransaction)
    tx_receipt = w3.eth.waitForTransactionReceipt(tx_hash)
    print("=================")
    print(tx_receipt)

    log_to_process = tx_receipt['logs'][0]
    processed_log = contract.events.Transfer().processLog(log_to_process)
    print("=================")
    print("[LOG]")
    print(processed_log.args)
    print(processed_log.args.texto)
    print("-----------------")
    print(processed_log)


# call 
contract_caller = contract.caller() 
response = getattr(contract_caller, data["function_call"])
print("=================")
print(f"{data['function_call']}: {response()}")



# log
# log_to_process = box['logs'][0]
# processed_log = contract.events.myEvent().processLog(log_to_process)
# print(processed_log)
