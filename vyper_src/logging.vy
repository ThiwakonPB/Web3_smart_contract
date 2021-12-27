# event log

owner: public(address)
version: public(int128)
count: public(int128)

event Transfer:
  texto: String[30]
  value: int128

@external
@payable
def __init__():
  self.owner = msg.sender
  self.version = 11


@external
@payable
def plusOne():
  self.count += 1
  log Transfer("Add 1 to the count!", 42069)

