from vyper.interfaces import ERC20


struct Bid:
    value: uint256
    prevBid: uint256 # Bid with lower or equal value to current bid
    nextBid: uint256 # Bid with greater or equal value to current bid

struct Bidder:
    lastSequence: uint256


# External Contracts
interface ABC:
    def mintNonFungibleToken(
            _tokenType: uint256,
            _to: address[100],
            _indexes: uint256[100]): payable


########### Events ###############
event BidAdded:
    _operator: indexed(address)
    _bidId: indexed(uint256)
    _value: uint256s

event BidIncreased:
    _operator: indexed(address)
    _bidId: indexed(uint256)
    _value: uint256

event BidRemoved:
    _operator: indexed(address)
    _bidId: indexed(uint256)

event AuctionPaused: pass

event AuctionUnpaused: pass

event AuctionClosed: pass

event TokensMinted: 
    _minTokenId: uint256
    _mintedQty: uint256

event BidPromoted:
    _bidId: indexed(uint256)
    _height: int128


CONTRACT_VERSION : constant(uint256) = 1000001

BASE_BID_ID: constant(uint256) = 0
DEEPEST_LEVEL: constant(int128) = 0

# ABC token
MAX_BATCH_SIZE: constant(uint256) = 100

# Bid retrieval batch size
BID_RETRIEVAL_BATCH_SIZE: constant(uint256) = 10

# Contract configuration
MAX_AUCTION_ITEMS: constant(uint256) = 5000000
MAX_BID_QTY: constant(uint256) = 5000000 * 10
MAX_WHITELIST_OPS: constant(uint256) = 10
MAX_LEVEL: constant(int128) = 6
# promote probability = 2 ^ PROMOTION_CONSTANT
PROMOTION_CONSTANT: constant(int128) = 3
UNPROMOTE_PROB: constant(int128) = (2 ** 3) - 1

PENDING_STATE: constant(uint256) = 1
PAUSED_STATE: constant(uint256) = 2
OPEN_STATE: constant(uint256) = 3
SUDDEN_DEATH_STATE: constant(uint256) = 4
CLOSED_STATE: constant(uint256) = 5


contractOwner: public(address)
currencyAddress: address
minimumBid: public(uint256)

open: public(bool)
paused: public(bool)
startDate: public(uint256)
endDate: public(uint256)
extendedEnd: public(uint256)
extendingTime: public(uint256)

minTokenId: public(uint256)
maxTokenId: public(uint256)
# Total number of tokenIds actually in the tokenIds list.
tokenQty: public(uint256)

bidCount: public(uint256)
bidAverage: public(int128)
highestBidId: public(uint256)
lowWinningBidId: public(uint256)

levels: public(HashMap[uint256, Bid[MAX_LEVEL]])

# bidders: public(HashMap(address, Bidder))  # Map between address and Bidder object
bidders: public(HashMap[address, Bidder])  # Map between address and Bidder object

tokenContract: address
tokenType: uint256
testCount: public(int128)

