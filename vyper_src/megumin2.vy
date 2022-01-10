# Megumin

text: public(String[20])
kazuma_contract: public(address)
response: public(String[20])

interface Kazuma:
    def say() -> String[20]: view


@external
@payable
def __init__(kazuma: address):
    self.text = "Kazuma! Kazuma!"
    self.kazuma_contract = kazuma


@external
def call_kazuma():
    self.response = Kazuma(self.kazuma_contract).say()
