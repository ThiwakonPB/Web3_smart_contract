# Kazuma

text: public(String[20])






@external
@payable
def __init__():
    self.text = "Kazuma desu"



@external
def say() -> String[20]:
    return self.text
