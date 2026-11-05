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

def read_sub_urls():
    urls = []
    if os.path.exists(SUB_FILE):
        with open(SUB_FILE, "r", encoding="utf-8") as f:
            for line in f:
                u = line.strip()
                if u and u not in urls:
                    urls.append(u)
    return urls

def write_sub_urls(urls):
    clean = []
    for u in urls:
        u = u.strip()
        if u and u not in clean:
            clean.append(u)
    with open(SUB_FILE, "w", encoding="utf-8") as f:
        for u in clean:
            f.write(u + "\n")
    os.chmod(SUB_FILE, 0o600)

def load_state():
    st = {
        "server_name": "VPN",
        "ru_direct": True,
        "port": 2080,
        "selected_index": 0,
        "servers": []
    }
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                st.update(json.load(f))
        except Exception:
            pass
    if "url" in st:
        if st["url"]:
            cur = read_sub_urls()
            if st["url"] not in cur:
                cur.append(st["url"])
                write_sub_urls(cur)
        del st["url"]
    if not st["servers"] and "outbound" in st and isinstance(st["outbound"], dict):
        st["servers"] = [{"name": st.get("server_name", "Server 1"), "outbound": st["outbound"]}]
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    if "url" in st:
        del st["url"]
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)

def parse_uri(uri):
    u = urllib.parse.urlsplit(uri)
    scheme = u.scheme.lower()
    name = urllib.parse.unquote(u.fragment or "VPN Server").strip()
    q = dict(urllib.parse.parse_qsl(u.query))
    host = u.hostname or ""
    port = int(u.port or 443)
    if not host:
        return None, None

    if scheme == "vless":
        ob = {
            "type": "vless", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": urllib.parse.unquote(u.username or ""),
            "packet_encoding": "xudp"
        }
        if q.get("flow"):
            ob["flow"] = q["flow"]
    elif scheme == "trojan":
        ob = {"type": "trojan", "tag": "proxy", "server": host, "server_port": port, "password": urllib.parse.unquote(u.username or "")}
    elif scheme in ("hy2", "hysteria2"):
        ob = {"type": "hysteria2", "tag": "proxy", "server": host, "server_port": port, "password": urllib.parse.unquote(u.username or "")}
    elif scheme == "ss":
        userinfo = urllib.parse.unquote(u.username or "")
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
        if q.get("alpn"):
            tls["alpn"] = [x.strip() for x in q["alpn"].split(",") if x.strip()]
        if sec == "reality":
            tls["reality"] = {"enabled": True, "public_key": q.get("pbk", ""), "short_id": q.get("sid", "")}
        ob["tls"] = tls

    net_type = q.get("type", "tcp")
    if net_type == "ws":
        ob["transport"] = {"type": "ws", "path": q.get("path", "/"), "headers": {"Host": q.get("host", host)}}
    elif net_type == "grpc":
        ob["transport"] = {"type": "grpc", "service_name": q.get("serviceName", "")}
    elif net_type in ("http", "h2"):
        ob["transport"] = {"type": "http", "path": q.get("path", "/")}
    return name, ob

def has_cap_net_admin(sb_bin):
    try:
        out = subprocess.check_output(["getcap", sb_bin], text=True, stderr=subprocess.DEVNULL)
        return "cap_net_admin" in out
    except Exception:
        return False

