@external
def get_number() -> int128:
    return 16
    

@external
def try_get_number() -> int128:
    return self.get_number()
    

