#!/usr/bin/env python

import time
import socket
import threading
import json
import yaml
import random
import bcrypt
import base64
import requests
from colorama import Fore, Style
import colorama
import os

colorama.init()

HOST = ""
PORT = 8765

if os.path.exists("config.yaml"):
    with open("config.yaml", "r", encoding="utf-8") as f:
        CONFIG = yaml.safe_load(f)
else:
    with open("config.yaml", "w", encoding="utf-8") as f:
        config_str = (
        "--- GIchat Server Configuration\n"
        "# Refer to https://github.com/HazmatPants/GIchat/wiki/config.yaml\n"
        "# for configuration options\n"
        )
        f.write(config_str)

        print(Fore.YELLOW + f"[!] Config file not found, it was created. Please read it.", Style.RESET_ALL)
        exit()

if os.path.exists("accounts.yaml"):
    with open("accounts.yaml", "r", encoding="utf-8") as f:
        ACCOUNTS = yaml.safe_load(f)
        if ACCOUNTS is None:
            ACCOUNTS = {}
else:
    with open("accounts.yaml", "w", encoding="utf-8") as f:
        f.write("---")
def load_server_icon(path="server_icon.png") -> str | None:
    try:
        with open(path, "rb") as f:
            return base64.b64encode(f.read()).decode("ascii")
    except FileNotFoundError:
        return None

SERVER_ICON = load_server_icon()

if len(SERVER_ICON) > 100_000:
    print(Fore.YELLOW + f"[!] Server icon is quite large ({round(len(SERVER_ICON) / 1024)} KiB), a size of 256x256 is recommended", Style.RESET_ALL)

r = requests.get("https://icanhazip.com")
if r.status_code == 200:
    PUB_ADDR = r.text

MOTDS = CONFIG.get("motd", [])

ALLOWED_BBCODE = CONFIG.get("allowed_bbcode", [])

tcp_sock = socket.create_server((HOST, PORT))
tcp_sock.listen()

CLIENTS = {}
CLIENTS_LOCK = threading.Lock()

def main() -> None:
    print(f"[i] Server listening on port {PORT}")

    while True:
        conn, addr = tcp_sock.accept()

        threading.Thread(
            target=handle_client,
            args=(conn, addr),
            daemon=True
        ).start()

def get_username(conn) -> str | None:
    send_json(conn, {
        "type": "request",
        "body": "username"
    })

    data = recv_json(conn)
    if not data or data.get("type") != "response":
        return None

    username = data.get("body", "").strip()

    if not username:
        send_json(conn, {
            "type": "error",
            "body": "Invalid Username"
        })
        return None

    if any(substring in username for substring in CONFIG.get("username_char_blacklist", "")):
        send_json(conn, {
            "type": "error",
            "body": "Invalid Username (contains forbidden characters)"
        })
        return None

    with CLIENTS_LOCK:
        if username in CLIENTS.values():
            send_json(conn, {
                "type": "error",
                "body": "Username Taken"
            })
            return None

    return username

