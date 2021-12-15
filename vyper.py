
import os
import sys
import yaml
if sys.argv[1] == "compile":
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    f = open("./config/bytecode.txt", "r")
    f2 = open("./config/abi.txt", "r")
    print(f.read()) 
    print(f2.read())
    
elif sys.argv[1] == "deploy":
    os.system("vyper ./vyper_src/" + sys.argv[2] + " > ./config/bytecode.txt")
    os.system("vyper -f abi_python ./vyper_src/" + sys.argv[2] + " > ./config/abi.txt")
    os.system("python ./python_src/deploy-from-yaml.py")

elif sys.argv[1] == "nodeip":
    with open('./config/config.yaml') as database:
        data = yaml.safe_load((database))
        data['nodeip'] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)

elif sys.argv[1] == "private_key":
    with open('./config/config.yaml') as database:
        data = yaml.safe_load((database))
        data['private_key'] = sys.argv[2]
    with open("./config/config.yaml", "w") as f:
        yaml.dump(data, f)

else:
    print("you dumb")