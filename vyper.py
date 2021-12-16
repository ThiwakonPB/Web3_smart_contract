import os
import sys
import yaml

is_python3 = False

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


if sys.argv[1] == "compile":
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    f = open("./config/bytecode.txt", "r")
    f2 = open("./config/abi.txt", "r")
    print(f.read()) 
    print(f2.read())
    
elif sys.argv[1] == "deploy":
    check_python()
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    try:
        if sys.argv[3]:
            key = 'args'
            with open('./config/config.yaml') as database:
                data = yaml.safe_load((database))
                data[key] = sys.argv[3]
            with open("./config/config.yaml", "w") as f:
                yaml.dump(data, f)
    except:
        print("No arguments provided")
    if is_python3:
        os.system("python3 ./python_src/deploy-from-yaml.py")
    else:
        os.system("python ./python_src/deploy-from-yaml.py")

elif sys.argv[1] == "nodeip" or sys.argv[1] == "private_key" or sys.argv[1] == "contract_address" or sys.argv[1] == "gas":
    key = sys.argv[1]
    with open('./config/config.yaml') as database:
        data = yaml.safe_load((database))
        data[key] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)

elif sys.argv[1] == "interact":
    key = sys.argv[1]
    with open('./config/config.yaml') as database:
        data = yaml.safe_load((database))
        data[key] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)

else:
    print("Please enter the correct arguments")
