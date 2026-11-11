#!/usr/bin/env python3
import sys, os, json, base64, urllib.request, urllib.parse, subprocess, shutil, socket, time, re, ipaddress, bisect
from concurrent.futures import ThreadPoolExecutor, as_completed

HYSETT_DIR = os.path.expanduser("~/hysett")
CONF_DIR = os.path.expanduser("~/.config/hypr/scripts")
SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_sub.txt")
WL_SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_wl_sub.txt")
STATE_FILE = os.path.join(CONF_DIR, "vpn_state.json")
SB_CONF = os.path.join(CONF_DIR, "singbox_vpn.json")
BYPASS_REPOS = os.path.join(HYSETT_DIR, "bypass-lists/repos")
if not os.path.exists(BYPASS_REPOS):
    BYPASS_REPOS = os.path.expanduser("~/bypass-lists/repos")
UPDATE_SCRIPT = os.path.join(HYSETT_DIR, "scripts/update-bypass-lists.sh")

RU_DOMAIN_SUFFIXES = [
    "ru", ".ru", "su", ".su", "xn--p1ai", ".xn--p1ai", "by", ".by", "kz", ".kz",
    "yandex.com", "yandex.net", "ya.ru", "yastatic.net", "yandexcloud.net",
    "vk.com", "vk.ru", "vkuser.net", "vkuseraudio.net", "vkuservideo.net", "userapi.com", "mycdn.me",
    "gosuslugi.ru", "sberbank.ru", "sber.ru", "tbank.ru", "tinkoff.ru", "alfabank.ru", "vtb.ru",
    "ozon.ru", "ozonusercontent.com", "wb.ru", "wildberries.ru", "wbbasket.ru",
    "mail.ru", "imgsmail.ru", "avito.ru", "2gis.com", "kinopoisk.ru", "rutube.ru", "dzen.ru",
    "hh.ru", "habr.com", "pikabu.ru", "mts.ru", "megafon.ru", "beeline.ru", "tele2.ru", "stamina-online.com", "staminaon.com"
]

WHITE_SNI_KEYWORDS = (
    ".ru", ".su", "vk.com", "userapi.com", "vkuser", "mycdn.me",
    "ya.ru", "yandex.", "yastatic.net", "sber", "tbank", "tinkoff",
    "ozon.", "wb.ru", "wildberries", "gosuslugi", "mail.ru", "imgsmail.ru",
    "mts.ru", "megafon.ru", "beeline.ru", "tele2.ru", "rostelecom", "selectel", "2gis"
)

WHITELIST_SOURCES = [
    ("auto", "󰓅 Все проверенные БС", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt",
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt",
        "vpn-configs/white_sni_ru.txt",
        "vpn-configs/whitelist_cidr1_ru.txt"
    ]),
    ("my_wl_subs", "󰌘 Мои подписки БС", []),
    ("igareck_mobile", "󰄜 igareck Mobile", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt"
    ]),
    ("igareck_cidr_checked", "󰞀 igareck CIDR", [
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt"
    ]),
    ("igareck_sni", "󰒃 igareck SNI РФ", [
        "vpn-configs-for-russia/WHITE-SNI-RU-all.txt"
    ]),
    ("igareck_cidr_all", "󰒃 igareck Все CIDR", [
        "vpn-configs-for-russia/WHITE-CIDR-RU-all.txt"
    ]),
    ("wl_sni_ru", "󰒃 wlunlocker SNI РФ", [
        "vpn-configs/white_sni_ru.txt"
    ]),
    ("wl_cidr1_ru", "󰞀 wlunlocker CIDR 1", [
        "vpn-configs/whitelist_cidr1_ru.txt"
    ]),
    ("wl_cidr2_ru", "󰞀 wlunlocker CIDR 2", [
        "vpn-configs/whitelist_cidr2_ru.txt"
    ]),
    ("wl_cidr3_eu", "󰈀 wlunlocker CIDR EU", [
        "vpn-configs/whitelist_cidr3_eu.txt"
    ]),
    ("wl_all", "󰒃 wlunlocker Все БС", [
        "vpn-configs/whitelist_all.txt"
    ]),
    ("igareck_black", "󰦝 igareck VLESS", [
        "vpn-configs-for-russia/BLACK_VLESS_RUS.txt",
        "vpn-configs-for-russia/BLACK_VLESS_RUS_mobile.txt"
    ])
]

DOMAIN_RE = re.compile(r"^[a-zA-Z0-9._-]+(\.[a-zA-Z0-9_-]+)+$")
CIDR_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}(/\d{1,2})?$")
IPV4_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")

def server_sig(ob):
    if not isinstance(ob, dict) or ob.get("type") == "urltest":
        return ""
    sni = ob.get("tls", {}).get("server_name", "")
    return f"{ob.get('type')}://{ob.get('server')}:{ob.get('server_port')}/{ob.get('uuid', ob.get('password', ''))}/{sni}"

