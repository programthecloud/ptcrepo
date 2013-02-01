"""
Python auction server.  Requires the `restclient` and `web.py` libraries.

Usage: python server.py localhostname:port replica1:port replica2:port ...
"""
from threading import Lock
import time
import restclient
import web
import sys

urls = (
    '/start_auction', 'start_auction',
    '/bid', 'bid',
    '/status', 'status',
    '/winner', 'winner',
    '/rst', 'rst',
)

# Dictionary keyed by auction name, containing {bid, agent, end_time} dict
# tracking the highest bidder.
auctions = {}
auction_lock = Lock()  # CherryPy is multithreaded, so we need synchronization


def current_time():
    return int(time.time())


def broadcast(path, params, async=True):
    if "is_broadcast" in params:  # Don't rebroadcast a message
        return
    for replica in sys.argv[2:]:
        params["is_broadcast"] = 1
        restclient.POST("http://" + replica + '/' + path, params, async=async)


class start_auction:
    def POST(self):
        params = web.input()
        name = params.name
        end_time = int(params.end_time)
        with auction_lock:
            if name not in auctions and end_time >= current_time():
                auctions[name] = {
                    'bid': 0,
                    'bidder': "",
                    'end_time': end_time,
                    'bid_timestamp': sys.maxint
                }
                broadcast("start_auction", params, async=False)


class bid:
    def POST(self):
        params = web.input()
        name = params.name
        agent = int(params.agent)
        bid = int(params.bid)
        params.timestamp = int(params.get("timestamp", current_time()))
        with auction_lock:
            # start_auction is synchronous, so we should know about the auction
            auction = auctions[name]
            if params.timestamp < auction['end_time']:
                higher_bid = (bid > auction['bid'])
                same_bid = (bid == auction['bid'])
                earlier_time = (params.timestamp < auction['bid_timestamp'])
                same_time = (params.timestamp == auction['bid_timestamp'])
                higher_id = (agent > auction['bidder'])
                replicated = len(sys.argv[2:]) > 0
                # Unfair tie-breaking, which only applies when the service is replicated
                if higher_bid or (same_bid and replicated and (earlier_time or (same_time and higher_id))):
                    auction['bid'] = bid
                    auction['bidder'] = agent
                    auction['bid_timestamp'] = params.timestamp
                    broadcast("bid", params)


class status:
    def GET(self):
        name = web.input().name
        if name in auctions and auctions[name]['bid'] > 0:
            return auctions[name]['bidder']
        else:
            return "UNKNOWN"


class winner:
    def GET(self):
        name = web.input().name
        if name in auctions and auctions[name]['end_time'] < current_time():
            return auctions[name]['bidder']
        else:
            return "UNKNOWN"


class rst:
    def POST(self):
        with auction_lock:
            auctions.clear()


if __name__ == "__main__":
    app = web.application(urls, globals())
    app.internalerror = lambda: web.ok("")  # Return 200, even for errors
    app.run()