def build_config(outbound, ru_direct, use_tun=False):
    clean_ob = dict(outbound)
    clean_ob["tag"] = "proxy"

    inbounds = [
        {
            "type": "mixed",
            "tag": "mixed-in",
            "listen": "127.0.0.1",
            "listen_port": 2080,
            "set_system_proxy": False
        }
    ]
    if use_tun:
        inbounds.insert(0, {
            "type": "tun",
            "tag": "tun-in",
            "interface_name": "singbox_tun0",
            "address": ["172.19.0.1/30", "fdfe:dcba:9876::1/126"],
            "mtu": 1400,
            "auto_route": True,
            "strict_route": False,
            "stack": "gvisor"
        })

    rules = [
        {"action": "sniff"},
        {"protocol": "dns", "action": "hijack-dns"},
        {"ip_is_private": True, "outbound": "direct"}
    ]
    if ru_direct:
        rules.append({"domain_suffix": RU_DOMAIN_SUFFIXES, "outbound": "direct"})

    return {
        "log": {"level": "info"},
        "dns": {
            "servers": [
                {"type": "https", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"},
                {"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}
            ],
            "rules": ([{"domain_suffix": RU_DOMAIN_SUFFIXES, "server": "dns-direct"}] if ru_direct else []),
            "strategy": "ipv4_only",
            "final": "dns-remote"
        },
        "inbounds": inbounds,
        "outbounds": [
            clean_ob,
            {"type": "direct", "tag": "direct"}
        ],
        "route": {
            "default_domain_resolver": "dns-direct",
            "auto_detect_interface": True,
            "rules": rules,
            "final": "proxy"
        }
    }

def parse_subscription_content(raw):
    found = []
    if "://" not in raw and not raw.startswith("{"):
        pad = len(raw) % 4
        if pad: raw += "=" * (4 - pad)
        try:
            raw = base64.b64decode(raw).decode("utf-8", errors="ignore")
        except Exception:
            try:
                raw = base64.urlsafe_b64decode(raw).decode("utf-8", errors="ignore")
            except Exception:
                pass

    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            for idx, ob in enumerate(data.get("outbounds", [])):
                if ob.get("type") in ("vless", "trojan", "hysteria2", "shadowsocks", "vmess"):
                    ob["tag"] = "proxy"
                    nm = ob.get("tag_name") or ob.get("server") or f"Server {idx+1}"
                    found.append({"name": nm, "outbound": ob})
        except Exception:
            pass
        return found

    for line in raw.splitlines():
        line = line.strip()
        if any(line.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
            name, ob = parse_uri(line)
            if ob:
                found.append({"name": name, "outbound": ob})
    return found

def fetch_subscriptions():
    st = load_state()
    urls = read_sub_urls()
    if not urls:
        return st

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    all_servers = []
    for u in urls:
        if any(u.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
            name, ob = parse_uri(u)
            if ob:
                all_servers.append({"name": name, "outbound": ob})
            continue
        for ua in ("v2rayN/6.45", "SFA/1.11.0 sing-box/1.11.0", "ClashMetaForAndroid/2.10.1"):
            try:
                req = urllib.request.Request(u, headers={"User-Agent": ua})
                with opener.open(req, timeout=10) as r:
                    raw = r.read().decode("utf-8", errors="ignore").strip()
                parsed = parse_subscription_content(raw)
                if parsed:
                    all_servers.extend(parsed)
                    break
            except Exception as e:
                print(f"Fetch error ({u}): {e}", file=sys.stderr)

    if all_servers:
        st["servers"] = all_servers
        idx = min(max(0, st.get("selected_index", 0)), len(all_servers) - 1)
        st["selected_index"] = idx
        st["server_name"] = all_servers[idx]["name"]
        st["outbound"] = all_servers[idx]["outbound"]
        save_state(st)
        sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
        with open(SB_CONF, "w", encoding="utf-8") as f:
            json.dump(build_config(st["outbound"], st.get("ru_direct", True), has_cap_net_admin(sb_bin)), f, indent=2)
    return st

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
    for _ in range(30):
        if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode != 0:
            break
        time.sleep(0.05)
    time.sleep(0.15)

def country_flag(cc):
    if not cc or len(cc) != 2 or not cc.isalpha():
        return "🌐"
    return "".join(chr(0x1F1E6 + ord(c) - ord("A")) for c in cc.upper())

def detect_live_location():
    proxy_handler = urllib.request.ProxyHandler({"http": "http://127.0.0.1:2080", "https": "http://127.0.0.1:2080"})
    opener = urllib.request.build_opener(proxy_handler)
    try:
        req = urllib.request.Request("http://ip-api.com/json/?fields=status,country,countryCode,city&lang=ru", headers={"User-Agent": "curl/8.0"})
        with opener.open(req, timeout=4.0) as r:
            d = json.loads(r.read().decode("utf-8", errors="ignore"))
        if d.get("status") == "success" and d.get("country"):
            flag = country_flag(d.get("countryCode", ""))
            country = d.get("country", "")
            city = d.get("city", "")
            return f"{flag} {country}" + (f" ({city})" if city else "")
    except Exception:
        pass
    try:
        req = urllib.request.Request("https://ipinfo.io/json", headers={"User-Agent": "curl/8.0"})
        with opener.open(req, timeout=4.0) as r:
            d = json.loads(r.read().decode("utf-8", errors="ignore"))
        cc = d.get("country", "")
        city = d.get("city", "")
        if cc:
            flag = country_flag(cc)
            return f"{flag} {cc}" + (f" ({city})" if city else "")
    except Exception:
        pass
    return None

def start_vpn():
    stop_vpn()
    st = load_state()
    if not st.get("servers") and "outbound" not in st:
        st = fetch_subscriptions()
    servers = st.get("servers", [])
    if servers:
        idx = min(max(0, st.get("selected_index", 0)), len(servers) - 1)
        st["outbound"] = servers[idx]["outbound"]
        st["server_name"] = servers[idx]["name"]
        save_state(st)
    if "outbound" not in st:
        return False
    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    use_tun = has_cap_net_admin(sb_bin)
    with open(SB_CONF, "w", encoding="utf-8") as f:
        json.dump(build_config(st["outbound"], st.get("ru_direct", True), use_tun), f, indent=2)
    if os.path.exists(sb_bin) and os.path.exists(SB_CONF):
        subprocess.Popen([sb_bin, "run", "-c", SB_CONF], stdout=open("/tmp/singbox_vpn.log", "w"), stderr=subprocess.STDOUT)
        if wait_port(2080, 3.5):
            set_desktop_proxy(not use_tun)
            loc = detect_live_location()
            if loc:
                st["server_name"] = loc
                servers = st.get("servers", [])
                idx = st.get("selected_index", 0)
                if 0 <= idx < len(servers):
                    servers[idx]["name"] = loc
                save_state(st)
            return True
        else:
            stop_vpn()
    return False

def dump_status_json():
    st = load_state()
    urls = read_sub_urls()
    srv_names = [s.get("name", f"Server {i+1}") for i, s in enumerate(st.get("servers", []))]
    out = {
        "server_name": st.get("server_name", "VPN"),
        "ru_direct": st.get("ru_direct", True),
        "selected_index": st.get("selected_index", 0),
        "servers": srv_names,
        "urls": urls
    }
    print(json.dumps(out, ensure_ascii=False))

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        dump_status_json()
    elif cmd == "update":
        if len(sys.argv) > 2 and sys.argv[2].strip():
            urls = read_sub_urls()
            u = sys.argv[2].strip()
            if u not in urls:
                urls.append(u)
                write_sub_urls(urls)
        fetch_subscriptions()
        dump_status_json()
    elif cmd == "add_url":
        if len(sys.argv) > 2 and sys.argv[2].strip():
            urls = read_sub_urls()
            u = sys.argv[2].strip()
            if u not in urls:
                urls.append(u)
                write_sub_urls(urls)
            fetch_subscriptions()
        dump_status_json()
    elif cmd == "remove_url":
        if len(sys.argv) > 2:
            idx = int(sys.argv[2])
            urls = read_sub_urls()
            if 0 <= idx < len(urls):
                urls.pop(idx)
                write_sub_urls(urls)
                fetch_subscriptions()
        dump_status_json()
    elif cmd == "select_server":
        if len(sys.argv) > 2:
            idx = int(sys.argv[2])
            st = load_state()
            servers = st.get("servers", [])
            if 0 <= idx < len(servers):
                st["selected_index"] = idx
                st["server_name"] = servers[idx]["name"]
                st["outbound"] = servers[idx]["outbound"]
                save_state(st)
                if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
                    start_vpn()
        dump_status_json()
    elif cmd == "set_ru":
        st = load_state()
        st["ru_direct"] = (sys.argv[2] == "1")
        save_state(st)
        if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
            start_vpn()
        dump_status_json()
    elif cmd == "start":
        start_vpn()
        dump_status_json()
    elif cmd == "stop":
        stop_vpn()