def handle_client(conn, addr):
    try:
        username = get_username(conn)
        if not username:
            return

        send_json(conn, {
            "type": "server_info",
            "name": CONFIG["name"],
            "description": CONFIG["description"],
            "login_required": CONFIG["login_required"],
            "icon": SERVER_ICON,
            "addr": PUB_ADDR,
            "port": PORT
        })

        if len(CLIENTS) >= CONFIG.get("max_users", 10):
            send_json(conn, {
                "type": "error",
                "body": "Server Full"
            })
            return

        if CONFIG["login_required"]:
            send_json(conn, {
                "type": "request",
                "body": "auth"
            })

            msg = recv_json(conn)

            if not msg:
                conn.close()
                return

            if msg.get("type") != "auth":
                send_json(conn, {
                    "type": "error",
                    "body": "Login Required"
                })
                conn.close()
                return

            username = msg.get("user")
            passwd = msg.get("pass")

            acc = ACCOUNTS.get(username)
            if acc:
                if not bcrypt.checkpw(passwd.encode("utf-8"), acc["password"].encode("utf-8")):
                    send_json(conn, {
                        "type": "error",
                        "body": "Invalid Credentials"
                    })
                    conn.close()
                    return
            else:
                passwd = bcrypt.hashpw(passwd.encode("utf-8"), bcrypt.gensalt()).decode("utf-8")
                ACCOUNTS[username] = {"password": passwd, "is_admin": False}
                with open("accounts.yaml", "w") as f:
                    yaml.dump(ACCOUNTS, f)

                    send_json(conn, {
                        "type": "success",
                        "body": "Account Registered! Please reconnect and login."
                    })
                    conn.close()
                    return

        with CLIENTS_LOCK:
            CLIENTS[conn] = username
            users = list(CLIENTS.values())

        send_json(conn, {
            "type": "users",
            "users": users
        })

        send_json(conn, {
            "type": "motd",
            "body": get_random_motd()
        })

        print(f"[+] {username} connected from {addr}")
        broadcast_json({
            "type": "join",
            "user": username,
            "body": f">>> {username} joined the chat!\n"
        })

        while True:
            message = recv_json(conn)
            if not message:
                return

            match message["type"]:
                case "message":
                    print(f"[i] {username} ({message['type']}): {message['body']}")

                    if CONFIG["login_required"]:
                        if ACCOUNTS[username].get("is_admin", false) and CONFIG.get("admin_ignore_bbcode_whitelist", true):
                            clean = message["body"]
                        else:
                            clean = sanitize_bbcode(message["body"])
                    else:
                        clean = sanitize_bbcode(message["body"])

                    broadcast_json({
                        "type": "message",
                        "user": username,
                        "body": clean
                        })

                case "ping":
                    send_json(conn, {
                        "type": "ping",
                        "body": time.time()
                    })
    finally:
        with CLIENTS_LOCK:
            username = CLIENTS.pop(conn, None)

        conn.close()

        if username:
            print(f"[-] {username} disconnected")
            broadcast_json({
                "type": "leave",
                "user": username,
                "body": f">>> {username} left the chat!\n"
            })

def broadcast(message: str, exclude=None) -> None:
    if exclude is None:
        exclude = []

    dead = []

    with CLIENTS_LOCK:
        for client in CLIENTS:
            if client in exclude:
                continue
            try:
                client.sendall(message.encode("utf-8"))
            except OSError:
                dead.append(client)

        for client in dead:
            CLIENTS.pop(client, None)
            client.close()

def broadcast_json(data: dict, exclude=None) -> None:
    if exclude is None:
        exclude = []

    dead = []

    with CLIENTS_LOCK:
        for client in CLIENTS:
            if client in exclude:
                continue
            try:
                send_json(client, data)
            except OSError:
                dead.append(client)

        for client in dead:
            CLIENTS.pop(client, None)
            client.close()

def recv_line(conn) -> bytes | None:
    data = b""
    while b"\n" not in data:
        chunk = conn.recv(1024)
        if not chunk:
            return None
        data += chunk
    return data

def send_json(conn, payload: dict) -> None:
    conn.sendall((json.dumps(payload) + "\n").encode("utf-8"))

def recv_json(conn) -> dict | None:
    data = b""
    while b"\n" not in data:
        chunk = conn.recv(1024)
        if not chunk:
            return None
        data += chunk

    line = data.split(b"\n", 1)[0]

    try:
        return json.loads(line.decode("utf-8"))
    except json.JSONDecodeError:
        return None

def get_random_motd() -> str:
    if not MOTDS:
        return "Welcome!"
    return random.choice(MOTDS)

def sanitize_bbcode(text: str) -> str:
    out = []
    i = 0
    length = len(text)

    while i < length:
        if text[i] == "[":
            end = text.find("]", i)
            if end == -1:
                out.append(text[i])
                i += 1
                continue

            tag = text[i+1:end]
            base = tag.split("=", 1)[0]

            if base.lower() in ALLOWED_BBCODE:
                out.append(f"[{tag}]")

            i = end + 1
        else:
            out.append(text[i])
            i += 1

    return "".join(out)

if __name__ == "__main__":
    main()
