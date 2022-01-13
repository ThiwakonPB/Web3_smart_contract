version: public(int128)
characters: public(HashMap[int128, String[16]])


@external
def add_char(id: int128, name: String[16]):
    self.characters[id] = name
