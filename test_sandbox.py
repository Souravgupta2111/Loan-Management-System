import urllib.request
import json

req = urllib.request.Request('https://api.sandbox.co.in/authenticate', method='POST')
req.add_header('x-api-key', 'key_live_a3040e9faa71465e901ce33a588378db')
req.add_header('x-api-version', '1.0')
req.add_header('Content-Type', 'application/json')
req.add_header('Accept', 'application/json')

data = json.dumps({"secret": "secret_live_9af8b6ea84f04b4bb83e5b3a1c97b988"}).encode('utf-8')

try:
    with urllib.request.urlopen(req, data=data) as response:
        print(response.read().decode('utf-8'))
except urllib.error.HTTPError as e:
    print(f"HTTP Error: {e.code}")
    print(e.read().decode('utf-8'))
