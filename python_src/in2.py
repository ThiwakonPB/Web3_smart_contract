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



# call 
contract_caller = contract.caller().addressToBool("0x3cC807065B9F2d06E14c9F7550347c2a5785087F")
# response = getattr(contract_caller, data["function_call"])
print("=================")
# print(f"{data['function_call']}: {response()}")
print(f"{data['function_call']}: {contract_caller}")



# log
# log_to_process = box['logs'][0]
# processed_log = contract.events.myEvent().processLog(log_to_process)
# print(processed_log)