@external
@view
def contractVersion() -> uint256:
    """
    auction.vy -    Auction Contract for Ordered Sequential Non-Fungible Tokens
                    Given a descending ordered (by value) list of tokens with unique ids,
                    this auction contract will assign the top bids to the most valuable
                    tokens when the auction ends.

                    ITEMS - Tokens must be in our ERC-1155 contract and be optioned to this
                    auction contract. (Or should the auction mint the tokens? Probably so.)
                    List of items should be in descending order of value and one item may
                    only be in the list once.

                    KYC - Bids must come from wallets that are in a whitelist managed by 
                    a KYCProvider.

                    KYC_CANCEL - Bidders removed from the whitelist have all their bids
                    'cancelled'. They may no longer add or update bids. Their bids will not
                    be matched with tokens should they be 'in the money' post auction.
                    (WARNING - if we don't remove the bids right away this could mess up our
                    'in the money' calculations for future bids and cancellation. Probably 
                    should disallow kyc cancellations for our initial implementation and 
                    perhaps add this later.)

                    MULTI_BID - Bidders may create multiple bids in order to bid on 
                    multiple tokens.

                    ETHER - All bids are denominated in Ethereum wei.

                    SAME_VALID - Bids can be for the same bid value as a pre-existing bid 
                    as long as the number of active bids is lower than the number of 
                    available tokens OR the bid value is higher than the bid value of the 
                    current lowest winning bid.

                    INCREASE - Bidders may update existing bids by increasing their value.

                    CANCELLOSER - Bidders may cancel existing bids only if their bid is 
                    'out of the money'.

                    FAIR_PRECEDENCE - Pre-existing bids of the same bid value have 
                    precedence over new bids of the same value.

                    TIMED_AUCTION - Bidding may commence on or after 'start' time so long 
                    as 'pause' is False, and normal bidding ends upon 'end' time. Contract 
                    owner may pause the bidding at any time.

                    FINAL_AUCTION - Final auction bidding model is TBD. Sudden death 
                    extended bids from a more restricted set of bidding wallets is anticipated.

                    WIN_MATCH - Upon auction completion, the top bids will be matched to 
                    their respective most valuable tokens. 

                    LOSER_REFUND - All non-matched bids will be eligible for refund
                    requests from their bidding wallets. Owner can push refunds optionally.

                    DESTRUCT - After the auction is completed, owner may self destruct the
                    contract. Remaining value will be returned to auction owner or wallet
                    designated by owner.
    """
    return CONTRACT_VERSION


@external
def __init__(
    _tokenContract: address,
    _tokenType: uint256,
    _minTokenId: uint256,
    _maxTokenId: uint256,
    _currencyAddress: address,
    _minimumBid: uint256,
    _startDate: uint256,
    _endDate: uint256,
    _extendingTime: uint256
):
    """
    _tokenContract - address of token contract.

    _tokenType - type of ABC token.

    _minTokneId - an index of token with minimum sequence number that make
    it be the most valuable token of the auction.

    _minTokneId - an index of token with maximum sequence number that make
    it be the least valuable token of the auction.

    _currencyAddress - ERC20 contract address that going to be main
    currency of the auction contract

    _minimumBid - Minimium acceptable bid of the acution

    _startDate - the datetime when the auction can accept bids.

    _endDate - the datetime when the auction ends normal bidding activities.

    _extendingTime - the timedelta to extend the auction end time
    """
    assert _maxTokenId >= _minTokenId, "Max token id is less than minimum one"
    assert block.timestamp < _endDate, \
           "End of the auction is earlier than current time"
    assert _startDate < _endDate, \
           "End of the auction is earlier than its start date"
    quantity: uint256 = _maxTokenId - _minTokenId + 1
    assert quantity <= MAX_AUCTION_ITEMS, \
           "Total quantity of tokens exceeded maximum allowance"

    # Check currency address is ERC20 contract

    self.minTokenId = _minTokenId
    self.maxTokenId = _maxTokenId

    self.tokenContract = _tokenContract
    self.tokenType = _tokenType

    self.tokenQty = quantity
    self.bidAverage = 0

    self.contractOwner = msg.sender
    self.currencyAddress = _currencyAddress
    self.minimumBid = _minimumBid

    self.open = True
    self.startDate = _startDate
    self.endDate = _endDate
    self.extendedEnd = _endDate
    self.extendingTime = _extendingTime
    self.testCount = 0


@external
@view
def getBids(
       _startBid: uint256,
       _size: int128) -> uint256[2][BID_RETRIEVAL_BATCH_SIZE]:
   assert _size > 0

   # bids: uint256[2][BID_RETRIEVAL_BATCH_SIZE]
   bids: uint256[2][BID_RETRIEVAL_BATCH_SIZE] = empty(uint256[2][BID_RETRIEVAL_BATCH_SIZE])
   bid: Bid = self.levels[_startBid][DEEPEST_LEVEL]
   bidId: uint256 = _startBid

   for i in range(BID_RETRIEVAL_BATCH_SIZE):
       if bidId == 0 or i >= _size:
           break
       bid = self.levels[bidId][DEEPEST_LEVEL]
       bids[i] = [bidId, bid.value]
       bidId = bid.prevBid
   return bids

@external
def test() -> int128:
    self.testCount += 1
    return self.testCount

