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
    _value: uint256

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
BID_RETRIEVAL_BATCH_SIZE: constant(uint256) = 400

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


#### Auction utilities ####

@internal
@view
def getBidId(_bidder: address, _bidSequence: uint256) -> uint256:
    msbs: uint256 = shift(convert(_bidder, uint256), 96)
    bidId: uint256 = bitwise_or(msbs, _bidSequence)

    return bidId


@internal
def getNewBidId(_bidder: address) -> uint256:
    self.bidders[_bidder].lastSequence += 1
    return self.getBidId(_bidder, self.bidders[_bidder].lastSequence)


@internal
@view
def _getState() -> uint256:
    if block.timestamp < self.extendedEnd and self.open == True:
        if self.paused:
            return PAUSED_STATE
        else:
            if block.timestamp >= self.startDate:
                if block.timestamp < self.endDate - self.extendingTime:
                    return OPEN_STATE
                else:
                    return SUDDEN_DEATH_STATE
            else:
                return PENDING_STATE
    else:
        return CLOSED_STATE


@external
@view
def getState() -> uint256:
    return self._getState()


@external
def test() -> int128:
    self.testCount += 1
    return self.testCount



##### Assertion ####

@internal
@view
def bidOwner(_sender: address, _bidId: uint256) -> bool:
    return shift(_bidId, -96) == convert(_sender, uint256)


@internal
@view
def _getNewAverageChangingN(
        old_mean: int128,
        _value: uint256,
        temp_bid_count: uint256,
        _count: int128) -> int128:
    return old_mean + ((convert(_value, int128) * _count) - (old_mean * _count)) / (convert(temp_bid_count, int128) + _count)


@internal
@view
def _getNewAverageConstN(
        old_mean: int128,
        token_qty: uint256,
        _value: uint256,
        _count: int128) -> int128:
    value_pushed: uint256  = 0
    temp_bid_id: uint256 = self.lowWinningBidId
    for i in range(MAX_BATCH_SIZE):
        if i >= _count:
            break
        value_pushed += self.levels[temp_bid_id][DEEPEST_LEVEL].value
        temp_bid_id = self.levels[temp_bid_id][DEEPEST_LEVEL].nextBid
    return old_mean + (
            (convert(_value, int128) * _count - convert(value_pushed, int128)) / convert(token_qty, int128))


@internal
def _updateBidsAverage(_value: uint256, _count: int128):
   old_av: int128 = self.bidAverage
   temp_bid_count: uint256 = self.bidCount
   temp_token_qty: uint256 = self.tokenQty
   # Total amount of bids in the money will be increased
   if ( (convert(temp_bid_count, int128) + _count) <=
           convert(temp_token_qty, int128) ):
       self.bidAverage = self._getNewAverageChangingN(
           old_av,
           _value,
           temp_bid_count,
           _count
       )
   else:
       # Total amount of bids will be PARTIALLY increased
       if ( temp_bid_count < temp_token_qty ):
           amount_diff: int128 = (convert(temp_bid_count, int128) + _count) - convert(temp_token_qty, int128)
           temp_mean: int128 = self._getNewAverageChangingN(
                   old_av,
                   _value,
                   temp_bid_count,
                   _count - amount_diff
           )
           self.bidAverage = self._getNewAverageConstN(
               temp_mean,
               temp_token_qty,
               _value,
               amount_diff
           )
       # Total amount of bids in the money will NOT be increased
       else:
           self.bidAverage = self._getNewAverageConstN(
               old_av,
               temp_token_qty,
               _value,
               _count
           )


@internal
@view
def _getLowerBidBound() -> int128:
    # Comparison is by date because we are out control on the Paused state
    if block.timestamp < self.endDate - self.extendingTime:
        return convert(
            self.levels[self.lowWinningBidId][DEEPEST_LEVEL].value,
            int128)
    return self.bidAverage


@external
@view
def getLowerBidBound() -> int128:
    return self._getLowerBidBound()


