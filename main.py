import typer
import os
import yaml

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


@app.callback()
def callback():
    """
    Awesome Web3 vyper toolkit
    """


@app.command()
def compile(
        contract: str = typer.Option(
            "Bob", help="Choose a contract", autocompletion=auto_complete_contract)
        ):
    """
    Compile vyper source code into folder
    """
    if contract == "Bob":
        typer.echo("Please include Contract's name")
    else:
        typer.echo("Compiling a contract")
        os.system("vyper ./vyper_src/" + contract + " > ./config/bytecode.txt")
        os.system("vyper -f abi_python ./vyper_src/" + contract + " > ./config/abi.txt")
        f = open("./config/bytecode.txt", "r")
        f2 = open("./config/abi.txt", "r")
        print(f.read()) 
        print(f2.read()) 


@app.command()
def load():
    """
    Load contract
    """
    typer.echo("Loading a contract")


@app.command()
def deploy():
    """
    Deploy a contract
    """
    typer.echo("Deploy a contract!")

