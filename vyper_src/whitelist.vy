addressToBool: public(HashMap[address, bool])
idToAddress: HashMap[int128, address]
currentId: public(int128)
owner: public(address)


@external
def __init__():
    self.owner = msg.sender


@external
def add_to_whitelist(new_address: address):
    assert self.owner == msg.sender
    self.idToAddress[self.currentId] = new_address
    self.addressToBool[new_address] = True
    self.currentId += 1


@external
def remove_from_whitelist(new_address: address):
    assert self.owner == msg.sender
    self.addressToBool[new_address] = False