@internal
@view
def validBidValue(_value: uint256) -> bool:
    if self.minimumBid > _value:
        return False
    if self._getState() == OPEN_STATE:
        return (self.bidCount < self.tokenQty or
               _value > self.levels[self.lowWinningBidId][DEEPEST_LEVEL].value)
    if self._getState() == SUDDEN_DEATH_STATE:
        return convert(_value, int128) > self.bidAverage
    return False


@internal
@view
def _bidOutOfTheMoney(_bidId : uint256) -> bool:
    currentBid: Bid = self.levels[self.lowWinningBidId][DEEPEST_LEVEL]
    value: uint256 = self.levels[_bidId][DEEPEST_LEVEL].value
    result: bool = False

    if currentBid.value == value:
        for i in range(MAX_BID_QTY):
            if currentBid.prevBid == _bidId:
                result = True
                break
            if currentBid.value != value: break
            currentBid = self.levels[currentBid.prevBid][DEEPEST_LEVEL]
        return result
    else:
        return currentBid.value > value


@external
@view
def bidOutOfTheMoney(_bidId : uint256) -> bool:
    return self._bidOutOfTheMoney(_bidId)


##### Data structure utilities ####

@internal
@view
def findClosestLowerValueBid(
        _level: uint256,
        _start: uint256,
        _value: uint256) -> uint256:
    bidId: uint256 = _start
    bid: Bid = self.levels[bidId][_level]
    for i in range(MAX_BID_QTY):
        if bid.nextBid == 0 or self.levels[bid.nextBid][_level].value >= _value:
            break
        bidId = bid.nextBid
        bid = self.levels[bidId][_level]
    return bidId


@internal
@view
def linearCong(_seed: uint256) -> uint256:
    return 69069 * bitwise_and(_seed, 2**32) + 1234567


@internal
@view
def getLevel(_bidId: uint256, _sender: address, _randSeed: uint256) -> int128:
    level: int128 = 0
    xor_result: uint256 = bitwise_xor(
        bitwise_xor(
            bitwise_xor(
                convert(_sender, uint256), _bidId),
                convert(block.prevhash, uint256)
        ),
        _randSeed
    )
    random: uint256 = convert(keccak256(convert(xor_result, bytes32)), uint256)
    for i in range(MAX_LEVEL - 1):
        if bitwise_and(
                random,
                shift(UNPROMOTE_PROB, PROMOTION_CONSTANT * i)
                ) == 0:
            level += 1
        else:
            break

    return level


@internal
@view
def getLevelForMultiBid(_bidder: address, _count: int128) -> int128[MAX_LEVEL]:
    assert _count > 0

    sequence: uint256 = self.bidders[_bidder].lastSequence + 1
    bidCountForEachLevel: int128[MAX_LEVEL] = [0, 0, 0, 0, 0, 0]
    msbs: uint256 = shift(convert(_bidder, uint256), 96)
    seedBuf: uint256 = 0

    for i in range(MAX_BID_QTY):
        if i >= _count:
            break

        bidId: uint256 = bitwise_or(msbs, sequence)
        level: int128 = self.getLevel(bidId, _bidder, seedBuf)
        seedBuf = self.linearCong(bitwise_xor(seedBuf, bidId))
        bidCountForEachLevel[level] += 1

        sequence += 1
    return bidCountForEachLevel


@internal
def insertBid(_bidId: uint256, _value: uint256, _sender: address):
   cursorBidId: uint256 = 0
   height: int128 = self.getLevel(_bidId, _sender, 0)

   for i in range(MAX_LEVEL):
       level: uint256 = MAX_LEVEL  - 1
       cursorBidId = self.findClosestLowerValueBid(level, cursorBidId, _value)
       new_height:uint256 = convert(height, uint256)
       if level <= new_height:
           nextBid: uint256 = self.levels[cursorBidId][level].nextBid
           newBid: Bid = Bid({
                   value: _value,
                   prevBid: cursorBidId,
                   nextBid: nextBid
           })

           if nextBid != 0:
                self.levels[nextBid][level].prevBid = _bidId
           self.levels[cursorBidId][level].nextBid = _bidId
           self.levels[_bidId][level] = newBid

   if _value > self.levels[self.highestBidId][DEEPEST_LEVEL].value:
       self.highestBidId = _bidId       


