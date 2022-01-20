import typer
import os
import yaml
from web3 import Web3
from web3 import HTTPProvider


app = typer.Typer()


# load config file
with open('./config/config.yaml') as database:
    data = yaml.safe_load((database))


# check for python3
is_python3 = False


def auto_complete_contract():
    filenames = os.listdir("vyper_src/")
    return filenames


def check_python():
    status = os.system(f"command -v python3")
    if status != 0:
        print(f"python3: not found")
        print(f"Trying python...")
        status2 = os.system(f"command -v python")
        if status2 != 0:
            print(f"python: not found")
            print("Abort")
            exit()
        else:
            print(f"Detect: python")
    else:
        print(f"python3: detected")
        global is_python3 
        is_python3 = True


def input_no():
    return ["n", "no", "No", "N"]


def input_yes():
    return ["y", "yes", "Yes", "Y"]


def compile_helper(contract: str):
    os.system("vyper ./vyper_src/" + contract + " > ./data/" + contract)
    os.system("vyper -f abi_python ./vyper_src/" + contract + " >> ./data/" + contract)
    text = typer.style(f"{contract} compiled <(￣︶￣)>", fg=typer.colors.GREEN, bold=True)
    typer.echo(text)

    print("\n") 
    print("Bytecode and Abi below") 
    print("========================") 
    f = open(f"./data/{contract}", "r")
    print(f.read()) 
    print(f.read()) 
    print("========================") 


@app.callback()
def callback():
    """
    Awesome Web3 vyper toolkit
    """


@app.command()
def compile(
        contract: str = typer.Argument(
            "Bob", help="Choose a contract", autocompletion=auto_complete_contract)
        ):
    """
    Compile vyper source code into folder
    """

    if contract == "Bob":
        typer.echo("Please include Contract's name")
    elif os.path.isfile(f"vyper_src/{contract}"):
        # Confirm contract already compiled before
        if os.path.isfile(f"data/{contract}"):
            text = typer.style(f"Contract exists overwrite? Σ(°△°|||) [y/N]\n", fg=typer.colors.YELLOW, bold=True)
            user_input = input(text)
            if user_input in input_yes():
                text = typer.style(f"Override {contract}", fg=typer.colors.YELLOW, bold=True)
                typer.echo(text)
                compile_helper(contract)
            else:
                typer.echo("Abort")
        else:
            compile_helper(contract)
    else:
        text = typer.style(f"{contract} not found...", fg=typer.colors.RED, bold=True)
        typer.echo(text)


@app.command()
def load():
    """
    Load contract
    """
    typer.echo("Loading a contract")


@app.command()
def deploy(contract_name: str):
    """
    Deploy a contract
    """
    typer.echo("Deploy a contract!")

    # get config yaml
    with open("config/config.yaml", "r") as stream:
        try:
            data = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    # get abi and bytecode
    with open(f"data/{contract_name}", "r") as stream:
        box_bytecode = stream.readline()[:-1]
        box_abi = stream.readline()[:-1]
    
    # connect to node
    w3 = Web3(HTTPProvider(data["nodeip"]))

    # check connection
    is_connect = w3.isConnected()
    if not is_connect:
        typer.echo("Connection: {is_connect}")
        raise Exception("Can't connect to node")
    typer.echo(f"IP: {data['nodeip']}")
    typer.echo(f"Connection: {is_connect}")


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
    # os.system("echo 'YAY'")
    # os.system(f"echo '{tx_receipt['contractAddress']}' >> data/{contract}")

    # os.system("echo 'MAMAMAM' >> data/kazuma.vy")
    print("ECHO HERE")
    os.system(f"echo {tx_receipt['contractAddress']} >> data/{contract_name}")


@app.command()
def interact(contract_name: str):
    """
    Deploy a contract
    """
    typer.echo("Deploy a contract!")

    # get config yaml
    with open("config/config.yaml", "r") as stream:
        try:
            data = yaml.safe_load(stream)
        except yaml.YAMLError as exc:
            print(exc)

    # get abi and bytecode
    with open(f"data/{contract_name}", "r") as stream:
        box_bytecode = stream.readline()[:-1]
        box_abi = stream.readline()[:-1]
    
    # connect to node
    w3 = Web3(HTTPProvider(data["nodeip"]))

    # check connection
    is_connect = w3.isConnected()
    if not is_connect:
        typer.echo("Connection: {is_connect}")
        raise Exception("Can't connect to node")
    typer.echo(f"IP: {data['nodeip']}")
    typer.echo(f"Connection: {is_connect}")


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
    # os.system("echo 'YAY'")
    # os.system(f"echo '{tx_receipt['contractAddress']}' >> data/{contract}")

    # os.system("echo 'MAMAMAM' >> data/kazuma.vy")
    print("ECHO HERE")
    os.system(f"echo {tx_receipt['contractAddress']} >> data/{contract_name}")