def rebuild_uri_from_outbound(ob, name="Server"):
    if not isinstance(ob, dict) or ob.get("type") == "urltest":
        return ""
    t = ob.get("type", "vless")
    host = ob.get("server", "")
    port = ob.get("server_port", 443)
    frag = urllib.parse.quote(name)
    if t == "vless":
        uuid = ob.get("uuid", "")
        params = {"type": ob.get("transport", {}).get("type", "tcp")}
        if ob.get("flow"):
            params["flow"] = ob["flow"]
        tls = ob.get("tls", {})
        if tls.get("enabled"):
            if tls.get("reality", {}).get("enabled"):
                params["security"] = "reality"
                params["pbk"] = tls["reality"].get("public_key", "")
                if tls["reality"].get("short_id"):
                    params["sid"] = tls["reality"]["short_id"]
            else:
                params["security"] = "tls"
            if tls.get("server_name"):
                params["sni"] = tls["server_name"]
            if tls.get("utls", {}).get("fingerprint"):
                params["fp"] = tls["utls"]["fingerprint"]
        q = urllib.parse.urlencode(params)
        return f"vless://{uuid}@{host}:{port}?{q}#{frag}"
    elif t == "trojan":
        pw = ob.get("password", "")
        sni = ob.get("tls", {}).get("server_name", host)
        return f"trojan://{pw}@{host}:{port}?security=tls&sni={sni}#{frag}"
    elif t == "hysteria2":
        pw = ob.get("password", "")
        sni = ob.get("tls", {}).get("server_name", host)
        return f"hy2://{pw}@{host}:{port}?sni={sni}#{frag}"
    return ""

def read_url_list(path):
    urls = []
    if os.path.exists(path):
        with open(path, "r", encoding="utf-8") as f:
            for line in f:
                u = line.strip()
                if u and u not in urls:
                    urls.append(u)
    return urls

def write_url_list(path, urls):
    clean = []
    for u in urls:
        u = u.strip()
        if u and u not in clean:
            clean.append(u)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for u in clean:
            f.write(u + "\n")
    os.chmod(path, 0o600)

def read_sub_urls():
    return read_url_list(SUB_FILE)

def write_sub_urls(urls):
    write_url_list(SUB_FILE, urls)

def read_wl_sub_urls():
    return read_url_list(WL_SUB_FILE)

def write_wl_sub_urls(urls):
    write_url_list(WL_SUB_FILE, urls)

