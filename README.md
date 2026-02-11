# GIchat Server

## Installation

Make sure you have the latest version of Python.
GIchat has only been tested on Linux as of writing this.

1. Clone the server
```sh
$ git clone https://github.com/HazmatPants/GIchat.git --branch server

$ cd GIchat
```

2. Create a Python virtual environment
```sh
# create venv
$ python -m venv .venv

# use the new venv
$ source .venv/bin/activate

# check python path
$ which python
/home/archie/GIchat-server/.venv/bin/python
```

3. Install dependencies
```sh
$ pip install -r requirements.txt
```

4. Run the server
```sh
$ ./server.py
```

The server will create the default config file and exit, you should read the file and edit it to how you want.

Users on your local network should be able to join now. For users on other networks, port forwarding is required.

Whenever you want to run the server, you must use the venv. You can create a Bash script for this:
```bash
#!/usr/bin/env bash

source .venv/bin/activate

python server.py
```

Make it executable:
```sh
$ chmod +x start-server.sh
```

Run it:
```sh
$ ./start-server.sh
```