@internal
def unlinkedBid(_bidId: uint256):
    for i in range(MAX_LEVEL):
        level: int128 = MAX_LEVEL - i - 1
        bid: Bid = self.levels[_bidId][level]
        if bid.value == 0:
            continue
        self.levels[bid.prevBid][level].nextBid = bid.nextBid
        self.levels[bid.nextBid][level].prevBid = bid.prevBid


@internal
def deleteBid(_bidId: uint256):
    for i in range(MAX_LEVEL):
        level: int128 = MAX_LEVEL - i - 1
        if self.levels[_bidId][level].value == 0:
            continue
        self.levels[_bidId][level] = Bid({value: 0, prevBid: 0, nextBid: 0})


@internal
def getBidHeight(_bidId: uint256) -> int128:
    level: int128 = 0
    for i in range(MAX_LEVEL):
        level = MAX_LEVEL - i - 1
        if self.levels[_bidId][level].value != 0:
            break
    return level


##### Public functions #####

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
    ERC20(_currencyAddress).balanceOf(msg.sender)
    ERC20(_currencyAddress).totalSupply()

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


@internal
def _updateExtendedEnd(_state: uint256, _value: uint256):
    if _state == SUDDEN_DEATH_STATE:
        self.extendedEnd = block.timestamp + self.extendingTime
    elif (_state == OPEN_STATE and
         block.timestamp >= self.endDate - self.extendingTime):
        self.extendedEnd = block.timestamp + self.extendingTime


@internal
def _multiInsert(
        _value: uint256,
        _bidIds: uint256[MAX_BATCH_SIZE],
        _count: int128,
        _sender: address,
        addOnly: bool):
    tempBidCount: uint256 = self.bidCount
    _countForEachLevel: int128[MAX_LEVEL] = self.getLevelForMultiBid(
        _sender,
        _count
    )
    totalAddingBids: int128 = 0
    lowestWinningBidId: uint256 = self.lowWinningBidId

    self._updateBidsAverage(_value, _count)

    if _value > self.levels[self.highestBidId][DEEPEST_LEVEL].value:
        self.highestBidId = _bidIds[0]

    for i in range(MAX_LEVEL):
        level: uint256 = MAX_LEVEL - i - 1

        closestLowerBidId: uint256 = lowestWinningBidId # Hack Is this the right initialization value?
        closestLowerBidId = self.findClosestLowerValueBid(
            level,
            closestLowerBidId,
            _value
        )
        cursorBidId: uint256 = closestLowerBidId

        totalAddingBids += _countForEachLevel[level]

        for j in range(MAX_BID_QTY):
            if j >= totalAddingBids:
                break
            bidId: uint256 = _bidIds[j]

            nextBid: uint256 = self.levels[cursorBidId][level].nextBid
            newBid: Bid = Bid({
                value: _value,
                prevBid: cursorBidId,
                nextBid: nextBid
            })

            if nextBid != BASE_BID_ID:
                self.levels[nextBid][level].prevBid = bidId

            self.levels[cursorBidId][level].nextBid = bidId
            self.levels[bidId][level] = newBid

            if level == DEEPEST_LEVEL:
                tempBidCount += 1
                if tempBidCount <= self.tokenQty:
                    lowestWinningBidId = \
                        self.levels[BASE_BID_ID][DEEPEST_LEVEL].nextBid
                else:
                    assert (_value >
                           self.levels[lowestWinningBidId][DEEPEST_LEVEL].value)
                    lowestWinningBidId = \
                        self.levels[lowestWinningBidId][DEEPEST_LEVEL].nextBid
                if addOnly:
                    log BidAdded(_sender, bidId, _value)
                else:
                    log BidIncreased(_sender, bidId, _value)

    if addOnly:
        self.bidCount = tempBidCount

    self.lowWinningBidId = lowestWinningBidId
    self.bidders[_sender].lastSequence += convert(_count, uint256)


