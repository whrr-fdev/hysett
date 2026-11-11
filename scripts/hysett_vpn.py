#!/usr/bin/env python3
import sys, os, json, base64, urllib.request, urllib.parse, subprocess, shutil, socket, time, re
from concurrent.futures import ThreadPoolExecutor, as_completed

CONF_DIR = os.path.expanduser("~/.config/hypr/scripts")
SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_sub.txt")
STATE_FILE = os.path.join(CONF_DIR, "vpn_state.json")
SB_CONF = os.path.join(CONF_DIR, "singbox_vpn.json")
BYPASS_REPOS = os.path.expanduser("~/bypass-lists/repos")
UPDATE_SCRIPT = os.path.expanduser("~/hysett/scripts/update-bypass-lists.sh")

RU_DOMAIN_SUFFIXES = [
    "ru", ".ru", "su", ".su", "xn--p1ai", ".xn--p1ai", "by", ".by", "kz", ".kz",
    "yandex.com", "yandex.net", "ya.ru", "yastatic.net", "yandexcloud.net",
    "vk.com", "vk.ru", "vkuser.net", "vkuseraudio.net", "vkuservideo.net", "userapi.com", "mycdn.me",
    "gosuslugi.ru", "sberbank.ru", "sber.ru", "tbank.ru", "tinkoff.ru", "alfabank.ru", "vtb.ru",
    "ozon.ru", "ozonusercontent.com", "wb.ru", "wildberries.ru", "wbbasket.ru",
    "mail.ru", "imgsmail.ru", "avito.ru", "2gis.com", "kinopoisk.ru", "rutube.ru", "dzen.ru",
    "hh.ru", "habr.com", "pikabu.ru", "mts.ru", "megafon.ru", "beeline.ru", "tele2.ru"
]

WHITELIST_SOURCES = [
    ("auto", "⚡ Все проверенные белые списки (Авто)", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt",
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt",
        "vpn-configs/white_sni_ru.txt",
        "vpn-configs/whitelist_cidr1_ru.txt"
    ]),
    ("igareck_mobile", "🇷🇺 igareck: Vless Reality White-Lists Mobile", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt"
    ]),
    ("igareck_cidr_checked", "🇷🇺 igareck: WHITE-CIDR-RU (Проверенные)", [
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt"
    ]),
    ("igareck_sni", "🇷🇺 igareck: WHITE-SNI-RU (Все белые SNI)", [
        "vpn-configs-for-russia/WHITE-SNI-RU-all.txt"
    ]),
    ("igareck_cidr_all", "🇷🇺 igareck: WHITE-CIDR-RU (Все)", [
        "vpn-configs-for-russia/WHITE-CIDR-RU-all.txt"
    ]),
    ("wl_sni_ru", "🛡️ wlunlocker: white_sni_ru.txt", [
        "vpn-configs/white_sni_ru.txt"
    ]),
    ("wl_cidr1_ru", "🛡️ wlunlocker: whitelist_cidr1_ru.txt", [
        "vpn-configs/whitelist_cidr1_ru.txt"
    ]),
    ("wl_cidr2_ru", "🛡️ wlunlocker: whitelist_cidr2_ru.txt", [
        "vpn-configs/whitelist_cidr2_ru.txt"
    ]),
    ("wl_cidr3_eu", "🇪🇺 wlunlocker: whitelist_cidr3_eu.txt", [
        "vpn-configs/whitelist_cidr3_eu.txt"
    ]),
    ("wl_all", "🛡️ wlunlocker: whitelist_all.txt", [
        "vpn-configs/whitelist_all.txt"
    ]),
    ("igareck_black", "🌐 igareck: BLACK_VLESS_RUS.txt", [
        "vpn-configs-for-russia/BLACK_VLESS_RUS.txt",
        "vpn-configs-for-russia/BLACK_VLESS_RUS_mobile.txt"
    ])
]

DOMAIN_RE = re.compile(r"^[a-zA-Z0-9._-]+(\.[a-zA-Z0-9_-]+)+$")
CIDR_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}(/\d{1,2})?$")

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
        "split_mode": "ru_direct",
        "whitelist_mode": False,
        "whitelist_file": "auto",
        "port": 2080,
        "selected_index": 0,
        "servers": [],
        "sub_servers": [],
        "wl_servers": [],
        "custom_proxy_domains": [],
        "custom_direct_domains": []
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
    if not st["sub_servers"] and st.get("servers") and not st.get("whitelist_mode"):
        st["sub_servers"] = st["servers"]
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    if "url" in st:
        del st["url"]
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)

