auctionOwner: public(address)

highestBid: public(uint256)
addressHighestBid: public(address)
contractBalance: public(uint256)
theEnd: public(bool)
jeronumber: public(uint256)


@external
@payable
def __init__(_number:uint256):
    self.auctionOwner = msg.sender
    self.highestBid = 0
    self.theEnd = False
    self.jeronumber = _number



@external
@payable
def bid():
    assert not self.theEnd
    assert msg.value > self.highestBid
    if self.highestBid != 0:
        send(self.addressHighestBid, self.highestBid) # refund

    # update
    self.addressHighestBid = msg.sender
    self.highestBid = msg.value
    self.contractBalance = self.balance


@external
def endAuction():
    assert self.auctionOwner == msg.sender
    send(self.auctionOwner, self.balance)
    self.theEnd = True