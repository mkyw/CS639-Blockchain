''' A simple implementation of battleship in Vyper '''

# NOTE: The provided code is only a suggestion
# You can change all of this code (as long as the ABI stays the same)

NUM_PIECES: constant(int32) = 5
BOARD_SIZE: constant(int32) = 5

board_a: int256[BOARD_SIZE][BOARD_SIZE]
board_b: int256[BOARD_SIZE][BOARD_SIZE]

# What phase of the game are we in ?
# Start with SET and end with END
PHASE_SET: constant(int32) = 0
PHASE_SHOOT: constant(int32) = 1
PHASE_END: constant(int32) = 2

# Each player has a 5-by-5 board
# The field track where the player's boats are located and what fields were hit
# Player should not be allowed to shoot the same field twice, even if it is empty
FIELD_EMPTY: constant(int256) = -1
FIELD_BOAT: constant(int256) = 0
FIELD_HIT: constant(int256) = 1

players: immutable(address[2])
p1: constant(int256) = 0
p2: constant(int256) = 1
player_pieces: int32[2]
pieces_hit: int32[2]

# Which player has the next turn? Only used during the SHOOT phase
next_player: int256

# Which phase of the game is it?
phase: int32

# Winner
winner: address

# A player set a piece
event Set:
    pos_x: int32
    pos_y: int32
    player: int32

# A player hit a piece
event Hit:
    pos_x: int32
    pos_y: int32
    player: int32

# A player won
event Winner:
    player: address

@external
def __init__(player1: address, player2: address):
    players = [player1, player2]
    self.next_player = 0
    self.phase = PHASE_SET

    #TODO initialize whatever you need here
    self.player_pieces[0] = 0
    self.player_pieces[1] = 0
    self.pieces_hit[0] = 0
    self.pieces_hit[1] = 0
    
    for i in range(BOARD_SIZE):
        for j in range(BOARD_SIZE):
            self.board_a[i][j] = FIELD_EMPTY
            self.board_b[i][j] = FIELD_EMPTY


@external
def set_field(pos_x: int32, pos_y: int32):
    '''
    Sets a ship at the specified coordinates
    This should only be allowed in the initial phase of the game

    Players are allowed to call this out of order,
    but at most NUM_PIECES times
    '''
    if self.phase != PHASE_SET:
        raise "Wrong phase"

    if pos_x >= BOARD_SIZE or pos_y >= BOARD_SIZE:
        raise "Position out of bounds"

    if msg.sender == players[0]:
        if self.player_pieces[0] < NUM_PIECES:
            if self.board_a[pos_x][pos_y] == FIELD_EMPTY:
                self.board_a[pos_x][pos_y] = FIELD_BOAT
                self.player_pieces[0] += 1
                log Set(pos_x, pos_y, 1)
            else:
                raise "Field already contains a boat!"
        else:
            raise "All pieces set already!"
    elif msg.sender == players[1]:
        if self.player_pieces[1] < NUM_PIECES:
            if self.board_b[pos_x][pos_y] == FIELD_EMPTY:
                self.board_b[pos_x][pos_y] = FIELD_BOAT
                self.player_pieces[1] += 1
                log Set(pos_x, pos_y, 2)
            else:
                raise "Field already contains a boat!"
        else:
            raise "All pieces set already!"
    else:
        raise "Third party cannot set fields!"


    #TODO add the rest here
    if self.player_pieces[0] == NUM_PIECES and self.player_pieces[1] == NUM_PIECES:
        self.phase = PHASE_SHOOT


@external
def shoot(pos_x: int32, pos_y: int32):
    '''
    Shoot a specific field on the other players board
    This should only be allowed if it is the calling player's turn and only during the SHOOT phase
    '''

    if self.phase != PHASE_SHOOT:
        raise "Cannot shoot at this time!"

    if pos_x >= BOARD_SIZE or pos_y >= BOARD_SIZE:
        raise "Position out of bounds"

    current_player: (int256) = 0
    if msg.sender == players[0]:
        current_player = p1
    elif msg.sender == players[1]:
        current_player = p2
    else:
        raise "Sender is not a player"

    if current_player != self.next_player:
        raise "Not your turn!"

    if current_player == p1 and self.board_b[pos_x][pos_y] == FIELD_BOAT:
            self.board_b[pos_x][pos_y] = FIELD_HIT
            self.pieces_hit[0] += 1
            log Hit(pos_x, pos_y, 1)
    elif current_player == p2 and self.board_a[pos_x][pos_y] == FIELD_BOAT:
            self.board_a[pos_x][pos_y] = FIELD_HIT
            self.pieces_hit[1] = self.pieces_hit[1] + 1
            log Hit(pos_x, pos_y, 2)

    self.next_player = (self.next_player + 1) % 2

    if self.pieces_hit[current_player] == 5:
        self.winner = msg.sender
        self.phase = PHASE_END
        log Winner(msg.sender)

@external
@view
def has_winner() -> bool:
    return self.phase == PHASE_END

@external
@view
def get_winner() -> address:
    ''' Returns the address of the winner's account '''

    #TODO figure out who won
    if self.phase == PHASE_END:
        return self.winner

    # Raise an error if no one won yet
    raise "No one won yet"