def parse_uri(uri):
    uri = uri.strip()
    if not uri or "://" not in uri:
        return None, None
    try:
        u = urllib.parse.urlsplit(uri)
        scheme = u.scheme.lower()
        name = urllib.parse.unquote(u.fragment or "VPN Server").strip()
        q = dict(urllib.parse.parse_qsl(u.query))
        host = (u.hostname or "").strip()
        port = int(u.port or 443)
    except Exception:
        return None, None

    if not host or port <= 0 or port > 65535:
        return None, None

    net_type = q.get("type", "tcp").lower()
    if net_type in ("xhttp", "splithttp", "kcp", "quic"):
        return None, None

    if scheme == "vless":
        uuid = urllib.parse.unquote(u.username or "").strip()
        if len(uuid) < 8:
            return None, None
        ob = {
            "type": "vless", "tag": "proxy",
            "server": host, "server_port": port,
            "uuid": uuid,
            "packet_encoding": "xudp"
        }
        flow = q.get("flow", "").strip()
        if flow in ("xtls-rprx-vision", "xtls-rprx-vision-udp443"):
            ob["flow"] = "xtls-rprx-vision"
        elif flow:
            return None, None
    elif scheme == "trojan":
        pw = urllib.parse.unquote(u.username or "").strip()
        if not pw:
            return None, None
        ob = {"type": "trojan", "tag": "proxy", "server": host, "server_port": port, "password": pw}
    elif scheme in ("hy2", "hysteria2"):
        pw = urllib.parse.unquote(u.username or "").strip()
        if not pw:
            return None, None
        ob = {"type": "hysteria2", "tag": "proxy", "server": host, "server_port": port, "password": pw}
    elif scheme == "ss":
        userinfo = urllib.parse.unquote(u.username or "").strip()
        if ":" not in userinfo:
            pad = len(userinfo) % 4
            if pad:
                userinfo += "=" * (4 - pad)
            try:
                userinfo = base64.urlsafe_b64decode(userinfo).decode("utf-8")
            except Exception:
                return None, None
        method, _, pw = userinfo.partition(":")
        if not method or not pw:
            return None, None
        ob = {"type": "shadowsocks", "tag": "proxy", "server": host, "server_port": port, "method": method, "password": pw}
    else:
        return None, None

    sec = q.get("security", "tls" if scheme in ("trojan", "hy2", "hysteria2") else "none").lower()
    if sec in ("tls", "reality"):
        sni = q.get("sni", q.get("peer", host)).strip() or host
        fp = q.get("fp", "chrome").strip() or "chrome"
        if fp not in ("chrome", "firefox", "safari", "ios", "android", "edge", "360", "qq", "random", "randomized"):
            fp = "chrome"
        tls = {
            "enabled": True,
            "server_name": sni,
            "utls": {"enabled": True, "fingerprint": fp}
        }
        if q.get("allowInsecure") in ("1", "true"):
            tls["insecure"] = True
        if q.get("alpn"):
            alpn = [x.strip() for x in q["alpn"].split(",") if x.strip()]
            if alpn:
                tls["alpn"] = alpn
        if sec == "reality":
            pbk = q.get("pbk", "").strip()
            sid = q.get("sid", "").strip()
            if not pbk or not re.match(r"^[0-9a-fA-F]{0,16}$", sid):
                return None, None
            tls["reality"] = {"enabled": True, "public_key": pbk, "short_id": sid}
        ob["tls"] = tls

    if net_type == "ws":
        ob["transport"] = {"type": "ws", "path": q.get("path", "/") or "/", "headers": {"Host": q.get("host", host) or host}}
    elif net_type == "grpc":
        ob["transport"] = {"type": "grpc", "service_name": q.get("serviceName", "")}
    elif net_type in ("http", "h2"):
        ob["transport"] = {"type": "http", "path": q.get("path", "/") or "/"}
    elif net_type == "httpupgrade":
        ob["transport"] = {"type": "httpupgrade", "path": q.get("path", "/") or "/", "host": q.get("host", host) or host}
    return name, ob

