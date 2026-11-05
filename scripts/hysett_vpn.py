#!/usr/bin/env python3
import sys, os, json, base64, urllib.request, urllib.parse, subprocess, shutil, socket, time

CONF_DIR = os.path.expanduser("~/.config/hypr/scripts")
SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_sub.txt")
STATE_FILE = os.path.join(CONF_DIR, "vpn_state.json")
SB_CONF = os.path.join(CONF_DIR, "singbox_vpn.json")

RU_DOMAIN_SUFFIXES = [
    "ru", ".ru", "su", ".su", "xn--p1ai", ".xn--p1ai", "by", ".by", "kz", ".kz",
    "yandex.com", "yandex.net", "ya.ru", "vk.com", "vkuseraudio.net", "userapi.com",
    "gosuslugi.ru", "sberbank.ru", "sber.ru", "tbank.ru", "tinkoff.ru",
    "ozon.ru", "ozonusercontent.com", "wb.ru", "wildberries.ru",
    "mail.ru", "avito.ru", "2gis.com", "kinopoisk.ru", "rutube.ru", "dzen.ru"
]

def read_sub_url():
    if os.path.exists(SUB_FILE):
        with open(SUB_FILE, "r") as f:
            u = f.read().strip()
            if u: return u
    return ""

def write_sub_url(u):
    with open(SUB_FILE, "w") as f:
        f.write(u.strip() + "\n")
    os.chmod(SUB_FILE, 0o600)

def load_state():
    st = {"server_name": "StealthSurf VPN", "ru_direct": True, "port": 2080}
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r") as f:
                st.update(json.load(f))
        except Exception:
            pass
    if "url" in st:
        if not os.path.exists(SUB_FILE) and st["url"]:
            write_sub_url(st["url"])
        del st["url"]
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    if "url" in st: del st["url"]
    with open(STATE_FILE, "w") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)

def parse_uri(uri):
    u = urllib.parse.urlsplit(uri)
    scheme = u.scheme.lower()
    name = urllib.parse.unquote(u.fragment or "StealthSurf Server").strip()
    q = dict(urllib.parse.parse_qsl(u.query))
    host = u.hostname or ""
    port = int(u.port or 443)

    if scheme == "vless":
        ob = {
            "type": "vless", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": u.username or "",
            "packet_encoding": "xudp"
        }
        if q.get("flow"): ob["flow"] = q["flow"]
    elif scheme == "trojan":
        ob = {"type": "trojan", "tag": "proxy", "server": host, "server_port": port, "password": u.username or ""}
    elif scheme in ("hy2", "hysteria2"):
        ob = {"type": "hysteria2", "tag": "proxy", "server": host, "server_port": port, "password": u.username or ""}
    elif scheme == "ss":
        userinfo = u.username or ""
        if ":" not in userinfo:
            pad = len(userinfo) % 4
            if pad: userinfo += "=" * (4 - pad)
            try: userinfo = base64.urlsafe_b64decode(userinfo).decode("utf-8")
            except Exception: pass
        method, _, pw = userinfo.partition(":")
        ob = {"type": "shadowsocks", "tag": "proxy", "server": host, "server_port": port, "method": method, "password": pw}
    else:
        return None, None

    sec = q.get("security", "tls" if scheme in ("trojan", "hy2", "hysteria2") else "none")
    if sec in ("tls", "reality"):
        tls = {
            "enabled": True,
            "server_name": q.get("sni", q.get("peer", host)),
            "utls": {"enabled": True, "fingerprint": q.get("fp", "chrome")}
        }
        if sec == "reality":
            tls["reality"] = {"enabled": True, "public_key": q.get("pbk", ""), "short_id": q.get("sid", "")}
        ob["tls"] = tls

    net_type = q.get("type", "tcp")
    if net_type == "ws":
        ob["transport"] = {"type": "ws", "path": q.get("path", "/"), "headers": {"Host": q.get("host", host)}}
    elif net_type == "grpc":
        ob["transport"] = {"type": "grpc", "service_name": q.get("serviceName", "")}
    return name, ob

def build_config(outbound, ru_direct):
    # Совместимо с sing-box 1.11 .. 1.14+ (action: "sniff" в route.rules вместо удаленных полей в inbound)
    clean_ob = dict(outbound)
    clean_ob["tag"] = "proxy"
    rules = [
        {"action": "sniff"},
        {"ip_is_private": True, "outbound": "direct"}
    ]
    if ru_direct:
        rules.append({"domain_suffix": RU_DOMAIN_SUFFIXES, "outbound": "direct"})
    return {
        "log": {"level": "warn"},
        "inbounds": [
            {
                "type": "mixed",
                "tag": "mixed-in",
                "listen": "127.0.0.1",
                "listen_port": 2080
            }
        ],
        "outbounds": [
            clean_ob,
            {"type": "direct", "tag": "direct"}
        ],
        "route": {
            "rules": rules,
            "final": "proxy"
        }
    }

