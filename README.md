# GIchat 3.0

The definitive version of GIchat, after the Tkinter client of 1.0, and PyQt client of 2.0, client 3.0 now uses Godot Engine.
The server uses raw Python TCP sockets, JSON for data transfer, and YAML for configuration.

The server and client are on separate branches in this repo, [client](https://github.com/HazmatPants/GIchat/tree/client) and [server](https://github.com/HazmatPants/GIchat/tree/server).

## Current Features
- Account system
- BBCode formatting
- Custom MOTD/welcome messages when joining a server

## To-Do Features
- Encryption
- File transfers
- Profile pictures, bios, nicknames, etc.
- Commands (e.g. /nick, /kick, /who)
- Rate limiting/spam protection
- Account limits per IP address

## Notes
- There is currently **no encryption**. Messages are sent as plaintext JSON.