def read_domain_file(rel_path, max_items=12000):
    full = os.path.join(BYPASS_REPOS, rel_path)
    out = []
    if not os.path.exists(full):
        return out
    try:
        with open(full, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip().lower()
                if not s or s.startswith("#") or s.startswith("/"):
                    continue
                if "://" in s:
                    s = urllib.parse.urlsplit(s).hostname or ""
                s = s.lstrip("*.")
                if s and DOMAIN_RE.match(s):
                    out.append(s)
                    if len(out) >= max_items:
                        break
    except Exception:
        pass
    return out

def read_cidr_file(rel_path, max_items=4000):
    full = os.path.join(BYPASS_REPOS, rel_path)
    out = []
    if not os.path.exists(full):
        return out
    try:
        with open(full, "r", encoding="utf-8", errors="ignore") as f:
            for line in f:
                s = line.strip()
                if not s or s.startswith("#"):
                    continue
                if CIDR_RE.match(s):
                    if "/" not in s:
                        s += "/32"
                    out.append(s)
                    if len(out) >= max_items:
                        break
    except Exception:
        pass
    return out

def load_bypass_routing_sets(st):
    blocked_domains = set()
    for svc in ("youtube.lst", "discord.lst", "telegram.lst", "google_ai.lst", "meta.lst", "twitter.lst", "tiktok.lst", "hdrezka.lst", "roblox.lst", "google_meet.lst"):
        blocked_domains.update(read_domain_file(f"allow-domains/Services/{svc}", 2000))
    blocked_domains.update(read_domain_file("allow-domains/Russia/outside-raw.lst", 8000))
    blocked_domains.update(read_domain_file("Re-filter-lists/community.lst", 4000))
    for d in st.get("custom_proxy_domains", []):
        d = d.strip().lower().lstrip("*.")
        if d:
            blocked_domains.add(d)

    ru_domains = set(RU_DOMAIN_SUFFIXES)
    ru_domains.update(read_domain_file("allow-domains/Russia/inside-raw.lst", 6000))
    for d in st.get("custom_direct_domains", []):
        d = d.strip().lower().lstrip("*.")
        if d:
            ru_domains.add(d)
            blocked_domains.discard(d)

    # Исключаем заблокированные домены из прямого списка РФ, чтобы они гарантированно шли через VPN
    ru_domains.difference_update(blocked_domains)

    discord_cidrs = read_cidr_file("Re-filter-lists/discord_ips.lst", 500)
    blocked_cidrs = list(dict.fromkeys(discord_cidrs + read_cidr_file("Re-filter-lists/community_ips.lst", 1500)))
    return sorted(blocked_domains), sorted(ru_domains), blocked_cidrs

def load_whitelist_servers(wl_key="auto", limit=120):
    rel_files = []
    for k, _, files in WHITELIST_SOURCES:
        if k == wl_key:
            rel_files = files
            break
    if not rel_files:
        rel_files = WHITELIST_SOURCES[0][2]

    servers = []
    seen = set()
    for rel in rel_files:
        full = os.path.join(BYPASS_REPOS, rel)
        if not os.path.exists(full):
            continue
        try:
            with open(full, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if any(line.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
                        name, ob = parse_uri(line)
                        if not ob:
                            continue
                        sni = ob.get("tls", {}).get("server_name", "")
                        sig = (ob.get("type"), ob.get("server"), ob.get("server_port"), ob.get("uuid", ob.get("password", "")), sni)
                        if sig in seen:
                            continue
                        seen.add(sig)
                        short_name = name[:65] if name else f"{ob['server']}:{ob['server_port']}"
                        servers.append({"name": short_name, "outbound": ob})
                        if len(servers) >= limit:
                            break
        except Exception:
            pass
        if len(servers) >= limit:
            break

    if len(servers) > 1:
        pool = [dict(s["outbound"], tag=f"wl-{i}") for i, s in enumerate(servers[:25])]
        servers.insert(0, {
            "name": f"⚡ Авто-выбор (UrlTest из {len(pool)} серверов белого списка)",
            "outbound": {
                "type": "urltest",
                "tag": "proxy",
                "outbounds": [p["tag"] for p in pool],
                "url": "https://www.gstatic.com/generate_204",
                "interval": "3m",
                "tolerance": 80,
                "_pool": pool
            }
        })
    return servers

def tcp_ping_server(item, timeout=1.2):
    ob = item.get("outbound", {})
    if ob.get("type") == "urltest":
        return -1, item
    host = ob.get("server", "")
    port = int(ob.get("server_port", 443))
    if not host:
        return 99999, item
    t0 = time.monotonic()
    try:
        with socket.create_connection((host, port), timeout=timeout):
            ms = int((time.monotonic() - t0) * 1000)
            clean_name = re.sub(r"^\[(\d+)\s*мс\]\s*", "", item.get("name", ""))
            return ms, {"name": f"[{ms} мс] {clean_name}", "outbound": ob}
    except Exception:
        return 99999, item

def test_and_sort_whitelist(st):
    wl = load_whitelist_servers(st.get("whitelist_file", "auto"), limit=90)
    real_srvs = [s for s in wl if s.get("outbound", {}).get("type") != "urltest"]
    if not real_srvs:
        return st

    scored = []
    with ThreadPoolExecutor(max_workers=24) as ex:
        futs = [ex.submit(tcp_ping_server, s, 1.1) for s in real_srvs]
        for f in as_completed(futs):
            ms, item = f.result()
            if ms < 99999:
                scored.append((ms, item))

    scored.sort(key=lambda x: x[0])
    alive = [x[1] for x in scored]
    if not alive:
        alive = real_srvs[:30]

    pool = [dict(s["outbound"], tag=f"wl-{i}") for i, s in enumerate(alive[:20])]
    final_list = [{
        "name": f"⚡ Авто-выбор ({len(pool)} проверенных серверов)",
        "outbound": {
            "type": "urltest",
            "tag": "proxy",
            "outbounds": [p["tag"] for p in pool],
            "url": "https://www.gstatic.com/generate_204",
            "interval": "2m",
            "tolerance": 60,
            "_pool": pool
        }
    }] + alive

    st["wl_servers"] = final_list
    if st.get("whitelist_mode", False):
        st["servers"] = final_list
        st["selected_index"] = 0
        st["server_name"] = final_list[0]["name"]
        st["outbound"] = final_list[0]["outbound"]
    save_state(st)
    return st

def has_cap_net_admin(sb_bin):
    try:
        out = subprocess.check_output(["getcap", sb_bin], text=True, stderr=subprocess.DEVNULL)
        return "cap_net_admin" in out
    except Exception:
        return False

def build_config(outbound, st, use_tun=False):
    split_mode = st.get("split_mode", "ru_direct" if st.get("ru_direct", True) else "all_vpn")
    blocked_domains, ru_domains, blocked_cidrs = load_bypass_routing_sets(st)

    outbounds = []
    if outbound.get("type") == "urltest" and "_pool" in outbound:
        pool = outbound["_pool"]
        ut = {
            "type": "urltest",
            "tag": "proxy",
            "outbounds": [p["tag"] for p in pool],
            "url": outbound.get("url", "https://www.gstatic.com/generate_204"),
            "interval": outbound.get("interval", "3m"),
            "tolerance": outbound.get("tolerance", 80)
        }
        outbounds.append(ut)
        outbounds.extend(pool)
    else:
        clean_ob = {k: v for k, v in outbound.items() if not k.startswith("_")}
        clean_ob["tag"] = "proxy"
        outbounds.append(clean_ob)

    outbounds.append({"type": "direct", "tag": "direct"})

    inbounds = [{
        "type": "mixed",
        "tag": "mixed-in",
        "listen": "127.0.0.1",
        "listen_port": 2080,
        "set_system_proxy": False
    }]
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
        {"action": "sniff", "timeout": "300ms"},
        {"protocol": "dns", "action": "hijack-dns"},
        {"ip_is_private": True, "outbound": "direct"}
    ]
    dns_rules = []

    if split_mode == "ru_direct":
        if blocked_domains:
            rules.append({"domain_suffix": blocked_domains, "outbound": "proxy"})
            dns_rules.append({"domain_suffix": blocked_domains, "server": "dns-remote"})
        if blocked_cidrs:
            rules.append({"ip_cidr": blocked_cidrs, "outbound": "proxy"})
        if ru_domains:
            rules.append({"domain_suffix": ru_domains, "outbound": "direct"})
            dns_rules.append({"domain_suffix": ru_domains, "server": "dns-direct"})
        route_final = "proxy"
        dns_final = "dns-remote"
    elif split_mode == "only_blocked":
        if blocked_domains:
            rules.append({"domain_suffix": blocked_domains, "outbound": "proxy"})
            dns_rules.append({"domain_suffix": blocked_domains, "server": "dns-remote"})
        if blocked_cidrs:
            rules.append({"ip_cidr": blocked_cidrs, "outbound": "proxy"})
        route_final = "direct"
        dns_final = "dns-direct"
    else:
        if st.get("custom_direct_domains"):
            cd = [d.strip().lower().lstrip("*.") for d in st["custom_direct_domains"] if d.strip()]
            if cd:
                rules.append({"domain_suffix": cd, "outbound": "direct"})
                dns_rules.append({"domain_suffix": cd, "server": "dns-direct"})
        route_final = "proxy"
        dns_final = "dns-remote"

    return {
        "log": {"level": "warn"},
        "dns": {
            "servers": [
                {"type": "https", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"},
                {"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}
            ],
            "rules": dns_rules,
            "strategy": "ipv4_only",
            "final": dns_final
        },
        "inbounds": inbounds,
        "outbounds": outbounds,
        "route": {
            "default_domain_resolver": "dns-direct",
            "auto_detect_interface": True,
            "rules": rules,
            "final": route_final
        }
    }

def parse_subscription_content(raw):
    found = []
    if "://" not in raw and not raw.startswith("{"):
        pad = len(raw) % 4
        if pad:
            raw += "=" * (4 - pad)
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

def sync_active_server_list(st):
    if st.get("whitelist_mode", False):
        if not st.get("wl_servers"):
            st["wl_servers"] = load_whitelist_servers(st.get("whitelist_file", "auto"))
        st["servers"] = st.get("wl_servers", [])
    else:
        st["servers"] = st.get("sub_servers", [])

    servers = st.get("servers", [])
    if servers:
        idx = min(max(0, st.get("selected_index", 0)), len(servers) - 1)
        st["selected_index"] = idx
        st["server_name"] = servers[idx]["name"]
        st["outbound"] = servers[idx]["outbound"]
    return st

def fetch_subscriptions():
    st = load_state()
    urls = read_sub_urls()
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
        st["sub_servers"] = all_servers
    st = sync_active_server_list(st)
    save_state(st)
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
    else:
        subprocess.run(["gsettings", "set", "org.gnome.system.proxy", "mode", "none"], stderr=subprocess.DEVNULL)

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
        with opener.open(req, timeout=3.5) as r:
            d = json.loads(r.read().decode("utf-8", errors="ignore"))
        if d.get("status") == "success" and d.get("country"):
            flag = country_flag(d.get("countryCode", ""))
            country = d.get("country", "")
            city = d.get("city", "")
            return f"{flag} {country}" + (f" ({city})" if city else "")
    except Exception:
        pass
    return None

def wait_network_ready(timeout=8.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            out = subprocess.check_output(["ip", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL).strip()
            if out:
                return True
        except Exception:
            pass
        time.sleep(0.3)
    return False

def start_vpn():
    wait_network_ready(8.0)
    stop_vpn()
    st = load_state()
    st = sync_active_server_list(st)
    if not st.get("servers") and not st.get("whitelist_mode"):
        st = fetch_subscriptions()
    if "outbound" not in st or not st.get("servers"):
        return False

    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    use_tun = has_cap_net_admin(sb_bin)
    cfg = build_config(st["outbound"], st, use_tun)
    with open(SB_CONF, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)

    if os.path.exists(sb_bin) and os.path.exists(SB_CONF):
        subprocess.Popen([sb_bin, "run", "-c", SB_CONF], stdout=open("/tmp/singbox_vpn.log", "w"), stderr=subprocess.STDOUT)
        if wait_port(2080, 3.5):
            set_desktop_proxy(not use_tun)
            if not st.get("whitelist_mode", False):
                loc = detect_live_location()
                if loc:
                    st["server_name"] = loc
                    idx = st.get("selected_index", 0)
                    if 0 <= idx < len(st.get("servers", [])):
                        st["servers"][idx]["name"] = loc
                    save_state(st)
            return True
        else:
            stop_vpn()
    return False

def dump_status_json():
    st = load_state()
    st = sync_active_server_list(st)
    urls = read_sub_urls()
    srv_names = [s.get("name", f"Server {i+1}") for i, s in enumerate(st.get("servers", []))]
    wl_files = [{"key": k, "label": lbl} for k, lbl, _ in WHITELIST_SOURCES]
    blocked_d, ru_d, _ = load_bypass_routing_sets(st)
    hint = f"Маршруты: {len(blocked_d)} в обход блокировок | {len(ru_d)} РФ напрямую"
    out = {
        "server_name": st.get("server_name", "VPN"),
        "ru_direct": st.get("ru_direct", True),
        "split_mode": st.get("split_mode", "ru_direct"),
        "whitelist_mode": st.get("whitelist_mode", False),
        "whitelist_file": st.get("whitelist_file", "auto"),
        "whitelist_files": wl_files,
        "selected_index": st.get("selected_index", 0),
        "servers": srv_names,
        "urls": urls,
        "custom_proxy_domains": st.get("custom_proxy_domains", []),
        "custom_direct_domains": st.get("custom_direct_domains", []),
        "status_hint": hint
    }
    print(json.dumps(out, ensure_ascii=False))

def restart_if_running():
    if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
        start_vpn()

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
    elif cmd == "update_lists":
        if os.path.exists(UPDATE_SCRIPT):
            subprocess.run(["/usr/bin/bash", UPDATE_SCRIPT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        st = load_state()
        st["wl_servers"] = load_whitelist_servers(st.get("whitelist_file", "auto"))
        st = sync_active_server_list(st)
        save_state(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "set_whitelist_mode":
        st = load_state()
        st["whitelist_mode"] = (sys.argv[2] == "1") if len(sys.argv) > 2 else False
        st["selected_index"] = 0
        if st["whitelist_mode"] and not st.get("wl_servers"):
            st["wl_servers"] = load_whitelist_servers(st.get("whitelist_file", "auto"))
        st = sync_active_server_list(st)
        save_state(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "set_whitelist_file":
        if len(sys.argv) > 2:
            st = load_state()
            st["whitelist_file"] = sys.argv[2].strip()
            st["selected_index"] = 0
            st["wl_servers"] = load_whitelist_servers(st["whitelist_file"])
            st = sync_active_server_list(st)
            save_state(st)
            restart_if_running()
        dump_status_json()
    elif cmd == "test_whitelist":
        st = load_state()
        st = test_and_sort_whitelist(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "set_split_mode":
        if len(sys.argv) > 2:
            mode = sys.argv[2].strip()
            if mode in ("ru_direct", "only_blocked", "all_vpn"):
                st = load_state()
                st["split_mode"] = mode
                st["ru_direct"] = (mode != "all_vpn")
                save_state(st)
                restart_if_running()
        dump_status_json()
    elif cmd == "add_custom_domain":
        if len(sys.argv) > 3:
            dom = sys.argv[2].strip().lower().lstrip("*.")
            is_direct = (sys.argv[3] == "1")
            st = load_state()
            key = "custom_direct_domains" if is_direct else "custom_proxy_domains"
            arr = st.get(key, [])
            if dom and dom not in arr:
                arr.append(dom)
                st[key] = arr
                save_state(st)
                restart_if_running()
        dump_status_json()
    elif cmd == "remove_custom_domain":
        if len(sys.argv) > 3:
            idx = int(sys.argv[2])
            is_direct = (sys.argv[3] == "1")
            st = load_state()
            key = "custom_direct_domains" if is_direct else "custom_proxy_domains"
            arr = st.get(key, [])
            if 0 <= idx < len(arr):
                arr.pop(idx)
                st[key] = arr
                save_state(st)
                restart_if_running()
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
            st = sync_active_server_list(st)
            servers = st.get("servers", [])
            if 0 <= idx < len(servers):
                st["selected_index"] = idx
                st["server_name"] = servers[idx]["name"]
                st["outbound"] = servers[idx]["outbound"]
                save_state(st)
                restart_if_running()
        dump_status_json()
    elif cmd == "set_ru":
        st = load_state()
        ru_on = (sys.argv[2] == "1")
        st["ru_direct"] = ru_on
        st["split_mode"] = "ru_direct" if ru_on else "all_vpn"
        save_state(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "start":
        start_vpn()
        dump_status_json()
    elif cmd == "stop":
        stop_vpn()
