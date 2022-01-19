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
        contract: str = typer.Option(
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
def deploy():
    """
    Deploy a contract
    """
    typer.echo("Deploy a contract!")

