#!/usr/bin/env python3
import base64
import hashlib
import hmac
import http.cookies
import http.server
import ipaddress
import json
import os
import re
import secrets
import subprocess
import sys
import tempfile
import threading
import time
import urllib.parse

STATE = "/var/lib/vtt-dashboard/config.json"
SYNC_STATUS = "/var/lib/vtt-sync/status.json"
WIFI = "wlan-upstream"
SERVICES = ("foundry-vtt", "nginx", "cage-tty1")
ITERATIONS = 310_000
SESSION_TTL = 8 * 60 * 60
LOGIN_WINDOW = 5 * 60
LOGIN_LIMIT = 5
sessions = {}
login_attempts = {}
lock = threading.Lock()
status_lock = threading.Lock()
status_cache = {"time": 0, "value": None}


def valid_pin(pin):
    return isinstance(pin, str) and re.fullmatch(r"[0-9]{6,12}", pin) is not None


def valid_sync_direction(direction):
    return direction in ("pull", "push")


def hash_pin(pin, salt=None):
    salt = salt or secrets.token_bytes(16)
    digest = hashlib.pbkdf2_hmac("sha256", pin.encode(), salt, ITERATIONS)
    return {"salt": base64.b64encode(salt).decode(), "hash": base64.b64encode(digest).decode()}


def check_pin(pin, saved):
    try:
        salt = base64.b64decode(saved["salt"], validate=True)
        expected = base64.b64decode(saved["hash"], validate=True)
        actual = hashlib.pbkdf2_hmac("sha256", pin.encode(), salt, ITERATIONS)
        return hmac.compare_digest(actual, expected)
    except (KeyError, TypeError, ValueError):
        return False


def load_config():
    try:
        with open(STATE, encoding="utf-8") as f:
            config = json.load(f)
        if not isinstance(config, dict):
            raise ValueError("configuration is not an object")
        return config
    except FileNotFoundError:
        return {}


def save_config(config):
    os.makedirs(os.path.dirname(STATE), mode=0o700, exist_ok=True)
    fd, path = tempfile.mkstemp(dir=os.path.dirname(STATE))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump(config, f, separators=(",", ":"))
            f.flush()
            os.fsync(f.fileno())
        os.chmod(path, 0o600)
        os.replace(path, STATE)
    finally:
        if os.path.exists(path):
            os.unlink(path)


def run(args, timeout=8, check=True):
    result = subprocess.run(args, capture_output=True, text=True, timeout=timeout, check=False)
    if check and result.returncode:
        raise RuntimeError(f"{args[0]} failed")
    return result.stdout.strip(), result.returncode


def wpa(*args):
    output, _ = run(["wpa_cli", "-i", WIFI, *args])
    if not output.splitlines() or output.splitlines()[-1] != "OK":
        raise RuntimeError("wpa_cli failed")
    return output


def service_status(name):
    output, code = run(["systemctl", "is-active", name], timeout=3, check=False)
    return output or ("active" if code == 0 else "unknown")


def system_status():
    config = load_config()
    exists = os.path.exists(f"/sys/class/net/{WIFI}")
    ssid = None
    addresses = []
    default_route = False
    internet = False
    if exists:
        output, _ = run(["iw", "dev", WIFI, "link"], timeout=3, check=False)
        match = re.search(r"^\s*SSID:\s*(.*)$", output, re.MULTILINE)
        ssid = match.group(1) if match else None
        output, code = run(["ip", "-json", "address", "show", "dev", WIFI], timeout=3, check=False)
        if code == 0:
            for interface in json.loads(output or "[]"):
                addresses.extend(f'{a["local"]}/{a["prefixlen"]}' for a in interface.get("addr_info", []))
        _, code = run(["ip", "route", "show", "default", "dev", WIFI], timeout=3, check=False)
        default_route = code == 0 and bool(_)
    _, code = run(["ping", "-c", "1", "-W", "1", "1.1.1.1"], timeout=3, check=False)
    internet = code == 0
    return {
        "setupRequired": "pin" not in config,
        "onlineUrl": config.get("onlineUrl", ""),
        "uplink": {"interface": WIFI, "exists": exists, "ssid": ssid, "addresses": addresses,
                   "status": "connected" if ssid else "disconnected",
                   "defaultRoute": default_route, "internet": internet},
        "services": {name: service_status(name) for name in SERVICES},
        "ap": {"interface": "wlan0", "ssid": os.environ.get("VTT_AP_SSID", "VTT-Gaming"),
               "exists": os.path.exists("/sys/class/net/wlan0"),
               "status": service_status("manual-hostapd")},
    }


def sync_status():
    try:
        with open(SYNC_STATUS, encoding="utf-8") as f:
            value = json.load(f)
        return value if isinstance(value, dict) else {"state": "unknown"}
    except (FileNotFoundError, OSError, ValueError, json.JSONDecodeError):
        return {"state": "unknown"}


