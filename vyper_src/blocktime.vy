current_time: public(uint256)


@external
def __init__():
    self.current_time = block.timestamp


@external
def set_time():
    self.current_time = block.timestamp
