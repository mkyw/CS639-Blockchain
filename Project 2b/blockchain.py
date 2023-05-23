# forked from https://github.com/dvf/blockchain

from ast import dump
import hashlib
import json
import time
import threading
import logging
from xml.dom import ValidationErr

import requests
from flask import Flask, request

class Transaction(object):
    def __init__(self, sender, recipient, amount):
        self.sender = sender # constraint: should exist in state
        self.recipient = recipient # constraint: need not exist in state. Should exist in state if transaction is applied.
        self.amount = amount # constraint: sender should have enough balance to send this amount

    def __str__(self) -> str:
        return "T(%s -> %s: %s)" % (self.sender, self.recipient, self.amount)

    def encode(self) -> str:
        return self.__dict__.copy()

    @staticmethod
    def decode(data):
        return Transaction(data['sender'], data['recipient'], data['amount'])

    def __lt__(self, other):
        if self.sender < other.sender: return True
        if self.sender > other.sender: return False
        if self.recipient < other.recipient: return True
        if self.recipient > other.recipient: return False
        if self.amount < other.amount: return True
        return False
    
    def __eq__(self, other) -> bool:
        return self.sender == other.sender and self.recipient == other.recipient and self.amount == other.amount

class Block(object):
    def __init__(self, number, transactions, previous_hash, miner):
        self.number = number # constraint: should be 1 larger than the previous block
        self.transactions = transactions # constraint: list of transactions. Ordering matters. They will be applied sequentlally.
        self.previous_hash = previous_hash # constraint: Should match the previous mined block's hash
        self.miner = miner # constraint: The node_identifier of the miner who mined this block
        self.hash = self._hash()

    def _hash(self):
        return hashlib.sha256(
            str(self.number).encode('utf-8') +
            str([str(txn) for txn in self.transactions]).encode('utf-8') +
            str(self.previous_hash).encode('utf-8') +
            str(self.miner).encode('utf-8')
        ).hexdigest()

    def __str__(self) -> str:
        return "B(#%s, %s, %s, %s, %s)" % (self.hash[:5], self.number, self.transactions, self.previous_hash, self.miner)
    
    def encode(self):
        encoded = self.__dict__.copy()
        encoded['transactions'] = [t.encode() for t in self.transactions]
        return encoded
    
    @staticmethod
    def decode(data):
        txns = [Transaction.decode(t) for t in data['transactions']]
        return Block(data['number'], txns, data['previous_hash'], data['miner'])

class State(object):
    def __init__(self, chain):
        # TODO: You might want to think how you will store balance per person.
        # You don't need to worry about persisting to disk. Storing in memory is fine.
        self.balance = {}
        self.chain = chain

    def encode(self):
        # TODO: Add all person -> balance pairs into `dumped`.
        dumped = self.balance.copy()
        return dumped

    def validate_txns(self, txns):
        result = []
        # TODO: returns a list of valid transactions.
        # You receive a list of transactions, and you try applying them to the state.
        # If a transaction can be applied, add it to result. (should be included)

        state_copy = self.balance.copy()
        for t in txns:
            if t.sender in state_copy and state_copy[t.sender] >= t.amount:
                result.append(t)
                state_copy[t.sender] -= t.amount
                if t.recipient not in state_copy:
                    state_copy[t.recipient] = 0
                state_copy[t.recipient] += t.amount

        return result

    def apply_block(self, block):
        # TODO: apply the block to the state.
        for t in block.transactions:
            self.balance[t.sender] -= t.amount
            if t.recipient not in self.balance:
                self.balance[t.recipient] = 0
            self.balance[t.recipient] += t.amount
        logging.info("Block (#%s) applied to state. %d transactions applied" % (block.hash, len(block.transactions)))
        
    def history(self, account):
        # TODO: return a list of (blockNumber, value changes) that this account went through 
        # Here is an example

        history = []
        val = 0

        for block in self.chain:
            if block.number == 1 and account == 'A':
                history.append((block.number, 10000))
            for txn in block.transactions:
                if txn.sender == account:
                    val -= txn.amount
                if txn.recipient == account:
                    val += txn.amount
            if val != 0:
                history.append((block.number, val))
            val = 0

        return history

class Blockchain(object):
    def __init__(self):
        self.nodes = []
        self.node_identifier = 0
        self.block_mine_time = 5

        # in memory datastructures.
        self.current_transactions = [] # A list of `Transaction`
        self.chain = [] # A list of `Block`
        self.state = State(self.chain)

    def is_new_block_valid(self, block, received_blockhash):
        """
        Determine if I should accept a new block.
        Does it pass all semantic checks? Search for "constraint" in this file.

        :param block: A new proposed block
        :return: True if valid, False if not
        """
        # TODO: check if received block is valid
        # 1. Hash should match content
        if block.hash != received_blockhash:
            return False

        # 2. Previous hash should match previous block
        if block.number == 1 and block.previous_hash != '0xfeedcafe':
            return False
        elif len(self.chain) > 0 and self.chain[-1].hash != block.previous_hash:
            return False

        # # 3. Transactions should be valid (all apply to block)
        x = self.state.validate_txns(block.transactions)
        for a in block.transactions:
            if a not in x:
                return False

        # 4. Block number should be one higher than previous block
        if block.number != len(self.chain) + 1:
            return False

        # 5. miner should be correct (next RR)
        if block.number % len(self.nodes) == 0:
            if block.miner != self.nodes[block.number % len(self.nodes) + len(self.nodes) - 1]:
                return False
        if block.miner != self.nodes[block.number % len(self.nodes) - 1]:
            return False


        return True

    def trigger_new_block_mine(self, genesis=False):
        thread = threading.Thread(target=self.__mine_new_block_in_thread, args=(genesis,))
        thread.start()

    def __mine_new_block_in_thread(self, genesis=False):
        """
        Create a new Block in the Blockchain

        :return: New Block
        """
        logging.info("[MINER] waiting for new transactions before mining new block...")
        time.sleep(self.block_mine_time) # Wait for new transactions to come in
        miner = self.node_identifier

        if genesis:
            block = Block(1, [], '0xfeedcafe', miner)
        else:
            self.current_transactions.sort()
            valid_txns = self.state.validate_txns(self.current_transactions)
            block = Block(len(self.chain)+1, valid_txns, self.chain[len(self.chain)-1].hash, miner)

        # TODO: make changes to in-memory data structures to reflect the new block. Check Blockchain.__init__ method for in-memory datastructures
        self.chain.append(block)
        
        if genesis:
            # TODO: at time of genesis, change state to have 'A': 10000 (person A has 10000)
            self.state.balance['A'] = 10000
        else:
            self.state.apply_block(block)
            self.current_transactions = [t for t in self.current_transactions if t not in valid_txns]

        logging.info("[MINER] constructed new block with %d transactions. Informing others about: #%s" % (len(block.transactions), block.hash[:5]))
        # broadcast the new block to all nodes.
        for node in self.nodes:
            if node == self.node_identifier: continue
            requests.post(f'http://localhost:{node}/inform/block', json=block.encode())

    def new_transaction(self, sender, recipient, amount):
        """ Add this transaction to the transaction mempool. We will try
        to include this transaction in the next block until it succeeds.
        """
        self.current_transactions.append(Transaction(sender, recipient, amount))