def save_sync_status(direction, state, message):
    os.makedirs(os.path.dirname(SYNC_STATUS), mode=0o700, exist_ok=True)
    fd, path = tempfile.mkstemp(dir=os.path.dirname(SYNC_STATUS))
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"direction": direction, "state": state, "message": message,
                       "timestamp": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}, f,
                      separators=(",", ":"))
        os.chmod(path, 0o600)
        os.replace(path, SYNC_STATUS)
    finally:
        if os.path.exists(path):
            os.unlink(path)


def sync_active():
    return any(service_status(f"vtt-sync@{direction}.service") in ("active", "activating")
               for direction in ("pull", "push"))


def status(authenticated=False):
    with status_lock:
        if time.time() - status_cache["time"] > 2:
            status_cache.update(time=time.time(), value=system_status())
        value = dict(status_cache["value"])
    value["authenticated"] = authenticated
    value["sync"] = sync_status()
    return value


class Handler(http.server.BaseHTTPRequestHandler):
    server_version = "vtt-dashboard/1"

    def json_response(self, code, value, cookie=None):
        body = json.dumps(value, separators=(",", ":")).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        if cookie:
            self.send_header("Set-Cookie", cookie)
        self.end_headers()
        self.wfile.write(body)

    def body(self):
        if self.headers.get_content_type() != "application/json":
            raise ValueError("application/json required")
        try:
            length = int(self.headers.get("Content-Length", "0"))
        except ValueError as e:
            raise ValueError("invalid content length") from e
        if length < 0 or length > 65_536:
            raise ValueError("request body too large")
        value = json.loads(self.rfile.read(length) or b"{}")
        if not isinstance(value, dict):
            raise ValueError("JSON object required")
        return value

    def token(self):
        try:
            cookie = http.cookies.SimpleCookie(self.headers.get("Cookie", ""))
            return cookie["vtt_session"].value
        except (KeyError, http.cookies.CookieError):
            return None

    def authenticated(self):
        token = self.token()
        now = time.time()
        with lock:
            expiry = sessions.get(token, 0)
            if expiry <= now:
                sessions.pop(token, None)
                return False
            return True

    def require_auth(self):
        if self.authenticated():
            return True
        self.json_response(401, {"error": "authentication required"})
        return False

    def login_allowed(self, failed=False):
        source = self.headers.get("X-Real-IP", self.client_address[0])
        now = time.time()
        with lock:
            attempts = [stamp for stamp in login_attempts.get(source, []) if now - stamp < LOGIN_WINDOW]
            if failed:
                attempts.append(now)
            login_attempts[source] = attempts
            return len(attempts) < LOGIN_LIMIT

    def do_GET(self):
        try:
            if self.path == "/api/status":
                self.json_response(200, status(self.authenticated()))
            elif self.path == "/api/wifi/scan":
                if not self.require_auth():
                    return
                wpa("scan")
                time.sleep(10)
                output, _ = run(["wpa_cli", "-i", WIFI, "scan_results"])
                networks = []
                for line in output.splitlines():
                    fields = line.split("\t", 4)
                    if len(fields) == 5 and fields[1].isdigit():
                        networks.append({"bssid": fields[0], "frequency": int(fields[1]),
                                         "signal": int(fields[2]), "security": fields[3], "ssid": fields[4]})
                self.json_response(200, {"networks": networks})
            else:
                self.json_response(404, {"error": "not found"})
        except (RuntimeError, subprocess.TimeoutExpired, ValueError, OSError, json.JSONDecodeError) as e:
            self.json_response(500, {"error": str(e)})

    def do_POST(self):
        try:
            try:
                data = self.body()
            except (ValueError, json.JSONDecodeError) as e:
                return self.json_response(400, {"error": str(e)})
            if self.path == "/api/setup":
                pin = data.get("pin")
                if not valid_pin(pin):
                    return self.json_response(400, {"error": "PIN must be 6-12 digits"})
                try:
                    source = ipaddress.ip_address(self.headers.get("X-Real-IP", ""))
                except ValueError:
                    return self.json_response(403, {"error": "setup not allowed from this address"})
                if not (source.is_loopback or source == ipaddress.ip_address("192.168.4.1")):
                    return self.json_response(403, {"error": "setup not allowed from this address"})
                with lock:
                    config = load_config()
                    if "pin" in config:
                        return self.json_response(409, {"error": "setup already completed"})
                    config["pin"] = hash_pin(pin)
                    save_config(config)
                    token = secrets.token_urlsafe(32)
                    sessions[token] = time.time() + SESSION_TTL
                cookie = f"vtt_session={token}; Path=/; HttpOnly; SameSite=Strict; Max-Age={SESSION_TTL}"
                return self.json_response(201, {"ok": True}, cookie)

            if self.path == "/api/login":
                if not self.login_allowed():
                    return self.json_response(429, {"error": "too many attempts; try again later"})
                pin = data.get("pin")
                config = load_config()
                if not valid_pin(pin) or "pin" not in config or not check_pin(pin, config["pin"]):
                    self.login_allowed(failed=True)
                    return self.json_response(401, {"error": "invalid PIN"})
                with lock:
                    login_attempts.pop(self.headers.get("X-Real-IP", self.client_address[0]), None)
                token = secrets.token_urlsafe(32)
                with lock:
                    sessions[token] = time.time() + SESSION_TTL
                cookie = f"vtt_session={token}; Path=/; HttpOnly; SameSite=Strict; Max-Age={SESSION_TTL}"
                return self.json_response(200, {"ok": True}, cookie)

            if not self.require_auth():
                return
            if self.path == "/api/logout":
                with lock:
                    sessions.pop(self.token(), None)
                cookie = "vtt_session=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0"
                return self.json_response(200, {"ok": True}, cookie)

            if self.path == "/api/sync":
                direction = data.get("direction")
                if not valid_sync_direction(direction):
                    return self.json_response(400, {"error": "direction must be pull or push"})
                with lock:
                    if sync_active():
                        return self.json_response(409, {"error": "sync already active"})
                    save_sync_status(direction, "queued", "Sync queued")
                    try:
                        run(["systemctl", "--no-block", "start", f"vtt-sync@{direction}.service"], timeout=5)
                    except (RuntimeError, subprocess.TimeoutExpired, OSError):
                        save_sync_status(direction, "failed", "Could not start sync")
                        raise
                return self.json_response(202, {"ok": True, "direction": direction})

            if self.path == "/api/wifi/connect":
                ssid, password = data.get("ssid"), data.get("password")
                if not isinstance(ssid, str) or not 1 <= len(ssid) <= 32:
                    return self.json_response(400, {"error": "SSID must be 1-32 characters"})
                if not isinstance(password, str) or (password and not 8 <= len(password) <= 63):
                    return self.json_response(400, {"error": "password must be empty or 8-63 characters"})
                output, _ = run(["wpa_cli", "-i", WIFI, "add_network"])
                network_id = next((line for line in reversed(output.splitlines()) if line.isdigit()), None)
                if network_id is None:
                    raise RuntimeError("could not add WiFi network")
                try:
                    wpa("set_network", network_id, "ssid", json.dumps(ssid))
                    if password:
                        wpa("set_network", network_id, "psk", json.dumps(password))
                    else:
                        wpa("set_network", network_id, "key_mgmt", "NONE")
                    wpa("select_network", network_id)
                    wpa("save_config")
                    wpa("reconnect")
                except Exception:
                    run(["wpa_cli", "-i", WIFI, "remove_network", network_id], check=False)
                    run(["wpa_cli", "-i", WIFI, "save_config"], check=False)
                    raise
                return self.json_response(200, {"ok": True, "networkId": int(network_id)})

            if self.path == "/api/wifi/disconnect":
                wpa("disable_network", "all")
                wpa("save_config")
                return self.json_response(200, {"ok": True})

            if self.path == "/api/online-url":
                url = data.get("url")
                if not isinstance(url, str) or len(url) > 2048:
                    return self.json_response(400, {"error": "valid http/https URL required"})
                parsed = urllib.parse.urlsplit(url) if url else None
                if parsed and (parsed.scheme not in ("http", "https") or not parsed.netloc):
                    return self.json_response(400, {"error": "valid http/https URL required"})
                with lock:
                    config = load_config()
                    if url:
                        config["onlineUrl"] = url
                    else:
                        config.pop("onlineUrl", None)
                    save_config(config)
                return self.json_response(200, {"ok": True})

            if self.path == "/api/service":
                name, action = data.get("name"), data.get("action")
                if name not in SERVICES or action != "restart":
                    return self.json_response(400, {"error": "invalid service or action"})
                run(["systemctl", "--no-block", action, name], timeout=5)
                return self.json_response(200, {"ok": True})

            if self.path == "/api/reboot":
                run(["systemctl", "--no-block", "reboot"], timeout=5)
                return self.json_response(200, {"ok": True})

            self.json_response(404, {"error": "not found"})
        except (RuntimeError, subprocess.TimeoutExpired, ValueError, OSError, json.JSONDecodeError) as e:
            self.json_response(500, {"error": str(e)})

    def log_message(self, format, *args):
        sys.stderr.write("%s - %s\n" % (self.address_string(), format % args))


def self_test():
    assert valid_pin("123456") and valid_pin("012345678901")
    assert not valid_pin("1234") and not valid_pin("123456a") and not valid_pin(123456)
    saved = hash_pin("9876", b"0123456789abcdef")
    assert check_pin("9876", saved) and not check_pin("9875", saved)
    assert valid_sync_direction("pull") and valid_sync_direction("push")
    assert not valid_sync_direction("Pull") and not valid_sync_direction(1)
    print("self-test passed")


if __name__ == "__main__":
    if sys.argv[1:] == ["--self-test"]:
        self_test()
    else:
        http.server.ThreadingHTTPServer(("127.0.0.1", 8787), Handler).serve_forever()
