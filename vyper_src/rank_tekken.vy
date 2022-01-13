# rank_tekken.vy

rank: public(String[16])


@external
@payable
def __init__():
    self.rank = "1dan"


@external
def set_rank(new_rank: String[16]):
    self.rank = new_rank


@external
def get_rank() -> String[16]:
    return self.rank
