#!/usr/bin/env python3

from sys import argv
import requests
import codecs
import time

ADDRESS = "0xc304b48cC18036942bc0d14Ce0408d208db8a0C5"
BASE_URL = "https://api-goerli.etherscan.io/api?module=account&action=txlist&address=%s&startblock=0&endblock=99999999&page=1&offset=200&sort=asc" % ADDRESS


def _fetch_all():
    body = requests.get(BASE_URL).json()
    if body.get('status', '0') != "1":
        if 'Max rate limit reached' in body.get('result', ''):
            return None  # automatically retry
        raise Exception("returned status != 1 " + str(body))
    return body


def resilient_fetch():
    for _ in range(3):
        result = _fetch_all()
        if result is not None:
            return result
        print('Hold on, retrying...')
        time.sleep(5)
    raise Exception(
        "Unable to fetch from API. Please wait ~5 seconds and retry")


if __name__ == '__main__':
    if len(argv) != 2:
        raise Exception("Usage: python3 tester-p1a.py email@id.com")
    STUDENT_EMAIL = argv[1].strip().lower()

    all_txns = resilient_fetch()
    for txn in all_txns['result']:
        data = txn.get('input', '')
        data = data.strip('0x')
        try:
            data = str(codecs.decode(data, 'hex'), 'utf-8')
        except UnicodeDecodeError:
            continue
        if data.strip().lower() == STUDENT_EMAIL:
            print("Email present: True")
            if int(txn['value']) >= 500000000000000:
                print("Txn amount: sufficient")
                print("Result: test passed")
            else:
                print("Txn amount: insufficient")
                print("Result: test failed")
            break
    else:
        print("Email present: false")
        print("Result: test failed")