@external
def addBids(_value: uint256, _count: int128):
    state: uint256 = self._getState()
    assert (state == OPEN_STATE or
           state == SUDDEN_DEATH_STATE), "Auction is not Open or Sudden Death"

    assert _value > 0, "Value of a bid has to be positive"
    assert _count > 0, "Must add bid at least one"

    self._updateExtendedEnd(state, _value)

    assert self.validBidValue(_value), \
           "Bid has to be greater than the lower bound for a bid candidate"

    totalValue: uint256 = _value * convert(_count, uint256)
    ERC20(self.currencyAddress).transferFrom(msg.sender, self, totalValue)

    _bidIds: uint256[MAX_BATCH_SIZE] = empty(uint256[MAX_BATCH_SIZE])
    startSequence: uint256 = self.bidders[msg.sender].lastSequence + 1

    for i in range(MAX_BATCH_SIZE):
        if i >= _count:
            break
        _bidIds[i] = self.getBidId(
            msg.sender,
            startSequence + convert(i, uint256)
        )

    self._multiInsert(_value, _bidIds, _count, msg.sender, True)


@external
def increaseBids(_bidIds: uint256[MAX_BATCH_SIZE], _value: uint256):
    state: uint256 = self._getState()
    assert (state == OPEN_STATE or
           state == SUDDEN_DEATH_STATE), \
           "Auction is not in Open or Sudden Death"

    self._updateExtendedEnd(state, _value)

    assert self.validBidValue(_value), \
           "Bid has to be greater than the lower bound for a bid candidat"

    count: int128 = 0
    totalValue: uint256 = 0

    tempBidCount: uint256 = self.bidCount

    for bidId in _bidIds:
        if bidId == 0:
            break

        oldValue: uint256 = self.levels[bidId][DEEPEST_LEVEL].value

        assert oldValue < _value and oldValue > 0
        assert self.bidOwner(msg.sender, bidId)

        if not self._bidOutOfTheMoney(bidId):
            self.lowWinningBidId = \
                self.levels[self.lowWinningBidId][DEEPEST_LEVEL].prevBid

        withdraw: uint256 = self.levels[bidId][DEEPEST_LEVEL].value
        self.unlinkedBid(bidId)
        tempBidCount = tempBidCount - 1

        totalValue = totalValue + (_value - oldValue)
        count = count + 1

    ERC20(self.currencyAddress).transferFrom(msg.sender, self, totalValue)

    self._multiInsert(_value, _bidIds, count, msg.sender, False)


@internal
def _removeBid(_bidId: uint256, _sender: address):
    assert self.levels[_bidId][DEEPEST_LEVEL].value != 0, "Bid does not exist"
    assert self.bidOwner(_sender, _bidId), \
           "A bid can be removed only by its owner"
    assert (self.tokenQty == 0 or
           self._bidOutOfTheMoney(_bidId)), \
           "Either tokens are minted or current bid is in the money"

    withdraw: uint256 = self.levels[_bidId][DEEPEST_LEVEL].value
    self.unlinkedBid(_bidId)
    self.bidCount -= 1
    ERC20(self.currencyAddress).transfer(_sender, withdraw)
    self.deleteBid(_bidId)
    log BidRemoved(_sender, _bidId)


@external
def removeBid(_bidId: uint256):
    state: uint256 = self._getState()
    assert (state != PAUSED_STATE and
           state != PENDING_STATE), "Auction is paused or not started yet"
    self._removeBid(_bidId, msg.sender)


@external
def batchRemoveBid(_bidIds: uint256[MAX_BATCH_SIZE]):
    state: uint256 = self._getState()
    assert (state != PAUSED_STATE and
           state != PENDING_STATE), "Auction is paused or not started yet"

    for bidId in _bidIds:
        if bidId == 0:
            break
        self._removeBid(bidId, msg.sender)


##### Owner of KYC Provider only ####

@external
def pauseAuction():
    state: uint256 = self._getState()
    assert (state != PAUSED_STATE and
           state != CLOSED_STATE), "Already paused or closed"
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can pause"

    self.paused = True
    log AuctionPaused()


