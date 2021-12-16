
import os
import sys
import yaml

# load config file
with open('./config/config.yaml') as database:
    data = yaml.safe_load((database))


def vyper_compile():
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    f = open("./config/bytecode.txt", "r")
    f2 = open("./config/abi.txt", "r")
    print(f.read()) 
    print(f2.read()) 


def deploy():
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    try:
        if sys.argv[3]:
            key = 'args'
            data[key] = sys.argv[3]
            with open("./config/config.yaml", "w") as f:
                yaml.dump(data, f)
    except:
        print("No arguments provided")
    os.system("python ./python_src/deploy-from-yaml.py")


def config():
    key = sys.argv[1]
    data[key] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)


def interact():
    key = sys.argv[1]
    data[key] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)


# checks for user command args
if sys.argv[1] == "compile":
    vyper_compile()
elif sys.argv[1] == "deploy":
    deploy()
elif sys.argv[1] == "nodeip" or sys.argv[1] == "private_key" or sys.argv[1] == "contract_address" or sys.argv[1] == "gas":
    config()
elif sys.argv[1] == "interact":
    interact()
else:
    print("Please enter the correct arguments")

