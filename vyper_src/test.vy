timenow: uint256


@external
def getTimeNow():
    self.timenow = block.timestamp