@external
def resumeAuction():
    assert self._getState() == PAUSED_STATE, "Auction is not paused"
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can unpause it"

    self.paused = False
    log AuctionUnpaused()


@external
def closeAuction():
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can close it"
    assert block.timestamp > self.endDate, \
           "An auction can be closed iff its end date has passed"

    self.open = False
    log AuctionClosed()


@external
def mintTokens(_size: int128):
    assert _size > 0, "Quantity has to be positive"
    assert self._getState() == CLOSED_STATE, "Auction is not closed"
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can mint tokens"
    assert (self.tokenQty > 0 and
           self.bidCount > 0), "Available tokens or bid number not positive"

    tokenIndex: uint256 = self.minTokenId
    cursor: uint256 = 0
    withdraw: uint256 = 0
    mintedCount: uint256 = 0
    bid: Bid = Bid({value: 0, prevBid: 0, nextBid: 0})

    cursor = self.highestBidId

    indexes: uint256[MAX_BATCH_SIZE] = empty(uint256[MAX_BATCH_SIZE])
    toAccounts: address[MAX_BATCH_SIZE] = empty(address[MAX_BATCH_SIZE])


    for i in range(MAX_BATCH_SIZE):
        if cursor == 0 or i >= _size:
            break

        bid = self.levels[cursor][DEEPEST_LEVEL]

        to: address = convert(convert(shift(cursor, -96), bytes32), address)

        indexes[i] = tokenIndex
        toAccounts[i] = to

        withdraw += bid.value
        mintedCount += 1

        # Delete bid
        for level in range(MAX_LEVEL):
            if self.levels[cursor][level].value != 0:
                self.levels[cursor][level] = Bid({
                    value: 0,
                    prevBid: 0,
                    nextBid: 0
                })
                self.levels[bid.prevBid][level].nextBid = 0

        if cursor == self.lowWinningBidId:
            break

        cursor = bid.prevBid
        tokenIndex += 1

    ABC(self.tokenContract).mintNonFungibleToken(
        self.tokenType,
        toAccounts,
        indexes
    )

    if cursor == self.lowWinningBidId:
        self.highestBidId = bid.prevBid
        self.lowWinningBidId = bid.prevBid
    else:
        self.highestBidId = cursor

    self.bidCount -= mintedCount
    self.tokenQty -= mintedCount

    self.minTokenId = tokenIndex

    ERC20(self.currencyAddress).transfer(msg.sender, withdraw)
    log TokensMinted(tokenIndex - mintedCount, mintedCount)


@external
def promoteBid(_bidId: uint256, _height: int128):
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can promote a bid"
    assert _height > 0, "Promote level is not positive"

    level: int128 = self.getBidHeight(_bidId)

    assert level < _height, \
           "Promote level is higher than the current skip list\'s height"

    value: uint256 = self.levels[_bidId][DEEPEST_LEVEL].value

    cursor: uint256 = self.levels[_bidId][level].prevBid
    bid: Bid = self.levels[cursor][level]

    for i in range(MAX_BID_QTY):
        if bid.value == self.levels[cursor][level + 1].value:
            level += 1
            nextBid: uint256 = self.levels[cursor][level].nextBid
            newBid: Bid = Bid({value: value, prevBid: cursor, nextBid: nextBid})

            if nextBid != 0:
                self.levels[nextBid][level].prevBid = _bidId
            self.levels[cursor][level].nextBid = _bidId
            self.levels[_bidId][level] = newBid
            if level == _height:
                break
        else:
            cursor = self.levels[cursor][level].prevBid
            bid = self.levels[cursor][level]
    log BidPromoted(_bidId, _height)


@external
def destroyContract():
    assert self._getState() == CLOSED_STATE, "Auction is not closed"
    assert (self.tokenQty == 0 or
           self.bidCount == 0) , \
           "Both number of tokens and bids have to be positive"
    assert self.contractOwner == msg.sender, \
           "Only owner of an auction can destoy auction contract"

    selfdestruct(msg.sender)