def fetch_subscription():
    st = load_state()
    url = read_sub_url()
    if not url:
        return st.get("server_name", "StealthSurf VPN")
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    req = urllib.request.Request(url, headers={"User-Agent": "v2rayN/6.45 sing-box/1.14"})
    with opener.open(req, timeout=10) as r:
        raw = r.read().decode("utf-8", errors="ignore").strip()

    if "://" not in raw and not raw.startswith("{"):
        pad = len(raw) % 4
        if pad: raw += "=" * (4 - pad)
        try: raw = base64.b64decode(raw).decode("utf-8", errors="ignore")
        except Exception:
            try: raw = base64.urlsafe_b64decode(raw).decode("utf-8", errors="ignore")
            except Exception: pass

    if raw.startswith("{"):
        data = json.loads(raw)
        for ob in data.get("outbounds", []):
            if ob.get("type") in ("vless", "trojan", "hysteria2", "shadowsocks", "vmess"):
                ob["tag"] = "proxy"
                st["outbound"] = ob
                st["server_name"] = ob.get("server", "StealthSurf JSON")
                save_state(st)
                with open(SB_CONF, "w") as f:
                    json.dump(build_config(ob, st.get("ru_direct", True)), f, indent=2)
                return st["server_name"]

    for line in raw.splitlines():
        line = line.strip()
        if any(line.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
            name, ob = parse_uri(line)
            if ob:
                st["outbound"] = ob
                st["server_name"] = name
                save_state(st)
                with open(SB_CONF, "w") as f:
                    json.dump(build_config(ob, st.get("ru_direct", True)), f, indent=2)
                return name
    save_state(st)
    return st.get("server_name", "StealthSurf VPN")

def wait_port(port, timeout=3.5):
    t0 = time.time()
    while time.time() - t0 < timeout:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(0.1)
    return False

def set_desktop_proxy(enable):
    if enable:
        for schema, key, val in [
            ("org.gnome.system.proxy", "mode", "manual"),
            ("org.gnome.system.proxy.http", "host", "127.0.0.1"),
            ("org.gnome.system.proxy.http", "port", "2080"),
            ("org.gnome.system.proxy.https", "host", "127.0.0.1"),
            ("org.gnome.system.proxy.https", "port", "2080"),
            ("org.gnome.system.proxy.socks", "host", "127.0.0.1"),
            ("org.gnome.system.proxy.socks", "port", "2080"),
            ("org.gnome.system.proxy", "ignore-hosts", "['localhost', '127.0.0.0/8', '::1', '*.ru', '*.su', '*.xn--p1ai', '*vk.com', '*yandex.net', '*ozon.ru', '*wb.ru', '*sberbank.ru', '*tbank.ru', '*gosuslugi.ru']")
        ]:
            subprocess.run(["gsettings", "set", schema, key, val], stderr=subprocess.DEVNULL)
        # Также синхронизируем KDE kioslaverc (так как XDG_CURRENT_DESKTOP=KDE)
        if shutil.which("kwriteconfig6"):
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "ProxyType", "1"], stderr=subprocess.DEVNULL)
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "httpProxy", "http://127.0.0.1:2080"], stderr=subprocess.DEVNULL)
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "httpsProxy", "http://127.0.0.1:2080"], stderr=subprocess.DEVNULL)
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "socksProxy", "socks://127.0.0.1:2080"], stderr=subprocess.DEVNULL)
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "NoProxyFor", "localhost,127.0.0.1,.ru,.su,.xn--p1ai,vk.com,yandex.ru,ozon.ru,wb.ru,gosuslugi.ru"], stderr=subprocess.DEVNULL)
    else:
        subprocess.run(["gsettings", "set", "org.gnome.system.proxy", "mode", "none"], stderr=subprocess.DEVNULL)
        if shutil.which("kwriteconfig6"):
            subprocess.run(["kwriteconfig6", "--file", "kioslaverc", "--group", "Proxy Settings", "--key", "ProxyType", "0"], stderr=subprocess.DEVNULL)

def stop_vpn():
    set_desktop_proxy(False)
    subprocess.run(["pkill", "-f", "sing-box.*singbox_vpn.json"], stderr=subprocess.DEVNULL)

def start_vpn():
    stop_vpn()
    st = load_state()
    if "outbound" not in st or not os.path.exists(SB_CONF):
        try: fetch_subscription()
        except Exception as e: print("Fetch error:", e, file=sys.stderr)
        st = load_state()
    if "outbound" in st:
        with open(SB_CONF, "w") as f:
            json.dump(build_config(st["outbound"], st.get("ru_direct", True)), f, indent=2)
    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    if os.path.exists(sb_bin) and os.path.exists(SB_CONF):
        subprocess.Popen([sb_bin, "run", "-c", SB_CONF], stdout=open("/tmp/singbox_vpn.log", "w"), stderr=subprocess.STDOUT)
        if wait_port(2080, 3.5):
            set_desktop_proxy(True)
            return True
        else:
            stop_vpn()
    return False

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "update":
        if len(sys.argv) > 2 and sys.argv[2].strip():
            write_sub_url(sys.argv[2])
        print(fetch_subscription())
    elif cmd == "get_url":
        print(read_sub_url())
    elif cmd == "set_ru":
        st = load_state()
        st["ru_direct"] = (sys.argv[2] == "1")
        save_state(st)
        if "outbound" in st:
            with open(SB_CONF, "w") as f:
                json.dump(build_config(st["outbound"], st["ru_direct"]), f, indent=2)
        if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
            start_vpn()
    elif cmd == "start": start_vpn()
    elif cmd == "stop": stop_vpn()
