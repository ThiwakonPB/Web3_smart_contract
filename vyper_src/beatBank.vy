# Beat Bank

amount_deposit: public(uint256)
beatAddress: public(address)
version: public(int128)
current_balance: public(uint256)


@external
@payable
def __init__():
    self.amount_deposit = msg.value
    self.beatAddress = msg.sender
    self.version = 6
    self.current_balance = self.balance


@external
@payable
def payBeat():
    send(self.beatAddress, msg.value)
