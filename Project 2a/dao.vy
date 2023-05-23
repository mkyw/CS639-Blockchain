from vyper.interfaces import ERC20

implements: ERC20

event Transfer:
    sender: indexed(address)
    receiver: indexed(address)
    value: uint256

event Approval:
    owner: indexed(address)
    spender: indexed(address)
    value: uint256

balanceOf: public(HashMap[address, uint256])
allowance: public(HashMap[address, HashMap[address, uint256]])
totalSupply: public(uint256)

# TODO add state that tracks proposals here
struct Proposal:
    uid: uint256
    recipient: address
    value: uint256
    votes: uint256
    status: bool

struct Voter:
    voter: address
    value: uint256


proposal_list: public(HashMap[uint256, Proposal])
voter_list: public(HashMap[address, Voter])
voter_status: public(HashMap[address, bool[1024]])

@external
def __init__():
    self.balanceOf[msg.sender] = 0
    self.totalSupply = 0

@external
@payable
@nonreentrant("lock")
def buyToken():
    self.balanceOf[msg.sender] += msg.value
    self.totalSupply += msg.value
    
    voter: Voter = Voter({voter: msg.sender, value: msg.value})
    self.voter_list[msg.sender] = voter
    pass

@external
@nonpayable
@nonreentrant("lock")
def sellToken(_value: uint256):
    self.balanceOf[msg.sender] -= _value
    self.totalSupply -= _value
    pass

# TODO add other ERC20 methods here

@external
@nonpayable
@nonreentrant("lock")
def createProposal(_uid: uint256, _recipient: address, _amount: uint256):
    if _amount <= 0:
        raise "Proposal amount must be positive"
    elif self.proposal_list[_uid].value != 0:
        raise "Existing proposal still running"

    proposal: Proposal = Proposal({uid: _uid, recipient:_recipient, value:_amount, votes: 0, status:False})
    self.proposal_list[_uid] = proposal
    pass

@external
@nonpayable
@nonreentrant("lock")
def approveProposal(_uid: uint256):
    # Check stakeholder status
    if self.voter_list[msg.sender].value <= 0:
        raise "No funds available"
    # Check voting status
    if self.voter_status[msg.sender][_uid]:
        raise "Already voted"
    
    self.voter_status[msg.sender][_uid] = True

    self.proposal_list[_uid].votes += self.balanceOf[msg.sender]

    if (2 * self.proposal_list[_uid].votes) >= self.totalSupply and self.proposal_list[_uid].status == False:
        self.proposal_list[_uid].status = True

        recipient: address = self.proposal_list[_uid].recipient
        amount: uint256 = self.proposal_list[_uid].value
        send(recipient, amount)

        self.proposal_list[_uid].status = True
    pass

@external
def transfer(_to : address, _value : uint256) -> bool:
    """
    @dev Transfer token for a specified address
    @param _to The address to transfer to.
    @param _value The amount to be transferred.
    """
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[msg.sender] -= _value
    self.balanceOf[_to] += _value

    self.voter_list[_to].value += _value

    log Transfer(msg.sender, _to, _value)
    return True


@external
def transferFrom(_from : address, _to : address, _value : uint256) -> bool:
    """
     @dev Transfer tokens from one address to another.
     @param _from address The address which you want to send tokens from
     @param _to address The address which you want to transfer to
     @param _value uint256 the amount of tokens to be transferred
    """
    # NOTE: vyper does not allow underflows
    #       so the following subtraction would revert on insufficient balance
    self.balanceOf[_from] -= _value
    self.balanceOf[_to] += _value
    # NOTE: vyper does not allow underflows
    #      so the following subtraction would revert on insufficient allowance
    self.allowance[_from][msg.sender] -= _value
    log Transfer(_from, _to, _value)
    return True


@external
def approve(_spender : address, _value : uint256) -> bool:
    """
    @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
         Beware that changing an allowance with this method brings the risk that someone may use both the old
         and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
         race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
         https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
    @param _spender The address which will spend the funds.
    @param _value The amount of tokens to be spent.
    """
    self.allowance[msg.sender][_spender] = _value
    log Approval(msg.sender, _spender, _value)
    return True