def clean_server_title(text):
    s = re.sub(r"[\U0001F1E0-\U0001F1FF\U0001F300-\U0001FAFF\u2600-\u27BF\uE000-\uF8FF\U000F0000-\U000FFFFD]+", "", text or "")
    s = re.sub(r"\(\s*[^)]*\)", "", s)
    s = re.sub(r"\[\s*\*?[A-Za-zА-Яа-я0-9_+|-]+\s*\]", "", s)
    s = re.sub(r"[✨⚡⭐🛡️🎭🌐🇷🇺🇪🇺•|._*˚+‧-]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s or "Сервер"

def short_sub_title(url, idx, custom_title=""):
    if custom_title:
        c = clean_server_title(custom_title)
        if c and c != "Сервер":
            return c[:24]
    if "#" in url:
        frag = clean_server_title(urllib.parse.unquote(url.split("#", 1)[1]))
        if frag and frag != "Сервер":
            return frag[:24]
    try:
        u = urllib.parse.urlsplit(url)
        if u.scheme in ("vless", "trojan", "hy2", "hysteria2", "ss"):
            return f"Ключ #{idx+1}"
        if u.hostname:
            return u.hostname[:24]
    except Exception:
        pass
    return f"Подписка #{idx+1}"

def load_state():
    st = {
        "vpn_enabled": False,
        "server_name": "VPN",
        "sub_server_name": "VPN",
        "wl_server_name": "Авто-выбор лучшего сервера",
        "ru_direct": True,
        "split_mode": "ru_direct",
        "whitelist_mode": False,
        "whitelist_file": "auto",
        "port": 2080,
        "selected_index": 0,
        "sub_selected_index": 0,
        "wl_selected_index": 0,
        "servers": [],
        "sub_servers": [],
        "sub_cache": {},
        "wl_sub_cache": {},
        "wl_servers": [],
        "frozen_sigs": [],
        "custom_proxy_domains": [],
        "custom_direct_domains": []
    }
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                st.update(json.load(f))
        except Exception:
            pass
    if not isinstance(st.get("sub_cache"), dict):
        st["sub_cache"] = {}
    if not isinstance(st.get("wl_sub_cache"), dict):
        st["wl_sub_cache"] = {}
    if not isinstance(st.get("frozen_sigs"), list):
        st["frozen_sigs"] = []
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    st.pop("url", None)
    with open(STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)

def parse_uri(uri):
    uri = uri.strip()
    if not uri or "://" not in uri:
        return None, None
    try:
        u = urllib.parse.urlsplit(uri)
        scheme = u.scheme.lower()
        raw_name = urllib.parse.unquote(u.fragment or "").strip()
        q = dict(urllib.parse.parse_qsl(u.query))
        host = (u.hostname or "").strip()
        port = int(u.port or 443)
        name = clean_server_title(raw_name)
        if not name or name == "Сервер":
            name = f"{host}:{port}"
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

def load_ru_whitelist_ip_intervals():
    intervals = []
    for rel in ("vpn-configs/whitelist_cidr1_ru.txt", "vpn-configs/whitelist_cidr2_ru.txt", "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt"):
        full = os.path.join(BYPASS_REPOS, rel)
        if not os.path.exists(full):
            continue
        try:
            with open(full, "r", encoding="utf-8", errors="ignore") as f:
                for line in f:
                    s = line.strip()
                    if not s or s.startswith("#"):
                        continue
                    if CIDR_RE.match(s):
                        try:
                            net = ipaddress.IPv4Network(s, strict=False)
                            intervals.append((int(net.network_address), int(net.broadcast_address)))
                        except Exception:
                            pass
        except Exception:
            pass
    if not intervals:
        for cidr in ("5.45.192.0/18", "5.61.16.0/21", "37.9.64.0/18", "77.88.0.0/18", "87.240.128.0/18",
                     "84.201.128.0/18", "93.158.128.0/18", "95.163.0.0/16", "95.213.0.0/16", "178.154.128.0/17",
                     "185.71.76.0/22", "213.180.192.0/19", "45.130.41.0/24", "158.160.0.0/16", "62.84.112.0/20",
                     "51.250.0.0/17", "130.193.32.0/19", "176.53.160.0/20", "188.93.56.0/21"):
            net = ipaddress.IPv4Network(cidr, strict=False)
            intervals.append((int(net.network_address), int(net.broadcast_address)))
    intervals.sort()
    merged = []
    for st_i, en_i in intervals:
        if merged and st_i <= merged[-1][1] + 1:
            merged[-1] = (merged[-1][0], max(merged[-1][1], en_i))
        else:
            merged.append((st_i, en_i))
    starts = [x[0] for x in merged]
    return starts, merged

def check_ip_in_intervals(ip_str, starts, merged):
    try:
        val = int(ipaddress.IPv4Address(ip_str))
    except Exception:
        return False
    idx = bisect.bisect_right(starts, val) - 1
    if idx >= 0 and merged[idx][0] <= val <= merged[idx][1]:
        return True
    return False

def classify_whitelist_badge(ob, starts, merged, resolve_dns=False):
    host = ob.get("server", "")
    sni = (ob.get("tls", {}).get("server_name", "") or "").lower()
    is_sni_wl = any(k in sni for k in WHITE_SNI_KEYWORDS)
    ip_str = host if IPV4_RE.match(host) else ""
    if not ip_str and resolve_dns:
        try:
            ip_str = socket.gethostbyname(host)
        except Exception:
            ip_str = ""
    is_cidr_wl = check_ip_in_intervals(ip_str, starts, merged) if ip_str else False
    if is_cidr_wl and is_sni_wl:
        return "CIDR+SNI", 0
    if is_cidr_wl:
        return "CIDR РФ", 1
    if is_sni_wl:
        return "Белый SNI", 2
    return "VLESS", 3

def load_bypass_routing_sets(st):
    blocked_domains = {
        "google.ru", "www.google.ru", "google.com", "youtube.ru", "www.youtube.ru",
        "youtube.com", "youtu.be", "googlevideo.com", "ytimg.com", "ggpht.com",
        "gstatic.com", "googleapis.com", "2ip.ru", "2ip.io"
    }
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

    # Базовые сервисы РФ (Яндекс, ВК, Госуслуги, Банки, Stamina) всегда идут напрямую
    core_ru = {d.lstrip(".") for d in RU_DOMAIN_SUFFIXES}
    blocked_domains.difference_update(core_ru)
    ru_domains.difference_update(blocked_domains)

    discord_cidrs = read_cidr_file("Re-filter-lists/discord_ips.lst", 500)
    blocked_cidrs = list(dict.fromkeys(discord_cidrs + read_cidr_file("Re-filter-lists/community_ips.lst", 1500)))

    ru_cidrs = [
        "5.45.192.0/18", "5.61.16.0/21", "31.31.192.0/18", "37.9.64.0/18", "37.140.192.0/18",
        "45.130.41.0/24", "51.250.0.0/17", "62.84.112.0/20", "77.88.0.0/18", "84.201.128.0/18",
        "87.240.128.0/18", "89.108.64.0/18", "93.158.128.0/18", "95.163.0.0/16", "95.213.0.0/16",
        "130.193.32.0/19", "158.160.0.0/16", "176.53.160.0/20", "178.154.128.0/17",
        "185.71.76.0/22", "188.93.56.0/21", "194.58.88.0/21", "194.67.64.0/19", "213.180.192.0/19"
    ]
    for rel_c in ("vpn-configs/whitelist_cidr1_ru.txt", "vpn-configs/whitelist_cidr2_ru.txt", "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt"):
        for c in read_cidr_file(rel_c, 2500):
            if c not in ru_cidrs:
                ru_cidrs.append(c)

    return sorted(blocked_domains), sorted(ru_domains), blocked_cidrs, ru_cidrs

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
                    nm = clean_server_title(ob.get("tag_name") or ob.get("server") or f"Сервер {idx+1}")
                    found.append({"name": nm, "outbound": ob, "uri": rebuild_uri_from_outbound(ob, nm)})
        except Exception:
            pass
        return found

    for line in raw.splitlines():
        line = line.strip()
        if any(line.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
            name, ob = parse_uri(line)
            if ob:
                found.append({"name": name, "outbound": ob, "uri": line})
    return found

def fetch_single_url(u):
    if any(u.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
        name, ob = parse_uri(u)
        if ob:
            return "", [{"name": name, "outbound": ob, "uri": u}]
        return "", []

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
    for ua in ("v2rayN/6.45", "SFA/1.11.0 sing-box/1.11.0", "ClashMetaForAndroid/2.10.1", "Mozilla/5.0"):
        try:
            req = urllib.request.Request(u, headers={"User-Agent": ua})
            with opener.open(req, timeout=10) as r:
                title = ""
                raw_title = r.headers.get("profile-title", "")
                if raw_title.startswith("base64:"):
                    try:
                        title = base64.b64decode(raw_title.split(":", 1)[1]).decode("utf-8", errors="ignore").strip()
                    except Exception:
                        pass
                elif raw_title:
                    title = raw_title.strip()
                raw = r.read().decode("utf-8", errors="ignore").strip()
            parsed = parse_subscription_content(raw)
            if parsed:
                return clean_server_title(title), parsed
        except Exception as e:
            print(f"Fetch error ({u}): {e}", file=sys.stderr)
    return "", []

def rebuild_sub_servers_from_cache(urls, cache_dict, frozen_set, mark_wl_badges=False):
    starts, merged = (load_ru_whitelist_ip_intervals() if mark_wl_badges else ([], []))
    all_srvs = []
    groups = []
    for idx, u in enumerate(urls):
        entry = cache_dict.get(u, {})
        if isinstance(entry, list):
            srvs = entry
            title = short_sub_title(u, idx)
        else:
            srvs = entry.get("servers", [])
            title = short_sub_title(u, idx, entry.get("title", ""))
        start_idx = len(all_srvs)
        group_srv_names = []
        for s in srvs:
            nm = clean_server_title(s.get("name", "Сервер"))
            ob = s.get("outbound", {})
            uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
            sig = server_sig(ob)
            is_frz = (sig in frozen_set) if sig else False
            if mark_wl_badges and ob:
                badge, _ = classify_whitelist_badge(ob, starts, merged, resolve_dns=False)
                nm = f"{badge} • {nm}"
            item = {"name": nm, "outbound": ob, "uri": uri, "sig": sig, "frozen": is_frz, "sub_index": idx}
            all_srvs.append(item)
            group_srv_names.append({
                "name": nm,
                "uri": uri,
                "sig": sig,
                "frozen": is_frz,
                "global_index": len(all_srvs) - 1
            })
        groups.append({
            "index": idx,
            "title": title,
            "url": u,
            "count": len(srvs),
            "start_index": start_idx,
            "servers": group_srv_names
        })
    return all_srvs, groups

def apply_freeze_and_urltest(raw_servers, frozen_set, auto_title="Авто-выбор лучшего сервера"):
    real = [s for s in raw_servers if s.get("outbound", {}).get("type") != "urltest"]
    active_list = []
    frozen_list = []
    for s in real:
        ob = s.get("outbound", {})
        sig = s.get("sig") or server_sig(ob)
        uri = s.get("uri") or rebuild_uri_from_outbound(ob, s.get("name", "Server"))
        is_frz = sig in frozen_set if sig else False
        item = dict(s, sig=sig, uri=uri, frozen=is_frz)
        if is_frz:
            frozen_list.append(item)
        else:
            active_list.append(item)

    ordered = active_list + frozen_list
    if len(active_list) >= 1:
        pool = [dict(s["outbound"], tag=f"wl-{i}") for i, s in enumerate(active_list[:25])]
        ordered.insert(0, {
            "name": auto_title,
            "uri": "",
            "sig": "",
            "frozen": False,
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
    return ordered

def load_whitelist_servers(st, wl_key="auto", limit=120):
    frozen_set = set(st.get("frozen_sigs", []))
    if wl_key == "my_wl_subs":
        wl_urls = read_wl_sub_urls()
        srvs, _ = rebuild_sub_servers_from_cache(wl_urls, st.get("wl_sub_cache", {}), frozen_set, mark_wl_badges=True)
        return apply_freeze_and_urltest(srvs, frozen_set)

    rel_files = []
    for k, _, files in WHITELIST_SOURCES:
        if k == wl_key:
            rel_files = files
            break
    if not rel_files:
        rel_files = WHITELIST_SOURCES[0][2]

    starts, merged = load_ru_whitelist_ip_intervals()
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
                        sig = server_sig(ob)
                        if sig in seen:
                            continue
                        seen.add(sig)
                        sni = ob.get("tls", {}).get("server_name", "")
                        badge, _ = classify_whitelist_badge(ob, starts, merged, resolve_dns=False)
                        title = name if (name and name != "Сервер") else f"{ob['server']}:{ob['server_port']}"
                        if sni and sni not in title:
                            title = f"{title} • {sni}"
                        servers.append({
                            "name": f"{badge} • {title[:52]}",
                            "outbound": ob,
                            "uri": line,
                            "sig": sig,
                            "frozen": (sig in frozen_set)
                        })
                        if len(servers) >= limit:
                            break
        except Exception:
            pass
        if len(servers) >= limit:
            break

    return apply_freeze_and_urltest(servers, frozen_set)

def tcp_quick_filter(item, timeout=0.9):
    ob = item.get("outbound", {})
    host = ob.get("server", "")
    port = int(ob.get("server_port", 443))
    if not host:
        return False, item
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True, item
    except Exception:
        return False, item

def probe_http204_via_port(port, item, starts, merged, timeout=2.8):
    proxy_url = f"http://127.0.0.1:{port}"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
    t0 = time.monotonic()
    try:
        req = urllib.request.Request("http://cp.cloudflare.com/generate_204", headers={"User-Agent": "curl/8.0"})
        with opener.open(req, timeout=timeout) as r:
            if r.status in (200, 204):
                ms = int((time.monotonic() - t0) * 1000)
                ob = item["outbound"]
                badge, tier = classify_whitelist_badge(ob, starts, merged, resolve_dns=True)
                parts = item.get("name", "").split(" • ")
                base_title = parts[-1] if parts else f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
                return (tier, ms), {
                    "name": f"{ms} мс • {badge} • {base_title}",
                    "outbound": ob,
                    "uri": item.get("uri", "") or rebuild_uri_from_outbound(ob, base_title),
                    "sig": item.get("sig", "") or server_sig(ob),
                    "frozen": False
                }
    except Exception:
        pass
    return None, item

def test_and_sort_whitelist(st):
    frozen_set = set(st.get("frozen_sigs", []))
    wl = load_whitelist_servers(st, st.get("whitelist_file", "auto"), limit=110)
    real_srvs = [s for s in wl if s.get("outbound", {}).get("type") != "urltest" and not s.get("frozen")]
    if not real_srvs:
        return st

    tcp_alive = []
    with ThreadPoolExecutor(max_workers=32) as ex:
        futs = [ex.submit(tcp_quick_filter, s, 0.9) for s in real_srvs]
        for f in as_completed(futs):
            ok, item = f.result()
            if ok:
                tcp_alive.append(item)

    candidates = tcp_alive[:45] if tcp_alive else real_srvs[:30]
    starts, merged = load_ru_whitelist_ip_intervals()

    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    verified = []
    if os.path.exists(sb_bin) and candidates:
        base_port = 29100
        inbounds = []
        outbounds = [{"type": "direct", "tag": "direct"}]
        rules = []
        for idx, c in enumerate(candidates):
            in_tag = f"in-{idx}"
            out_tag = f"test-{idx}"
            inbounds.append({
                "type": "mixed",
                "tag": in_tag,
                "listen": "127.0.0.1",
                "listen_port": base_port + idx
            })
            ob_copy = {k: v for k, v in c["outbound"].items() if not k.startswith("_")}
            ob_copy["tag"] = out_tag
            outbounds.append(ob_copy)
            rules.append({"inbound": in_tag, "outbound": out_tag})

        test_cfg = {
            "log": {"level": "error"},
            "dns": {
                "servers": [{"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}],
                "final": "dns-direct"
            },
            "inbounds": inbounds,
            "outbounds": outbounds,
            "route": {
                "default_domain_resolver": "dns-direct",
                "auto_detect_interface": True,
                "rules": rules,
                "final": "direct"
            }
        }
        test_cfg_path = "/tmp/singbox_wl_audit.json"
        with open(test_cfg_path, "w", encoding="utf-8") as f:
            json.dump(test_cfg, f)

        proc = subprocess.Popen([sb_bin, "run", "-c", test_cfg_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        try:
            wait_port(base_port, 2.0)
            with ThreadPoolExecutor(max_workers=24) as ex:
                futs = [ex.submit(probe_http204_via_port, base_port + i, c, starts, merged, 2.8) for i, c in enumerate(candidates)]
                for f in as_completed(futs):
                    score, item = f.result()
                    if score is not None:
                        verified.append((score, item))
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=1.0)
            except Exception:
                proc.kill()

    verified.sort(key=lambda x: x[0])
    alive = [x[1] for x in verified]
    if not alive:
        alive = candidates[:25]

    frozen_items = [s for s in wl if s.get("outbound", {}).get("type") != "urltest" and s.get("frozen")]
    final_list = apply_freeze_and_urltest(alive + frozen_items, frozen_set, f"Авто-выбор • {len(alive)} проверенных серверов")

    st["wl_servers"] = final_list
    st["wl_selected_index"] = 0
    st["wl_server_name"] = final_list[0]["name"] if final_list else "Нет серверов"
    st = sync_active_server_list(st)
    save_state(st)
    return st

def detect_physical_interface():
    pref_path = os.path.expanduser("~/.config/hypr/scripts/preferred_net_iface.txt")
    if os.path.exists(pref_path):
        try:
            pref = open(pref_path, "r", encoding="utf-8").read().strip()
            if pref and os.path.exists(f"/sys/class/net/{pref}"):
                return pref
        except Exception:
            pass
    try:
        out = subprocess.check_output(["ip", "-4", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            parts = line.split()
            if "dev" in parts:
                dev = parts[parts.index("dev") + 1]
                if not any(dev.startswith(p) for p in ("tun", "tap", "singbox", "throne", "lo", "virbr", "docker", "veth", "wg")):
                    return dev
    except Exception:
        pass
    return ""

def collect_outbound_exclude_cidrs(outbound):
    cidrs = ["127.0.0.0/8"]
    obs = outbound.get("_pool", [outbound]) if outbound.get("type") == "urltest" else [outbound]
    for ob in obs:
        host = (ob.get("server") or "").strip()
        if IPV4_RE.match(host):
            c = f"{host}/32"
            if c not in cidrs:
                cidrs.append(c)
    return cidrs

def has_cap_net_admin(sb_bin):
    try:
        out = subprocess.check_output(["getcap", sb_bin], text=True, stderr=subprocess.DEVNULL)
        return "cap_net_admin" in out
    except Exception:
        return False

def build_config(outbound, st, use_tun=False):
    split_mode = st.get("split_mode", "ru_direct" if st.get("ru_direct", True) else "all_vpn")
    blocked_domains, ru_domains, blocked_cidrs, ru_cidrs = load_bypass_routing_sets(st)

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
            "address": ["172.19.0.1/30"],
            "mtu": 1320,
            "auto_route": True,
            "strict_route": False,
            "route_exclude_address": collect_outbound_exclude_cidrs(outbound),
            "stack": "gvisor"
        })

    rules = [
        {"action": "sniff", "timeout": "300ms"},
        {"protocol": "dns", "action": "hijack-dns"},
        {"ip_is_private": True, "outbound": "direct"},
        {"network": "udp", "port": 443, "action": "reject"}
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
        if ru_cidrs:
            rules.append({"ip_cidr": ru_cidrs, "outbound": "direct"})
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
        "log": {"level": st.get("log_level", "info")},
        "dns": {
            "servers": [
                {"type": "tls", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"},
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
            **({"default_interface": detect_physical_interface()} if detect_physical_interface() else {}),
            "rules": rules,
            "final": route_final
        }
    }

def sync_active_server_list(st):
    frozen_set = set(st.get("frozen_sigs", []))
    urls = read_sub_urls()
    sub_cache = st.get("sub_cache", {})
    if urls and not sub_cache and st.get("sub_servers"):
        sub_cache[urls[0]] = {"title": short_sub_title(urls[0], 0), "servers": st["sub_servers"]}
        st["sub_cache"] = sub_cache

    sub_srvs, _ = rebuild_sub_servers_from_cache(urls, sub_cache, frozen_set, mark_wl_badges=False)
    st["sub_servers"] = sub_srvs

    if sub_srvs:
        s_idx = min(max(0, st.get("sub_selected_index", 0)), len(sub_srvs) - 1)
        st["sub_selected_index"] = s_idx
        st["sub_server_name"] = sub_srvs[s_idx]["name"]
    else:
        st["sub_selected_index"] = 0
        st["sub_server_name"] = "Нет серверов"

    wl_file = st.get("whitelist_file", "auto")
    if not st.get("wl_servers") or wl_file == "my_wl_subs":
        st["wl_servers"] = load_whitelist_servers(st, wl_file)
    else:
        st["wl_servers"] = apply_freeze_and_urltest(st["wl_servers"], frozen_set)

    wl_srvs = st.get("wl_servers", [])
    if wl_srvs:
        w_idx = min(max(0, st.get("wl_selected_index", 0)), len(wl_srvs) - 1)
        st["wl_selected_index"] = w_idx
        st["wl_server_name"] = wl_srvs[w_idx]["name"]
    else:
        st["wl_selected_index"] = 0
        st["wl_server_name"] = "Нет серверов"

    use_wl_ob = st.get("active_is_wl", st.get("whitelist_mode", False))
    if st.get("whitelist_mode", False):
        st["servers"] = wl_srvs
        st["selected_index"] = st["wl_selected_index"]
        st["server_name"] = st["wl_server_name"]
    else:
        st["servers"] = sub_srvs
        st["selected_index"] = st["sub_selected_index"]
        st["server_name"] = st["sub_server_name"]

    if use_wl_ob:
        if wl_srvs:
            st["outbound"] = wl_srvs[st["wl_selected_index"]]["outbound"]
        else:
            st.pop("outbound", None)
    else:
        if sub_srvs:
            st["outbound"] = sub_srvs[st["sub_selected_index"]]["outbound"]
        else:
            st.pop("outbound", None)
    return st

def fetch_subscriptions(is_wl=False, only_url=None):
    st = load_state()
    urls = read_wl_sub_urls() if is_wl else read_sub_urls()
    cache_key = "wl_sub_cache" if is_wl else "sub_cache"
    cache = st.get(cache_key, {})

    for idx, u in enumerate(urls):
        if only_url and u != only_url:
            continue
        title, parsed = fetch_single_url(u)
        if parsed:
            cache[u] = {
                "title": short_sub_title(u, idx, title),
                "servers": parsed
            }
    for k in list(cache.keys()):
        if k not in urls:
            del cache[k]

    st[cache_key] = cache
    if is_wl and st.get("whitelist_file") == "my_wl_subs":
        st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs")
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

def stop_vpn(save_disabled=True):
    if save_disabled:
        st = load_state()
        st["vpn_enabled"] = False
        save_state(st)
    set_desktop_proxy(False)
    subprocess.run(["pkill", "-f", "sing-box.*singbox_vpn.json"], stderr=subprocess.DEVNULL)
    subprocess.run(["killall", "-q", "Throne", "throne", "ThroneCore", "hiddify", "HiddifyCli"], stderr=subprocess.DEVNULL)
    for _ in range(30):
        if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode != 0:
            break
        time.sleep(0.05)
    time.sleep(0.15)

def detect_live_location():
    proxy_handler = urllib.request.ProxyHandler({"http": "http://127.0.0.1:2080", "https": "http://127.0.0.1:2080"})
    opener = urllib.request.build_opener(proxy_handler)
    try:
        req = urllib.request.Request("http://ip-api.com/json/?fields=status,country,countryCode,city&lang=ru", headers={"User-Agent": "curl/8.0"})
        with opener.open(req, timeout=3.5) as r:
            d = json.loads(r.read().decode("utf-8", errors="ignore"))
        if d.get("status") == "success" and d.get("country"):
            country = d.get("country", "")
            city = d.get("city", "")
            return f"{country}, {city}" if city else country
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
    stop_vpn(save_disabled=False)
    st = load_state()
    st["vpn_enabled"] = True
    st["active_is_wl"] = st.get("whitelist_mode", False)
    st = sync_active_server_list(st)
    if not st.get("servers") and not st.get("whitelist_mode"):
        st = fetch_subscriptions(is_wl=False)
    if "outbound" not in st or not st.get("servers"):
        save_state(st)
        return False

    if st["outbound"].get("type") == "urltest" and "_pool" in st["outbound"]:
        raw_pool = st["outbound"]["_pool"]
        alive_pool = []
        with ThreadPoolExecutor(max_workers=16) as ex:
            futs = {ex.submit(tcp_quick_filter, {"outbound": p}, 0.65): p for p in raw_pool[:20]}
            for f in as_completed(futs):
                ok, _ = f.result()
                if ok:
                    alive_pool.append(futs[f])
        if alive_pool:
            st["outbound"]["_pool"] = alive_pool[:8]
            st["outbound"]["outbounds"] = [p["tag"] for p in st["outbound"]["_pool"]]

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
                    st["sub_server_name"] = loc
                    idx = st.get("sub_selected_index", 0)
                    if 0 <= idx < len(st.get("sub_servers", [])):
                        st["sub_servers"][idx]["name"] = loc
            save_state(st)
            return True
        else:
            stop_vpn(save_disabled=False)
    return False

def dump_status_json():
    st = load_state()
    st = sync_active_server_list(st)
    save_state(st)
    frozen_set = set(st.get("frozen_sigs", []))
    urls = read_sub_urls()
    wl_urls = read_wl_sub_urls()
    _, sub_groups = rebuild_sub_servers_from_cache(urls, st.get("sub_cache", {}), frozen_set, mark_wl_badges=False)
    _, wl_sub_groups = rebuild_sub_servers_from_cache(wl_urls, st.get("wl_sub_cache", {}), frozen_set, mark_wl_badges=True)

    sub_srv_names = []
    sub_srv_items = []
    for i, s in enumerate(st.get("sub_servers", [])):
        nm = s.get("name", f"Сервер {i+1}")
        ob = s.get("outbound", {})
        uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
        sig = s.get("sig", "") or server_sig(ob)
        frz = bool(s.get("frozen", False) or (sig and sig in frozen_set))
        sub_srv_names.append(nm)
        sub_srv_items.append({"name": nm, "uri": uri, "sig": sig, "frozen": frz, "global_index": i})

    wl_srv_names = []
    wl_srv_items = []
    for i, s in enumerate(st.get("wl_servers", [])):
        nm = s.get("name", f"Сервер {i+1}")
        ob = s.get("outbound", {})
        uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
        sig = s.get("sig", "") or server_sig(ob)
        frz = bool(s.get("frozen", False) or (sig and sig in frozen_set))
        wl_srv_names.append(nm)
        wl_srv_items.append({"name": nm, "uri": uri, "sig": sig, "frozen": frz, "global_index": i})

    srv_names = wl_srv_names if st.get("whitelist_mode", False) else sub_srv_names
    wl_files = [{"key": k, "label": lbl} for k, lbl, _ in WHITELIST_SOURCES]
    blocked_d, ru_d, _, _ = load_bypass_routing_sets(st)
    hint = f"Маршруты: {len(blocked_d)} в обход • {len(ru_d)} РФ напрямую"
    out = {
        "server_name": st.get("server_name", "VPN"),
        "sub_server_name": st.get("sub_server_name", "VPN"),
        "wl_server_name": st.get("wl_server_name", "Авто-выбор лучшего сервера"),
        "ru_direct": st.get("ru_direct", True),
        "split_mode": st.get("split_mode", "ru_direct"),
        "vpn_enabled": st.get("vpn_enabled", False),
        "active_is_wl": st.get("active_is_wl", st.get("whitelist_mode", False)),
        "whitelist_mode": st.get("whitelist_mode", False),
        "whitelist_file": st.get("whitelist_file", "auto"),
        "whitelist_files": wl_files,
        "selected_index": st.get("selected_index", 0),
        "sub_selected_index": st.get("sub_selected_index", 0),
        "wl_selected_index": st.get("wl_selected_index", 0),
        "servers": srv_names,
        "sub_servers": sub_srv_names,
        "wl_servers": wl_srv_names,
        "sub_server_items": sub_srv_items,
        "wl_server_items": wl_srv_items,
        "frozen_count": len(frozen_set),
        "urls": urls,
        "wl_urls": wl_urls,
        "sub_groups": sub_groups,
        "wl_sub_groups": wl_sub_groups,
        "custom_proxy_domains": st.get("custom_proxy_domains", []),
        "custom_direct_domains": st.get("custom_direct_domains", []),
        "status_hint": hint,
        "log_level": st.get("log_level", "info")
    }
    print(json.dumps(out, ensure_ascii=False))

def restart_if_running():
    if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
        start_vpn()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        dump_status_json()
    elif cmd == "boot":
        st = load_state()
        is_running = (subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0)
        if st.get("vpn_enabled", False) and not is_running:
            start_vpn()
        dump_status_json()
    elif cmd == "update":
        fetch_subscriptions(is_wl=False)
        fetch_subscriptions(is_wl=True)
        dump_status_json()
    elif cmd == "update_lists":
        if os.path.exists(UPDATE_SCRIPT):
            subprocess.run(["/usr/bin/bash", UPDATE_SCRIPT], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        st = load_state()
        st["wl_servers"] = load_whitelist_servers(st, st.get("whitelist_file", "auto"))
        st = sync_active_server_list(st)
        save_state(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "set_whitelist_mode":
        st = load_state()
        st["whitelist_mode"] = (sys.argv[2] == "1") if len(sys.argv) > 2 else False
        st = sync_active_server_list(st)
        save_state(st)
        dump_status_json()
    elif cmd == "start_mode":
        st = load_state()
        is_wl = (sys.argv[2] == "1") if len(sys.argv) > 2 else st.get("whitelist_mode", False)
        st["whitelist_mode"] = is_wl
        st["active_is_wl"] = is_wl
        st["vpn_enabled"] = True
        st = sync_active_server_list(st)
        save_state(st)
        start_vpn()
        dump_status_json()
    elif cmd == "set_whitelist_file":
        if len(sys.argv) > 2:
            st = load_state()
            st["whitelist_file"] = sys.argv[2].strip()
            st["wl_selected_index"] = 0
            st["wl_servers"] = load_whitelist_servers(st, st["whitelist_file"])
            st = sync_active_server_list(st)
            save_state(st)
            restart_if_running()
        dump_status_json()
    elif cmd == "test_whitelist":
        st = load_state()
        st = test_and_sort_whitelist(st)
        restart_if_running()
        dump_status_json()
    elif cmd == "toggle_freeze":
        if len(sys.argv) > 3:
            idx = int(sys.argv[2])
            is_wl = (sys.argv[3] == "1")
            st = load_state()
            st = sync_active_server_list(st)
            target_list = st.get("wl_servers", []) if is_wl else st.get("sub_servers", [])
            if 0 <= idx < len(target_list):
                ob = target_list[idx].get("outbound", {})
                sig = target_list[idx].get("sig") or server_sig(ob)
                if sig:
                    frz = st.get("frozen_sigs", [])
                    if sig in frz:
                        frz.remove(sig)
                    else:
                        frz.append(sig)
                    st["frozen_sigs"] = frz
                    if is_wl:
                        st["wl_selected_index"] = 0
                    st = sync_active_server_list(st)
                    save_state(st)
                    restart_if_running()
        dump_status_json()
    elif cmd == "clear_frozen":
        st = load_state()
        st["frozen_sigs"] = []
        st = sync_active_server_list(st)
        save_state(st)
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
    elif cmd in ("add_url", "add_wl_url"):
        is_wl = (cmd == "add_wl_url")
        if len(sys.argv) > 2 and sys.argv[2].strip():
            raw_in = sys.argv[2].strip()
            urls = read_wl_sub_urls() if is_wl else read_sub_urls()
            for part in raw_in.split():
                u = part.strip()
                if u and u not in urls:
                    urls.append(u)
                    if is_wl:
                        write_wl_sub_urls(urls)
                    else:
                        write_sub_urls(urls)
                    fetch_subscriptions(is_wl=is_wl, only_url=u)
            if is_wl:
                st = load_state()
                st["whitelist_file"] = "my_wl_subs"
                st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs")
                st = sync_active_server_list(st)
                save_state(st)
        dump_status_json()
    elif cmd in ("remove_url", "remove_wl_url"):
        is_wl = (cmd == "remove_wl_url")
        if len(sys.argv) > 2:
            idx = int(sys.argv[2])
            urls = read_wl_sub_urls() if is_wl else read_sub_urls()
            if 0 <= idx < len(urls):
                removed = urls.pop(idx)
                if is_wl:
                    write_wl_sub_urls(urls)
                else:
                    write_sub_urls(urls)
                st = load_state()
                cache_key = "wl_sub_cache" if is_wl else "sub_cache"
                cache = st.get(cache_key, {})
                cache.pop(removed, None)
                st[cache_key] = cache
                if is_wl and st.get("whitelist_file") == "my_wl_subs":
                    st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs")
                st = sync_active_server_list(st)
                save_state(st)
        dump_status_json()
    elif cmd == "select_server":
        if len(sys.argv) > 2:
            idx = int(sys.argv[2])
            st = load_state()
            st = sync_active_server_list(st)
            if st.get("whitelist_mode", False):
                wl_srvs = st.get("wl_servers", [])
                if 0 <= idx < len(wl_srvs):
                    st["wl_selected_index"] = idx
            else:
                sub_srvs = st.get("sub_servers", [])
                if 0 <= idx < len(sub_srvs):
                    st["sub_selected_index"] = idx
            st = sync_active_server_list(st)
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
    elif cmd == "get_logs":
        max_lines = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        log_path = "/tmp/singbox_vpn.log"
        lines = []
        if os.path.exists(log_path):
            try:
                with open(log_path, "r", encoding="utf-8", errors="ignore") as f:
                    all_l = [ re.sub(r"\x1b\[[0-9;]*m", "", ln.rstrip()) for ln in f.readlines() if ln.strip() ]
                    lines = all_l[-max_lines:]
            except Exception:
                pass
        if not lines:
            lines = ["Журнал пуст. Включите VPN или запустите проверку серверов."]
        print(json.dumps({"logs": lines}, ensure_ascii=False))
    elif cmd == "clear_logs":
        try:
            open("/tmp/singbox_vpn.log", "w").close()
        except Exception:
            pass
        print(json.dumps({"logs": ["Журнал очищен."]}, ensure_ascii=False))
    elif cmd == "set_log_level":
        if len(sys.argv) > 2:
            lvl = sys.argv[2].strip()
            if lvl in ("info", "warn", "debug"):
                st = load_state()
                st["log_level"] = lvl
                save_state(st)
                restart_if_running()
        dump_status_json()
    elif cmd == "start":
        start_vpn()
        dump_status_json()
    elif cmd == "stop":
        stop_vpn(save_disabled=True)
