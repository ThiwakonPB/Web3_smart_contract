# tekken.vy

version: public(int128)
rank_contract: public(address)
current_rank: public(String[16])

interface Rank:
    def get_rank() -> String[16]: view


@external
@payable
def __init__(rank_contract: address):
    self.version = 7
    self.rank_contract = rank_contract


@external
def get_current_rank() -> String[16]:
    return Rank(self.rank_contract).get_rank()
