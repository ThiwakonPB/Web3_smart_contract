# import the following dependencies
import json
import yaml
from web3 import Web3
from web3 import HTTPProvider
import asyncio


# get config yaml
with open("config/config.yaml", "r") as stream:
    try:
        data = yaml.safe_load(stream)
    except yaml.YAMLError as exc:
        print(exc)


# get abi
with open("config/abi.txt", "r") as stream:
    box_abi = stream.read()[:-1]


contractAddress = data["contract_address"]
contract = w3.eth.contract(address=contractAddress, abi=box_abi)
accounts = w3.eth.accounts
greeting_Event = contract.events.greeting() # Modification


def handle_event(event):
    receipt = w3.eth.waitForTransactionReceipt(event['transactionHash'])
    result = greeting_Event.processReceipt(receipt) # Modification
    print(result[0]['args'])


def log_loop(event_filter, poll_interval):
    while True:
        for event in event_filter.get_new_entries():
            handle_event(event)
            time.sleep(poll_interval)


block_filter = w3.eth.filter({'fromBlock':'latest', 'address':contractAddress})
log_loop(block_filter, 2)
