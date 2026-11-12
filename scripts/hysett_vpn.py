#!/usr/bin/env python3
import sys, os, json, base64, urllib.request, urllib.parse, subprocess, shutil, socket, time, re, ipaddress, bisect, uuid as uuid_lib
from concurrent.futures import ThreadPoolExecutor, as_completed

HYSETT_DIR = os.path.expanduser("~/hysett")
CONF_DIR = os.path.expanduser("~/.config/hypr/scripts")
SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_sub.txt")
WL_SUB_FILE = os.path.expanduser("~/.config/hysett_vpn_wl_sub.txt")
STATE_FILE = os.path.join(CONF_DIR, "vpn_state.json")
SB_CONF = os.path.join(CONF_DIR, "singbox_vpn.json")
PROG_FILE = "/tmp/hysett_vpn_progress.json"
BYPASS_REPOS = os.path.join(HYSETT_DIR, "bypass-lists/repos")
if not os.path.exists(BYPASS_REPOS):
    BYPASS_REPOS = os.path.expanduser("~/bypass-lists/repos")
UPDATE_SCRIPT = os.path.join(HYSETT_DIR, "scripts/update-bypass-lists.sh")

def write_progress(pct, text):
    try:
        tmp = PROG_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"percent": int(pct), "text": str(text)}, f, ensure_ascii=False)
        os.replace(tmp, PROG_FILE)
    except Exception:
        pass

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

COUNTRY_KEYWORDS = [
    (("нидерланд", "netherlands", "holland", "amsterdam", "nl"), "NL"),
    (("герман", "germany", "frankfurt", "falkenstein", "berlin", "de"), "DE"),
    (("финлянд", "finland", "helsinki", "fi"), "FI"),
    (("франц", "france", "paris", "strasbourg", "fr"), "FR"),
    (("сша", "usa", "united states", "new york", "miami", "dallas", "los angeles", "us"), "US"),
    (("великобрит", "united kingdom", "london", "england", "uk", "gb"), "GB"),
    (("швец", "sweden", "stockholm", "se"), "SE"),
    (("польш", "poland", "warsaw", "pl"), "PL"),
    (("турц", "turkey", "istanbul", "tr"), "TR"),
    (("эстон", "estonia", "tallinn", "ee"), "EE"),
    (("латв", "latvia", "riga", "lv"), "LV"),
    (("литв", "lithuania", "vilnius", "lt"), "LT"),
    (("швейцар", "switzerland", "zurich", "ch"), "CH"),
    (("австр", "austria", "vienna", "at"), "AT"),
    (("чех", "czech", "prague", "cz"), "CZ"),
    (("испан", "spain", "madrid", "es"), "ES"),
    (("итал", "italy", "milan", "it"), "IT"),
    (("канад", "canada", "toronto", "ca"), "CA"),
    (("япон", "japan", "tokyo", "jp"), "JP"),
    (("сингапур", "singapore", "sg"), "SG"),
    (("казах", "kazakhstan", "almaty", "kz"), "KZ"),
    (("росси", "russia", "moscow", "москва", "spb", "petersburg", "ru"), "RU"),
]

WHITELIST_SOURCES = [
    ("auto", "󰓅 Все проверенные БС", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt",
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt",
        "vpn-configs/white_sni_ru.txt",
        "vpn-configs/whitelist_cidr1_ru.txt",
        "wl/vless_lite.txt",
        "wl/vless.txt",
        "V.O.I.D-VPN_Bypass/hysett_wl.txt"
    ]),
    ("my_wl_subs", "󰌘 Мои подписки БС", []),
    ("zieng2_wl", "󰄜 zieng2 Mobile БС", [
        "wl/vless_lite.txt",
        "wl/vless.txt",
        "wl/vless_universal.txt"
    ]),
    ("igareck_mobile", "󰄜 igareck Mobile БС", [
        "vpn-configs-for-russia/Vless-Reality-White-Lists-Rus-Mobile.txt"
    ]),
    ("igareck_cidr_checked", "󰞀 igareck CIDR РФ", [
        "vpn-configs-for-russia/WHITE-CIDR-RU-checked.txt"
    ]),
    ("igareck_sni", "󰒃 igareck Белый SNI", [
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
    ("void_wl", "󰞀 VOID Bypass БС", [
        "V.O.I.D-VPN_Bypass/hysett_wl.txt"
    ]),
    ("all_subs_wl", "󰒃 all_subs (только БС)", [
        "all_subs/hysett_wl.txt"
    ]),
    ("goida_wl", "󰦝 Goida (только БС)", [
        "goida-vpn-configs/hysett_wl.txt"
    ])
]

BLACKLIST_SOURCES = [
    ("bl_igareck_vless", "󰦝 ЧС: igareck VLESS", [
        "vpn-configs-for-russia/BLACK_VLESS_RUS.txt"
    ]),
    ("bl_igareck_mobile", "󰄜 ЧС: igareck Mobile", [
        "vpn-configs-for-russia/BLACK_VLESS_RUS_mobile.txt"
    ]),
    ("bl_wlunlocker_1", "󰈀 ЧС: wlunlocker #1", [
        "vpn-configs/blacklist_vpn1.txt"
    ]),
    ("bl_wlunlocker_2", "󰈀 ЧС: wlunlocker #2", [
        "vpn-configs/blacklist_vpn2.txt"
    ]),
    ("bl_wlunlocker_all", "󰈀 ЧС: wlunlocker Все", [
        "vpn-configs/blacklist_all.txt"
    ]),
    ("bl_all_subs", "󰒃 ЧС: all_subs", [
        "all_subs/hysett_wl.txt"
    ]),
    ("bl_goida", "󰦝 ЧС: Goida VLESS", [
        "goida-vpn-configs/hysett_wl.txt"
    ])
]

DOMAIN_RE = re.compile(r"^[a-zA-Z0-9._-]+(\.[a-zA-Z0-9_-]+)+$")
CIDR_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}(/\d{1,2})?$")
IPV4_RE = re.compile(r"^\d{1,3}(\.\d{1,3}){3}$")

def extract_country_from_text(raw_text):
    if not raw_text:
        return ""
    # 1. Извлекаем ISO-код страны напрямую из региональных эмодзи-флагов (🇳🇱 -> NL, 🇩🇪 -> DE)
    pts = [ord(c) for c in raw_text]
    for i in range(len(pts) - 1):
        if 0x1F1E6 <= pts[i] <= 0x1F1FF and 0x1F1E6 <= pts[i + 1] <= 0x1F1FF:
            cc = chr(pts[i] - 0x1F1E6 + 65) + chr(pts[i + 1] - 0x1F1E6 + 65)
            if cc not in ("EU", "UN"):
                return cc
    low = raw_text.lower()
    for kw_tuple, code in COUNTRY_KEYWORDS:
        for kw in kw_tuple:
            if len(kw) <= 2:
                if re.search(rf"\b{kw}\b", low):
                    return code
            elif kw in low:
                return code
    return ""

def resolve_countries_batch(srv_list, country_cache, ru_starts=None, ru_merged=None):
    if not isinstance(country_cache, dict):
        country_cache = {}
    to_query = []
    seen_ips = set()
    for s in srv_list:
        ob = s.get("outbound", {})
        if not isinstance(ob, dict) or ob.get("type") == "urltest":
            continue
        host = (ob.get("server") or "").strip()
        cc = s.get("country") or extract_country_from_text(s.get("raw_name", "") or s.get("name", ""))
        if not cc and host in country_cache:
            cc = country_cache[host]
        if not cc and IPV4_RE.match(host) and ru_starts and check_ip_in_intervals(host, ru_starts, ru_merged):
            cc = "RU"
            country_cache[host] = "RU"
        if cc:
            s["country"] = cc
        elif IPV4_RE.match(host) and host not in seen_ips and len(to_query) < 80:
            seen_ips.add(host)
            to_query.append(host)

    if to_query:
        try:
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
            payload = json.dumps([{"query": ip, "fields": "query,countryCode"} for ip in to_query]).encode("utf-8")
            req = urllib.request.Request(
                "http://ip-api.com/batch",
                data=payload,
                headers={"Content-Type": "application/json", "User-Agent": "curl/8.0"}
            )
            with opener.open(req, timeout=1.8) as r:
                resp = json.loads(r.read().decode("utf-8", errors="ignore"))
                if isinstance(resp, list):
                    for entry in resp:
                        q_ip = entry.get("query", "")
                        c_code = entry.get("countryCode", "")
                        if q_ip and c_code:
                            country_cache[q_ip] = c_code
        except Exception:
            pass

    for s in srv_list:
        if not s.get("country"):
            ob = s.get("outbound", {})
            host = (ob.get("server") or "").strip() if isinstance(ob, dict) else ""
            if host and host in country_cache:
                s["country"] = country_cache[host]

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

def clean_server_title(text, fallback_host=""):
    raw = text or ""
    s = re.sub(r"(?:https?://|t\.me/)\S+", " ", raw, flags=re.IGNORECASE)
    s = re.sub(r"@[A-Za-z0-9_]{3,}", " ", s)
    no_br = re.sub(r"\([^)]*\)|\[[^\]]*\]", " ", s)
    if len(re.findall(r"[A-Za-zА-Яа-яЁё]", no_br)) >= 2:
        s = no_br
    s = re.sub(r"[^A-Za-zА-Яа-яЁё0-9\s:#/.-]+", " ", s)
    s = re.sub(r"(?:^|\s)[._:/#-]+(?:\s|$)", " ", s)
    s = re.sub(r"\s+", " ", s).strip(" .-:/#")
    if len(re.findall(r"[A-Za-zА-Яа-яЁё]", s)) < 2:
        return fallback_host if fallback_host else "Сервер"
    return s[:48]

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
        "active_is_wl": False,
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
        "ping_cache": {},
        "country_cache": {},
        "bl_groups_cache": [],
        "cached_hint": "",
        "ip_check_state": 0,
        "ip_check_text": "",
        "wl_servers": [],
        "frozen_sigs": [],
        "pinned_sigs": [],
        "verified_sigs": [],
        "pinned_wl_items": [],
        "last_updated": "",
        "custom_proxy_domains": [],
        "custom_direct_domains": []
    }
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                st.update(json.load(f))
        except Exception:
            pass
    for k in ("sub_cache", "wl_sub_cache", "ping_cache", "country_cache"):
        if not isinstance(st.get(k), dict):
            st[k] = {}
    for k in ("frozen_sigs", "pinned_sigs", "verified_sigs", "pinned_wl_items"):
        if not isinstance(st.get(k), list):
            st[k] = []
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    st.pop("url", None)
    for ck in ("ping_cache", "country_cache"):
        d = st.get(ck)
        if isinstance(d, dict) and len(d) > 350:
            keys = list(d.keys())[-300:]
            st[ck] = {k: d[k] for k in keys}
    tmp = STATE_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)
    os.replace(tmp, STATE_FILE)

def parse_uri(uri, strict_for_public=False):
    uri = uri.strip()
    if not uri or "://" not in uri:
        return None, None, ""
    try:
        u = urllib.parse.urlsplit(uri)
        scheme = u.scheme.lower()
        raw_name = urllib.parse.unquote(u.fragment or "").strip()
        q = dict(urllib.parse.parse_qsl(u.query))
        host = (u.hostname or "").strip()
        port = int(u.port or 443)
        country = extract_country_from_text(raw_name)
        name = clean_server_title(raw_name, f"{host}:{port}")
        if not name or name == "Сервер":
            name = f"{host}:{port}"
        elif host and host not in name and len(name) <= 18:
            name = f"{name} • {host}"
    except Exception:
        return None, None, ""

    if not host or port <= 0 or port > 65535:
        return None, None, ""

    net_type = q.get("type", "tcp").lower()
    if net_type in ("xhttp", "splithttp", "kcp", "quic"):
        return None, None, ""

    if scheme == "vless":
        uuid = urllib.parse.unquote(u.username or "").strip()
        if len(uuid) < 8:
            return None, None, ""
        if strict_for_public:
            try:
                uuid = str(uuid_lib.UUID(uuid))
            except Exception:
                return None, None, ""
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
            return None, None, ""
    elif scheme == "trojan":
        pw = urllib.parse.unquote(u.username or "").strip()
        if not pw:
            return None, None, ""
        ob = {"type": "trojan", "tag": "proxy", "server": host, "server_port": port, "password": pw}
    elif scheme in ("hy2", "hysteria2"):
        pw = urllib.parse.unquote(u.username or "").strip()
        if not pw:
            return None, None, ""
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
                return None, None, ""
        method, _, pw = userinfo.partition(":")
        if not method or not pw:
            return None, None, ""
        ob = {"type": "shadowsocks", "tag": "proxy", "server": host, "server_port": port, "method": method, "password": pw}
    else:
        return None, None, ""

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
            if not pbk:
                return None, None, ""
            if strict_for_public and not re.match(r"^[0-9a-fA-F]{0,16}$", sid):
                return None, None, ""
            if strict_for_public:
                try:
                    pad_pbk = pbk + "=" * ((4 - len(pbk) % 4) % 4)
                    raw_pbk = base64.urlsafe_b64decode(pad_pbk.encode("ascii"))
                    if len(raw_pbk) != 32:
                        return None, None, ""
                except Exception:
                    return None, None, ""
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
    return name, ob, country

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
        "gstatic.com", "googleapis.com", "2ip.ru", "2ip.io", "api.2ip.io"
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
        b64_str = re.sub(r"\s+", "", raw)
        pad = len(b64_str) % 4
        if pad:
            b64_str += "=" * (4 - pad)
        try:
            raw = base64.b64decode(b64_str).decode("utf-8", errors="ignore")
        except Exception:
            try:
                raw = base64.urlsafe_b64decode(b64_str).decode("utf-8", errors="ignore")
            except Exception:
                pass

    if raw.startswith("{"):
        try:
            data = json.loads(raw)
            for idx, ob in enumerate(data.get("outbounds", [])):
                if ob.get("type") in ("vless", "trojan", "hysteria2", "shadowsocks", "vmess"):
                    ob["tag"] = "proxy"
                    raw_nm = ob.get("tag_name") or ob.get("server") or f"Сервер {idx+1}"
                    cc = extract_country_from_text(raw_nm)
                    nm = clean_server_title(raw_nm, ob.get("server", ""))
                    found.append({"name": nm, "raw_name": raw_nm, "country": cc, "outbound": ob, "uri": rebuild_uri_from_outbound(ob, nm)})
        except Exception:
            pass
        return found

    for line in raw.splitlines():
        line = line.strip()
        if any(line.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
            name, ob, cc = parse_uri(line, strict_for_public=False)
            if ob:
                found.append({"name": name, "country": cc, "outbound": ob, "uri": line})
    return found

def fetch_single_url(u):
    if any(u.startswith(p) for p in ("vless://", "trojan://", "hy2://", "hysteria2://", "ss://")):
        name, ob, cc = parse_uri(u, strict_for_public=False)
        if ob:
            return "", [{"name": name, "country": cc, "outbound": ob, "uri": u}]
        return "", []

    # Сначала пробуем напрямую, а если подписка заблокирована РКН и работает локальный прокси 2080 — пробуем через него
    handlers = [urllib.request.ProxyHandler({})]
    if wait_port(2080, 0.05):
        handlers.append(urllib.request.ProxyHandler({"http": "http://127.0.0.1:2080", "https": "http://127.0.0.1:2080"}))

    for h in handlers:
        opener = urllib.request.build_opener(h)
        for ua in ("v2rayN/6.45", "SFA/1.11.0 sing-box/1.11.0", "ClashMetaForAndroid/2.10.1", "Mozilla/5.0"):
            try:
                req = urllib.request.Request(u, headers={"User-Agent": ua})
                with opener.open(req, timeout=7) as r:
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
            except Exception:
                pass
    return "", []

def detect_physical_interface():
    routed_devs = []
    try:
        out = subprocess.check_output(["ip", "-4", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL)
        for line in out.splitlines():
            parts = line.split()
            if "dev" in parts:
                dev = parts[parts.index("dev") + 1]
                if not any(dev.startswith(p) for p in ("tun", "tap", "singbox", "throne", "lo", "virbr", "docker", "veth", "wg")):
                    routed_devs.append(dev)
    except Exception:
        pass
    pref_path = os.path.expanduser("~/.config/hypr/scripts/preferred_net_iface.txt")
    if os.path.exists(pref_path):
        try:
            pref = open(pref_path, "r", encoding="utf-8").read().strip()
            carrier_file = f"/sys/class/net/{pref}/carrier"
            carrier_ok = os.path.exists(carrier_file) and open(carrier_file).read().strip() == "1"
            if pref and carrier_ok and (not routed_devs or pref in routed_devs):
                return pref
        except Exception:
            pass
    return routed_devs[0] if routed_devs else ""

def quick_host_ping_ms(host, port=443, timeout=0.45):
    if not host:
        return None
    t0 = time.monotonic()
    try:
        with socket.create_connection((host, int(port or 443)), timeout=timeout) as sock:
            tcp_ms = int((time.monotonic() - t0) * 1000)
            if tcp_ms >= 4:
                return tcp_ms
            sock.settimeout(timeout)
            t1 = time.monotonic()
            sock.sendall(b"HEAD / HTTP/1.0\r\nHost: " + host.encode("ascii", errors="ignore") + b"\r\n\r\n")
            data = sock.recv(1)
            if data:
                real_ms = int((time.monotonic() - t1) * 1000)
                if real_ms >= 4:
                    return real_ms
    except Exception:
        pass
    return None

def extract_ping_str(name_str, ping_ms=0):
    if isinstance(ping_ms, int) and ping_ms > 3:
        return f"{ping_ms} мс"
    parts = [p.strip() for p in (name_str or "").split(" • ") if p.strip()]
    if parts and parts[0].endswith("мс"):
        try:
            v = int(parts[0].split()[0])
            if v > 3:
                return parts[0]
        except Exception:
            pass
    return ""

def populate_server_pings(srv_list, ping_cache, max_new_probes=24, timeout=0.45):
    if not isinstance(ping_cache, dict):
        ping_cache = {}
    to_probe = []
    for s in srv_list:
        ob = s.get("outbound", {})
        if not isinstance(ob, dict) or ob.get("type") == "urltest":
            continue
        existing_str = extract_ping_str(s.get("name", ""), int(s.get("ping_ms") or 0))
        if existing_str:
            s["ping"] = existing_str
            try:
                ms_val = int(existing_str.split()[0])
                if ms_val > 3:
                    s["ping_ms"] = ms_val
                    hp = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
                    ping_cache[hp] = ms_val
                    continue
            except Exception:
                pass
        hp = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
        cached_val = int(ping_cache.get(hp) or 0)
        if cached_val > 3:
            s["ping_ms"] = cached_val
            s["ping"] = f"{cached_val} мс"
        elif hp not in ping_cache and len(to_probe) < max_new_probes:
            to_probe.append((hp, ob.get("server", ""), ob.get("server_port", 443), s))

    if to_probe:
        with ThreadPoolExecutor(max_workers=12) as ex:
            futs = {ex.submit(quick_host_ping_ms, host, port, timeout): (hp, s_ref) for hp, host, port, s_ref in to_probe}
            for f in as_completed(futs):
                hp, s_ref = futs[f]
                ms = f.result()
                val = int(ms) if (ms is not None and ms > 3) else 0
                ping_cache[hp] = val
                s_ref["ping_ms"] = val
                s_ref["ping"] = f"{val} мс" if val > 3 else ""

    for s in srv_list:
        if not s.get("ping"):
            ob = s.get("outbound", {})
            if isinstance(ob, dict):
                hp = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
                ms_c = int(ping_cache.get(hp) or 0)
                if ms_c > 3:
                    s["ping_ms"] = ms_c
                    s["ping"] = f"{ms_c} мс"

def ensure_sub_cache_metadata(cache_dict, ping_cache, country_cache):
    all_s = []
    for u, entry in cache_dict.items():
        if isinstance(entry, dict):
            for s in entry.get("servers", []):
                if int(s.get("ping_ms") or 0) <= 3:
                    s.pop("ping_ms", None)
                    s.pop("ping", None)
                all_s.append(s)
    if all_s:
        populate_server_pings(all_s, ping_cache, max_new_probes=32, timeout=0.55)
        resolve_countries_batch(all_s, country_cache)

def load_blacklist_groups(all_srvs, frozen_set, pinned_set, ping_cache, country_cache, per_group_limit=28, allow_network_probe=False, verified_set=None):
    if verified_set is None:
        verified_set = set()
    bl_groups = []
    seen_sigs = {s.get("sig") for s in all_srvs if s.get("sig")}
    base_group_idx = 100
    for b_idx, (b_key, b_title, rel_files) in enumerate(BLACKLIST_SOURCES):
        raw_items = []
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
                            name, ob, cc = parse_uri(line, strict_for_public=True)
                            if not ob:
                                continue
                            sig = server_sig(ob)
                            if not sig or sig in seen_sigs:
                                continue
                            seen_sigs.add(sig)
                            hp = f"{ob['server']}:{ob['server_port']}"
                            p_ms = int(ping_cache.get(hp) or 0)
                            if not cc:
                                cc = country_cache.get(ob["server"], "")
                            raw_items.append({
                                "name": name[:52],
                                "country": cc,
                                "outbound": ob,
                                "uri": line,
                                "sig": sig,
                                "ping_ms": p_ms if p_ms > 3 else 0,
                                "ping": f"{p_ms} мс" if p_ms > 3 else ""
                            })
                            if len(raw_items) >= per_group_limit:
                                break
            except Exception:
                pass
            if len(raw_items) >= per_group_limit:
                break

        if not raw_items:
            continue
        if allow_network_probe:
            populate_server_pings(raw_items, ping_cache, max_new_probes=20, timeout=0.50)
            resolve_countries_batch(raw_items, country_cache)

        raw_items.sort(key=lambda x: (0 if int(x.get("ping_ms") or 0) > 3 else 1, int(x.get("ping_ms") or 9999)))
        start_idx = len(all_srvs)
        group_srv_names = []
        best_ms = None
        for s in raw_items:
            nm = s["name"]
            ob = s["outbound"]
            uri = s["uri"]
            sig = s["sig"]
            cc = s.get("country", "")
            p_ms = int(s.get("ping_ms") or 0)
            p_str = s.get("ping", "")
            if p_ms > 3 and (best_ms is None or p_ms < best_ms):
                best_ms = p_ms
            is_frz = sig in frozen_set
            is_pin = sig in pinned_set
            item = {
                "name": nm, "country": cc, "outbound": ob, "uri": uri, "sig": sig,
                "ping": p_str, "ping_ms": p_ms,
                "frozen": is_frz, "pinned": is_pin,
                "sub_index": base_group_idx + b_idx,
                "is_public_bl": True
            }
            all_srvs.append(item)
            group_srv_names.append({
                "name": nm, "country": cc, "uri": uri, "sig": sig, "ping": p_str,
                "frozen": is_frz, "pinned": is_pin, "verified": bool(sig and sig in verified_set) and not is_frz,
                "global_index": len(all_srvs) - 1
            })
        bl_groups.append({
            "index": base_group_idx + b_idx,
            "title": b_title,
            "url": "",
            "country": "",
            "is_public_bl": True,
            "ping": f"{best_ms} мс" if best_ms else "",
            "count": len(group_srv_names),
            "start_index": start_idx,
            "servers": group_srv_names
        })
    return bl_groups

def rebuild_sub_servers_from_cache(urls, cache_dict, frozen_set, mark_wl_badges=False, pinned_set=None, ping_cache=None, country_cache=None, include_public_bl=False, allow_network_probe=False, verified_set=None):
    if pinned_set is None:
        pinned_set = set()
    if verified_set is None:
        verified_set = set()
    if ping_cache is None:
        ping_cache = {}
    if country_cache is None:
        country_cache = {}
    starts, merged = (load_ru_whitelist_ip_intervals() if mark_wl_badges else ([], []))
    all_srvs = []
    groups = []

    # 1. Сначала идут все импортированные серверы из личных подписок (в приоритете!)
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
        best_group_ms = None
        group_cc = ""
        for s in srvs:
            ob = s.get("outbound", {})
            host = ob.get("server", "") if isinstance(ob, dict) else ""
            nm = clean_server_title(s.get("name", "Сервер"), host)
            uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
            sig = server_sig(ob)
            hp = f"{host}:{ob.get('server_port', 443)}"
            p_ms = int(s.get("ping_ms") or ping_cache.get(hp) or 0)
            if p_ms <= 3:
                p_ms = 0
            if p_ms > 3 and (best_group_ms is None or p_ms < best_group_ms):
                best_group_ms = p_ms
            p_str = extract_ping_str(nm, p_ms)
            cc = s.get("country") or extract_country_from_text(s.get("raw_name", "") or nm) or country_cache.get(host, "")
            if cc and not group_cc:
                group_cc = cc
            is_frz = (sig in frozen_set) if sig else False
            is_pin = (sig in pinned_set) if sig else False
            if mark_wl_badges and ob:
                badge, _ = classify_whitelist_badge(ob, starts, merged, resolve_dns=False)
                nm = f"{badge} • {nm}"
            item = {
                "name": nm, "country": cc, "outbound": ob, "uri": uri, "sig": sig,
                "ping": p_str, "ping_ms": p_ms,
                "frozen": is_frz, "pinned": is_pin,
                "sub_index": idx, "is_public_bl": False
            }
            all_srvs.append(item)
            group_srv_names.append({
                "name": nm, "country": cc, "uri": uri, "sig": sig, "ping": p_str,
                "frozen": is_frz, "pinned": is_pin, "verified": bool(sig and sig in verified_set) and not is_frz,
                "global_index": len(all_srvs) - 1
            })
        groups.append({
            "index": idx,
            "title": title,
            "url": u,
            "country": group_cc,
            "is_public_bl": False,
            "ping": f"{best_group_ms} мс" if best_group_ms else "",
            "count": len(srvs),
            "start_index": start_idx,
            "servers": group_srv_names
        })

    # 2. После импортированных серверов добавляем публичные серверы обхода Чёрных списков
    if include_public_bl and not mark_wl_badges:
        bl_groups = load_blacklist_groups(all_srvs, frozen_set, pinned_set, ping_cache, country_cache, per_group_limit=25, allow_network_probe=allow_network_probe, verified_set=verified_set)
        groups.extend(bl_groups)

    # 3. Формируем умный "Авто-выбор (Импорт в приоритете)" на позиции 0 для Обычного VPN
    if include_public_bl and not mark_wl_badges and all_srvs:
        imported_all = [s for s in all_srvs if not s.get("is_public_bl")]
        imported_alive = [s for s in imported_all if not s.get("frozen")]
        if not imported_alive and imported_all:
            # Если единственный сервер личной подписки был случайно заморожен — размораживаем его для Авто-выбора
            imported_all[0]["frozen"] = False
            imported_alive = [imported_all[0]]
        public_alive = [s for s in all_srvs if s.get("is_public_bl") and not s.get("frozen")]
        public_alive.sort(key=lambda x: (0 if x.get("verified") else 1, 0 if int(x.get("ping_ms") or 0) > 3 else 1, int(x.get("ping_ms") or 9999)))

        priority_pool_src = imported_alive if imported_alive else public_alive[:12]
        if priority_pool_src:
            best_first = priority_pool_src[0]
            if len(priority_pool_src) == 1:
                auto_ob = dict(best_first["outbound"], tag="proxy")
            else:
                pool = [dict(s["outbound"], tag=f"sub-{i}") for i, s in enumerate(priority_pool_src[:15])]
                auto_ob = {
                    "type": "urltest",
                    "tag": "proxy",
                    "outbounds": [p["tag"] for p in pool],
                    "url": "https://www.gstatic.com/generate_204",
                    "interval": "25s",
                    "tolerance": 50,
                    "_pool": pool
                }
            auto_label = f"Авто-выбор (Импорт: {best_first.get('name', 'VPN')})" if imported_alive else "Авто-выбор лучшего сервера ЧС"
            all_srvs.insert(0, {
                "name": auto_label,
                "country": best_first.get("country", ""),
                "ping": best_first.get("ping", ""),
                "ping_ms": best_first.get("ping_ms", 0),
                "uri": "",
                "sig": "",
                "frozen": False,
                "pinned": False,
                "is_public_bl": False,
                "outbound": auto_ob
            })
            # Сдвигаем global_index на +1 во всех группах
            for g in groups:
                g["start_index"] += 1
                for gs in g["servers"]:
                    gs["global_index"] += 1

    return all_srvs, groups

def apply_freeze_and_urltest(raw_servers, frozen_set, auto_title="Авто-выбор лучшего сервера", pinned_set=None, pinned_items=None, verified_set=None):
    if pinned_set is None:
        pinned_set = set()
    if verified_set is None:
        verified_set = set()
    if pinned_items is None:
        pinned_items = []

    real = [s for s in raw_servers if s.get("outbound", {}).get("type") != "urltest"]
    pinned_list = []
    normal_list = []
    seen_sigs = set()

    for ps in pinned_items:
        ob = ps.get("outbound", {})
        sig = ps.get("sig") or server_sig(ob)
        if not sig or sig not in pinned_set or sig in seen_sigs:
            continue
        seen_sigs.add(sig)
        uri = ps.get("uri") or rebuild_uri_from_outbound(ob, ps.get("name", "Server"))
        is_frz = sig in frozen_set
        pinned_list.append(dict(ps, sig=sig, uri=uri, frozen=is_frz, pinned=True))

    for s in real:
        ob = s.get("outbound", {})
        sig = s.get("sig") or server_sig(ob)
        uri = s.get("uri") or rebuild_uri_from_outbound(ob, s.get("name", "Server"))
        is_frz = sig in frozen_set if sig else False
        is_pin = sig in pinned_set if sig else False
        if sig and sig in seen_sigs:
            continue
        if sig:
            seen_sigs.add(sig)
        item = dict(s, sig=sig, uri=uri, frozen=is_frz, pinned=is_pin)
        if is_pin:
            pinned_list.append(item)
        else:
            normal_list.append(item)

    ordered = pinned_list + normal_list
    alive_for_pool = [s for s in ordered if not s.get("frozen")]
    if len(alive_for_pool) >= 1:
        pool = [dict(s["outbound"], tag=f"wl-{i}") for i, s in enumerate(alive_for_pool[:20])]
        best_s = alive_for_pool[0]
        ordered.insert(0, {
            "name": auto_title,
            "country": best_s.get("country", ""),
            "ping": best_s.get("ping", ""),
            "ping_ms": best_s.get("ping_ms", 0),
            "uri": "",
            "sig": "",
            "frozen": False,
            "pinned": False,
            "outbound": {
                "type": "urltest",
                "tag": "proxy",
                "outbounds": [p["tag"] for p in pool],
                "url": "https://www.gstatic.com/generate_204",
                "interval": "20s",
                "tolerance": 45,
                "_pool": pool
            }
        })
    return ordered

def load_whitelist_servers(st, wl_key="auto", limit=220, allow_network_probe=False):
    frozen_set = set(st.get("frozen_sigs", []))
    pinned_set = set(st.get("pinned_sigs", []))
    verified_set = set(st.get("verified_sigs", []))
    pinned_items = st.get("pinned_wl_items", [])
    ping_cache = st.setdefault("ping_cache", {})
    country_cache = st.setdefault("country_cache", {})

    if wl_key == "my_wl_subs":
        wl_urls = read_wl_sub_urls()
        srvs, _ = rebuild_sub_servers_from_cache(wl_urls, st.get("wl_sub_cache", {}), frozen_set, mark_wl_badges=True, pinned_set=pinned_set, ping_cache=ping_cache, country_cache=country_cache, include_public_bl=False)
        return apply_freeze_and_urltest(srvs, frozen_set, pinned_set=pinned_set, pinned_items=pinned_items)

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
                        name, ob, cc = parse_uri(line, strict_for_public=True)
                        if not ob:
                            continue
                        sig = server_sig(ob)
                        if sig in seen:
                            continue
                        seen.add(sig)
                        sni = ob.get("tls", {}).get("server_name", "")
                        badge, tier = classify_whitelist_badge(ob, starts, merged, resolve_dns=False)
                        if (wl_key in ("all_subs_wl", "goida_wl") or rel in ("all_subs/hysett_wl.txt", "goida-vpn-configs/hysett_wl.txt")) and tier >= 3:
                            continue
                        title = name if (name and name != "Сервер") else f"{ob['server']}:{ob['server_port']}"
                        if sni and sni not in title:
                            title = f"{title} • {sni}"
                        hp = f"{ob['server']}:{ob['server_port']}"
                        p_ms = int(ping_cache.get(hp) or 0)
                        if not cc:
                            cc = country_cache.get(ob["server"], "RU" if tier <= 1 else "")
                        servers.append({
                            "name": f"{badge} • {title[:52]}",
                            "country": cc,
                            "outbound": ob,
                            "uri": line,
                            "sig": sig,
                            "tier": tier,
                            "ping_ms": p_ms if p_ms > 3 else 0,
                            "ping": f"{p_ms} мс" if p_ms > 3 else "",
                            "frozen": (sig in frozen_set)
                        })
                        if len(servers) >= limit:
                            break
        except Exception:
            pass
        if len(servers) >= limit:
            break

    if allow_network_probe:
        populate_server_pings(servers, ping_cache, max_new_probes=55, timeout=0.50)
        resolve_countries_batch(servers, country_cache, starts, merged)

    servers.sort(key=lambda x: (0 if int(x.get("ping_ms") or 0) > 3 else 1, x.get("tier", 2), int(x.get("ping_ms") or 9999)))
    return apply_freeze_and_urltest(servers, frozen_set, pinned_set=pinned_set, pinned_items=pinned_items)

def tcp_quick_filter(item, timeout=0.80):
    ob = item.get("outbound", {})
    host = ob.get("server", "")
    port = int(ob.get("server_port", 443))
    if not host:
        return False, 9999, item
    ms = quick_host_ping_ms(host, port, timeout=timeout)
    if ms is not None and ms > 1:
        item["ping_ms"] = ms
        item["ping"] = f"{ms} мс"
        return True, ms, item
    return False, 9999, item

def strip_ping_and_badge(raw_name, fallback):
    parts = [p.strip() for p in (raw_name or "").split(" • ") if p.strip()]
    while parts and (parts[0].endswith("мс") or parts[0] in ("CIDR+SNI", "CIDR РФ", "Белый SNI", "VLESS")):
        parts.pop(0)
    return " • ".join(parts) if parts else fallback

def probe_http204_via_port(port, item, starts, merged, timeout=2.4):
    proxy_url = f"http://127.0.0.1:{port}"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
    t1_ms = None
    for url1 in ("http://www.gstatic.com/generate_204", "http://cp.cloudflare.com/generate_204"):
        t0 = time.monotonic()
        try:
            req = urllib.request.Request(url1, headers={"User-Agent": "curl/8.0", "Connection": "close"})
            with opener.open(req, timeout=timeout) as r:
                if r.status in (200, 204):
                    t1_ms = max(4, int((time.monotonic() - t0) * 1000))
                    break
        except Exception:
            pass
    if t1_ms is None:
        return None, item

    t2_ms = None
    for url2 in ("https://www.gstatic.com/generate_204", "https://cp.cloudflare.com/generate_204"):
        t0 = time.monotonic()
        try:
            req2 = urllib.request.Request(url2, headers={"User-Agent": "Mozilla/5.0", "Connection": "close"})
            with opener.open(req2, timeout=timeout) as r2:
                if r2.status in (200, 204):
                    t2_ms = max(4, int((time.monotonic() - t0) * 1000))
                    break
        except Exception:
            pass
    if t2_ms is None:
        return None, item

    ms = max(4, int(t1_ms * 0.4 + t2_ms * 0.6))
    if ms > 2100:
        return None, item

    ob = item["outbound"]
    badge, tier = classify_whitelist_badge(ob, starts, merged, resolve_dns=True)
    fallback = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
    base_title = strip_ping_and_badge(item.get("name", ""), fallback)
    return (tier, ms), {
        "name": f"{ms} мс • {badge} • {base_title}",
        "country": item.get("country", "RU" if tier <= 1 else ""),
        "ping": f"{ms} мс",
        "ping_ms": ms,
        "outbound": ob,
        "uri": item.get("uri", "") or rebuild_uri_from_outbound(ob, base_title),
        "sig": item.get("sig", "") or server_sig(ob),
        "frozen": False,
        "pinned": bool(item.get("pinned", False))
    }

def log_wl_msg(msg):
    try:
        with open("/tmp/singbox_vpn.log", "a", encoding="utf-8") as lf:
            lf.write(f"[VPN] {msg}\n")
    except Exception:
        pass

def verify_active_tunnel_port(port=2080, timeout=2.6):
    proxy_url = f"http://127.0.0.1:{port}"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
    for u in ("https://www.gstatic.com/generate_204", "http://www.gstatic.com/generate_204", "http://cp.cloudflare.com/generate_204"):
        try:
            req = urllib.request.Request(u, headers={"User-Agent": "curl/8.0", "Connection": "close"})
            with opener.open(req, timeout=timeout) as r:
                if r.status in (200, 204):
                    return True
        except Exception:
            pass
    return False

def run_singbox_batch_audit(candidates, starts, merged, timeout=2.4):
    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    verified = []
    if not os.path.exists(sb_bin) or not candidates:
        return verified
    base_port = 29100
    phys_if = detect_physical_interface()

    def build_audit_cfg(cand_list):
        inbounds = []
        outbounds = [{"type": "direct", "tag": "direct"}]
        rules = []
        for idx, c in enumerate(cand_list):
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
        route_obj = {
            "default_domain_resolver": "dns-direct",
            "auto_detect_interface": True,
            "rules": rules,
            "final": "direct"
        }
        if phys_if:
            route_obj["default_interface"] = phys_if
        return {
            "log": {"level": "error"},
            "dns": {
                "servers": [{"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}],
                "final": "dns-direct"
            },
            "inbounds": inbounds,
            "outbounds": outbounds,
            "route": route_obj
        }

    test_cfg_path = "/tmp/singbox_wl_audit.json"
    with open(test_cfg_path, "w", encoding="utf-8") as f:
        json.dump(build_audit_cfg(candidates), f)

    if subprocess.run([sb_bin, "check", "-c", test_cfg_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        valid_cands = []
        for c in candidates:
            with open(test_cfg_path, "w", encoding="utf-8") as f:
                json.dump(build_audit_cfg([c]), f)
            if subprocess.run([sb_bin, "check", "-c", test_cfg_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0:
                valid_cands.append(c)
        candidates = valid_cands
        if candidates:
            with open(test_cfg_path, "w", encoding="utf-8") as f:
                json.dump(build_audit_cfg(candidates), f)

    if candidates:
        proc = subprocess.Popen(
            [sb_bin, "run", "-c", test_cfg_path],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
             close_fds=True,
            start_new_session=True
        )
        try:
            if wait_port(base_port, 2.5):
                with ThreadPoolExecutor(max_workers=28) as ex:
                    futs = [ex.submit(probe_http204_via_port, base_port + i, c, starts, merged, timeout) for i, c in enumerate(candidates)]
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
    return verified

def test_and_sort_whitelist(st, max_candidates=60):
    frozen_set = set(st.get("frozen_sigs", []))
    pinned_set = set(st.get("pinned_sigs", []))
    verified_set = set(st.get("verified_sigs", []))
    pinned_items = st.get("pinned_wl_items", [])
    ping_cache = st.setdefault("ping_cache", {})
    country_cache = st.setdefault("country_cache", {})

    write_progress(12, "Загрузка кандидатов БС...")
    wl = load_whitelist_servers(st, st.get("whitelist_file", "auto"), limit=200, allow_network_probe=False)
    real_srvs = [s for s in wl if s.get("outbound", {}).get("type") != "urltest" and not s.get("frozen")]
    if not real_srvs:
        write_progress(100, "Готово")
        return st

    starts, merged = load_ru_whitelist_ip_intervals()
    write_progress(25, f"Проверка пинга {len(real_srvs)} серверов БС (~3 сек)...")
    log_wl_msg(f"Аудит {len(real_srvs)} серверов категории '{st.get('whitelist_file', 'auto')}'...")

    populate_server_pings(real_srvs, ping_cache, max_new_probes=140, timeout=0.55)
    resolve_countries_batch(real_srvs, country_cache, starts, merged)

    tcp_alive = [s for s in real_srvs if int(s.get("ping_ms") or 0) > 3]
    tcp_alive.sort(key=lambda x: (x.get("tier", 2), int(x.get("ping_ms") or 9999)))
    candidates = tcp_alive[:max_candidates] if tcp_alive else real_srvs[:35]

    write_progress(58, f"Стресс-тест HTTP+HTTPS через sing-box ({len(candidates)} серв., ~3 сек)...")
    verified = run_singbox_batch_audit(candidates, starts, merged, timeout=2.4)
    alive = [x[1] for x in verified]
    for a in alive:
        ob = a.get("outbound", {})
        hp = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
        if int(a.get("ping_ms") or 0) > 3:
            ping_cache[hp] = int(a["ping_ms"])

    log_wl_msg(f"Проверка завершена: {len(alive)} стабильных серверов БС.")
    if not alive:
        alive = tcp_alive[:25] if tcp_alive else candidates[:15]

    frozen_items = [s for s in wl if s.get("outbound", {}).get("type") != "urltest" and s.get("frozen")]
    final_list = apply_freeze_and_urltest(
        alive + frozen_items,
        frozen_set,
        f"Авто-выбор • {len(alive)} проверенных серверов",
        pinned_set=pinned_set,
        pinned_items=pinned_items
    )

    st["wl_servers"] = final_list
    st["wl_selected_index"] = 0
    st["wl_server_name"] = final_list[0]["name"] if final_list else "Нет серверов"
    st = sync_active_server_list(st, allow_network_probe=False)
    save_state(st)
    write_progress(100, "Готово")
    return st


STOP_AUDIT_FLAG = "/tmp/hysett_vpn_stop_audit"

def test_single_outbound_via_singbox(ob, port=29250, timeout=2.5):
    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    if not os.path.exists(sb_bin) or not isinstance(ob, dict) or ob.get("type") == "urltest":
        return None, "", 0
    phys_if = detect_physical_interface()
    ob_copy = {k: v for k, v in ob.items() if not k.startswith("_")}
    ob_copy["tag"] = "test-out"
    route_obj = {
        "default_domain_resolver": "dns-direct",
        "auto_detect_interface": True,
        "rules": [{"inbound": ["test-in"], "outbound": "test-out"}],
        "final": "test-out"
    }
    if phys_if:
        route_obj["default_interface"] = phys_if
    cfg = {
        "log": {"level": "error"},
        "dns": {
            "servers": [{"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}],
            "final": "dns-direct"
        },
        "inbounds": [{"type": "mixed", "tag": "test-in", "listen": "127.0.0.1", "listen_port": port}],
        "outbounds": [ob_copy, {"type": "direct", "tag": "direct"}],
        "route": route_obj
    }
    cfg_path = f"/tmp/singbox_single_test_{port}.json"
    try:
        with open(cfg_path, "w", encoding="utf-8") as f:
            json.dump(cfg, f)
        if subprocess.run([sb_bin, "check", "-c", cfg_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
            return None, "", 0
        proc = subprocess.Popen(
            [sb_bin, "run", "-c", cfg_path],
            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            close_fds=True, start_new_session=True
        )
        try:
            t_wait = time.time()
            port_ok = False
            while time.time() - t_wait < 0.9:
                with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
                    if s.connect_ex(("127.0.0.1", port)) == 0:
                        port_ok = True
                        break
                time.sleep(0.025)
            if not port_ok:
                return None, "", 0
            proxy_url = f"http://127.0.0.1:{port}"
            opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
            t0 = time.monotonic()
            for u in ("http://www.gstatic.com/generate_204", "http://cp.cloudflare.com/generate_204", "https://www.gstatic.com/generate_204"):
                rem = timeout - (time.monotonic() - t0)
                if rem <= 0.2:
                    break
                try:
                    t_req = time.monotonic()
                    req = urllib.request.Request(u, headers={"User-Agent": "curl/8.0", "Connection": "close"})
                    with opener.open(req, timeout=min(1.8, rem)) as r:
                        if r.status in (200, 204):
                            ms = max(8, int((time.monotonic() - t_req) * 1000))
                            return f"ОК • {ms} мс", "", ms
                except Exception:
                    pass
        finally:
            proc.kill()
            try:
                proc.wait(timeout=0.3)
            except Exception:
                pass
    except Exception:
        pass
    return None, "", 0

def _probe_port_fast(port, srv, timeout=2.5):
    if os.path.exists(STOP_AUDIT_FLAG):
        return False, "", "", 0
    proxy_url = f"http://127.0.0.1:{port}"
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({"http": proxy_url, "https": proxy_url}))
    t0 = time.monotonic()
    for u in ("http://www.gstatic.com/generate_204", "http://cp.cloudflare.com/generate_204", "https://www.gstatic.com/generate_204"):
        if os.path.exists(STOP_AUDIT_FLAG):
            return False, "", "", 0
        rem = timeout - (time.monotonic() - t0)
        if rem <= 0.2:
            break
        try:
            t_req = time.monotonic()
            req = urllib.request.Request(u, headers={"User-Agent": "curl/8.0", "Connection": "close"})
            with opener.open(req, timeout=min(1.6, rem)) as r:
                if r.status in (200, 204):
                    ms = max(8, int((time.monotonic() - t_req) * 1000))
                    cc = srv.get("country", "")
                    return True, f"ОК • {ms} мс", cc, ms
        except Exception:
            pass
    return False, "", "", 0

def run_sequential_config_audit(st, is_wl=False, sub_tab=0):
    if os.path.exists(STOP_AUDIT_FLAG):
        try:
            os.remove(STOP_AUDIT_FLAG)
        except Exception:
            pass
    st = sync_active_server_list(st, allow_network_probe=False)
    frozen_sigs = list(st.get("frozen_sigs", []))
    verified_sigs = list(st.get("verified_sigs", []))
    ping_cache = st.setdefault("ping_cache", {})
    country_cache = st.setdefault("country_cache", {})

    if is_wl:
        target_srvs = [s for s in st.get("wl_servers", []) if s.get("outbound", {}).get("type") != "urltest"]
    else:
        all_sub = [s for s in st.get("sub_servers", []) if s.get("outbound", {}).get("type") != "urltest"]
        if sub_tab > 0:
            urls = read_sub_urls()
            _, groups = rebuild_sub_servers_from_cache(
                urls, st.get("sub_cache", {}), set(frozen_sigs),
                mark_wl_badges=False, pinned_set=set(st.get("pinned_sigs", [])),
                ping_cache=ping_cache, country_cache=country_cache,
                include_public_bl=True, allow_network_probe=False
            )
            if sub_tab <= len(groups):
                g_indices = {gs.get("global_index") for gs in groups[sub_tab - 1].get("servers", [])}
                target_srvs = [s for i, s in enumerate(st.get("sub_servers", [])) if i in g_indices and s.get("outbound", {}).get("type") != "urltest"]
            else:
                target_srvs = all_sub
        else:
            target_srvs = all_sub

    total = len(target_srvs)
    if total == 0:
        write_progress(100, "Нет серверов для проверки")
        write_ipcheck(3, "Нет серверов для проверки", reload_state=False)
        return st

    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    base_port = 29300
    inbounds = []
    outbounds = [{"type": "direct", "tag": "direct"}]
    rules = []
    valid_entries = []

    for idx, srv in enumerate(target_srvs):
        ob = srv.get("outbound", {})
        if not isinstance(ob, dict) or ob.get("type") == "urltest":
            continue
        p = base_port + len(valid_entries)
        in_tag = f"in-{len(valid_entries)}"
        out_tag = f"out-{len(valid_entries)}"
        ob_copy = {k: v for k, v in ob.items() if not k.startswith("_")}
        ob_copy["tag"] = out_tag
        inbounds.append({"type": "mixed", "tag": in_tag, "listen": "127.0.0.1", "listen_port": p})
        outbounds.append(ob_copy)
        rules.append({"inbound": [in_tag], "outbound": out_tag})
        valid_entries.append((p, srv))

    if not valid_entries:
        write_progress(100, "Готово")
        return st

    cfg = {
        "log": {"level": "error"},
        "dns": {"servers": [{"type": "udp", "tag": "dns-direct", "server": "77.88.8.8"}], "final": "dns-direct"},
        "inbounds": inbounds,
        "outbounds": outbounds,
        "route": {"default_domain_resolver": "dns-direct", "auto_detect_interface": True, "rules": rules, "final": "direct"}
    }
    cfg_path = "/tmp/singbox_multi_audit.json"
    with open(cfg_path, "w", encoding="utf-8") as f:
        json.dump(cfg, f)

    ok_count = 0
    frz_count = 0
    proc = subprocess.Popen(
        [sb_bin, "run", "-c", cfg_path],
        stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        close_fds=True, start_new_session=True
    )
    try:
        wait_port(base_port, 1.5)
        batch_size = 6
        for b_start in range(0, len(valid_entries), batch_size):
            if os.path.exists(STOP_AUDIT_FLAG):
                break
            chunk = valid_entries[b_start:b_start + batch_size]
            first_srv = chunk[0][1]
            first_sig = first_srv.get("sig") or server_sig(first_srv.get("outbound", {}))
            first_nm = first_srv.get("name", "Сервер")[:28]
            pct = max(5, int(((b_start + len(chunk)) * 100) / len(valid_entries)))
            write_progress(pct, f"[{min(len(valid_entries), b_start + len(chunk))}/{len(valid_entries)}] Проверка: {first_nm}...")
            write_ipcheck(1, f"Проверка [{min(len(valid_entries), b_start + len(chunk))}/{len(valid_entries)}]: {first_nm}...", reload_state=False, auditing_sig=first_sig)

            with ThreadPoolExecutor(max_workers=batch_size) as ex:
                futs = {ex.submit(_probe_port_fast, p, s, 2.2): s for p, s in chunk}
                for fut in as_completed(futs):
                    srv = futs[fut]
                    ob = srv.get("outbound", {})
                    sig = srv.get("sig") or server_sig(ob)
                    nm = srv.get("name", "Сервер")[:28]
                    is_ok, info_str, cc, ms = fut.result()
                    if is_ok and ms > 0:
                        ok_count += 1
                        if sig:
                            if sig in frozen_sigs:
                                frozen_sigs.remove(sig)
                            if sig not in verified_sigs:
                                verified_sigs.append(sig)
                        hp = f"{ob.get('server', '')}:{ob.get('server_port', 443)}"
                        ping_cache[hp] = ms
                        srv["ping_ms"] = ms
                        srv["ping"] = f"{ms} мс"
                        srv["frozen"] = False
                        srv["verified"] = True
                        log_wl_msg(f"✓ РАБОЧИЙ ({ms} мс): {nm}")
                    else:
                        if not is_wl and not srv.get("is_public_bl", True):
                            continue
                        frz_count += 1
                        if sig:
                            if sig not in frozen_sigs:
                                frozen_sigs.append(sig)
                            if sig in verified_sigs:
                                verified_sigs.remove(sig)
                        srv["frozen"] = True
                        srv["verified"] = False

            st["frozen_sigs"] = frozen_sigs
            st["verified_sigs"] = verified_sigs
            st = sync_active_server_list(st, allow_network_probe=False)
            save_state(st)
            write_ipcheck(1, f"Проверено {min(len(valid_entries), b_start + len(chunk))}/{len(valid_entries)} • Рабочих: {ok_count} ✓", reload_state=True, auditing_sig="")
    finally:
        proc.kill()
        try:
            proc.wait(timeout=0.5)
        except Exception:
            pass

    summary = f"Готово: {ok_count} рабочих ✓ • {frz_count} заморожено ❄"
    write_progress(100, summary)
    write_ipcheck(2 if ok_count > 0 else 3, summary, reload_state=True, auditing_sig="")
    log_wl_msg(f"🏁 Проверка завершена: {summary}")
    return st

def test_and_sort_normal_servers(st):
    write_progress(15, "Проверка пинга и стран импортированных и GitHub ЧС серверов...")
    ping_cache = st.setdefault("ping_cache", {})
    country_cache = st.setdefault("country_cache", {})
    ensure_sub_cache_metadata(st.get("sub_cache", {}), ping_cache, country_cache)
    write_progress(55, "Сортировка доступных серверов ЧС с GitHub...")
    st = sync_active_server_list(st, allow_network_probe=True)
    save_state(st)
    write_progress(100, "Готово")
    return st

def collect_outbound_exclude_cidrs(outbound, st=None):
    cidrs = ["127.0.0.0/8"]
    obs = list(outbound.get("_pool", [outbound])) if outbound.get("type") == "urltest" else [outbound]
    if isinstance(st, dict):
        for s_item in (st.get("sub_servers", [])[:60] + st.get("wl_servers", [])[:60]):
            ob_i = s_item.get("outbound", {})
            if isinstance(ob_i, dict) and ob_i.get("type") != "urltest":
                obs.append(ob_i)
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
            "interval": outbound.get("interval", "20s"),
            "tolerance": outbound.get("tolerance", 45)
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
            "stack": "gvisor"
        })

    rules = [
        {"action": "sniff", "timeout": "300ms"},
        {"protocol": "dns", "action": "hijack-dns"},
        {"inbound": ["mixed-in"], "outbound": "proxy"},
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

    phys_if = detect_physical_interface()
    return {
        "log": {"level": st.get("log_level", "info")},
        "dns": {
            "servers": [
                {"type": "udp", "tag": "dns-remote", "server": "1.1.1.1", "detour": "proxy"},
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
            **({"default_interface": phys_if} if phys_if else {}),
            "rules": rules,
            "final": route_final
        }
    }

def sync_active_server_list(st, allow_network_probe=False):
    frozen_set = set(st.get("frozen_sigs", []))
    pinned_set = set(st.get("pinned_sigs", []))
    verified_set = set(st.get("verified_sigs", []))
    pinned_items = st.get("pinned_wl_items", [])
    ping_cache = st.setdefault("ping_cache", {})
    country_cache = st.setdefault("country_cache", {})

    urls = read_sub_urls()
    sub_cache = st.get("sub_cache", {})
    if urls:
        for idx_u, u in enumerate(urls):
            entry_u = sub_cache.get(u, {})
            srvs_u = entry_u if isinstance(entry_u, list) else entry_u.get("servers", [])
            if not srvs_u:
                t_u, parsed_u = fetch_single_url(u)
                if parsed_u:
                    sub_cache[u] = {"title": short_sub_title(u, idx_u, t_u), "servers": parsed_u}
                    st["sub_cache"] = sub_cache

    sub_srvs, _ = rebuild_sub_servers_from_cache(
        urls, sub_cache, frozen_set,
        mark_wl_badges=False, pinned_set=pinned_set,
        ping_cache=ping_cache, country_cache=country_cache,
        include_public_bl=True, allow_network_probe=allow_network_probe, verified_set=set(st.get("verified_sigs", []))
    )
    st["sub_servers"] = sub_srvs

    if sub_srvs:
        s_idx = min(max(0, st.get("sub_selected_index", 0)), len(sub_srvs) - 1)
        if sub_srvs[s_idx].get("frozen"):
            s_idx = 0
        st["sub_selected_index"] = s_idx
        st["sub_server_name"] = sub_srvs[s_idx]["name"]
    else:
        st["sub_selected_index"] = 0
        st["sub_server_name"] = "Нет серверов"

    wl_file = st.get("whitelist_file", "auto")
    if not st.get("wl_servers") or wl_file == "my_wl_subs":
        st["wl_servers"] = load_whitelist_servers(st, wl_file, allow_network_probe=allow_network_probe)
    else:
        if allow_network_probe:
            populate_server_pings(st["wl_servers"], ping_cache, max_new_probes=45, timeout=0.50)
            resolve_countries_batch(st["wl_servers"], country_cache)
        else:
            for ws in st["wl_servers"]:
                ob_w = ws.get("outbound", {})
                if isinstance(ob_w, dict) and ob_w.get("type") != "urltest":
                    hp = f"{ob_w.get('server', '')}:{ob_w.get('server_port', 443)}"
                    p_ms = int(ws.get("ping_ms") or ping_cache.get(hp) or 0)
                    if p_ms > 3:
                        ws["ping_ms"] = p_ms
                        ws["ping"] = f"{p_ms} мс"
                    if not ws.get("country"):
                        ws["country"] = country_cache.get(ob_w.get("server", ""), "")
        st["wl_servers"] = apply_freeze_and_urltest(st["wl_servers"], frozen_set, pinned_set=pinned_set, pinned_items=pinned_items)

    wl_srvs = st.get("wl_servers", [])
    if wl_srvs:
        w_idx = min(max(0, st.get("wl_selected_index", 0)), len(wl_srvs) - 1)
        st["wl_selected_index"] = w_idx
        st["wl_server_name"] = wl_srvs[w_idx]["name"]
    else:
        st["wl_selected_index"] = 0
        st["wl_server_name"] = "Нет серверов"

    # ВАЖНО: активный outbound определяется СТРОГО по active_is_wl (включенному тумблеру), а не по открытой вкладке!
    use_wl_ob = bool(st.get("active_is_wl", False))
    if st.get("whitelist_mode", False):
        st["servers"] = wl_srvs
        st["selected_index"] = st["wl_selected_index"]
    else:
        st["servers"] = sub_srvs
        st["selected_index"] = st["sub_selected_index"]

    if use_wl_ob:
        st["server_name"] = st["wl_server_name"]
        if wl_srvs:
            st["outbound"] = wl_srvs[st["wl_selected_index"]]["outbound"]
        else:
            st.pop("outbound", None)
    else:
        st["server_name"] = st["sub_server_name"]
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

    ensure_sub_cache_metadata(cache, st.setdefault("ping_cache", {}), st.setdefault("country_cache", {}))
    st[cache_key] = cache
    if is_wl and st.get("whitelist_file") == "my_wl_subs":
        st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs", allow_network_probe=True)
    st = sync_active_server_list(st, allow_network_probe=False)
    save_state(st)
    return st

def wait_port(port, timeout=3.5):
    t0 = time.time()
    while time.time() - t0 < timeout:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            if s.connect_ex(("127.0.0.1", port)) == 0:
                return True
        time.sleep(0.025)
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

def cleanup_stale_throne_rules():
    try:
        out = subprocess.check_output(["ip", "-4", "rule", "show"], text=True, stderr=subprocess.DEVNULL)
        for ln in out.splitlines():
            if "1651821031" in ln:
                subprocess.run(["ip", "-4", "rule", "del", "lookup", "1651821031"], stderr=subprocess.DEVNULL)
    except Exception:
        pass

def stop_vpn(save_disabled=True):
    if save_disabled:
        st = load_state()
        st["vpn_enabled"] = False
        st["ip_check_state"] = 0
        st["ip_check_text"] = "Туннель отключен"
        save_state(st)
        write_ipcheck(0, "Туннель отключен")
    set_desktop_proxy(False)
    pass
    subprocess.run(["pkill", "-9", "-f", "sing-box.*singbox_vpn.json"], stderr=subprocess.DEVNULL)
    pass

IPCHECK_FILE = "/tmp/hysett_vpn_ipcheck.json"

def write_ipcheck(state_code, text, reload_state=False, auditing_sig=""):
    try:
        tmp = IPCHECK_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({
                "state": int(state_code),
                "text": str(text),
                "reload_state": bool(reload_state),
                "auditing_sig": str(auditing_sig or ""),
                "ts": time.time()
            }, f, ensure_ascii=False)
        os.replace(tmp, IPCHECK_FILE)
    except Exception:
        pass

def _probe_2ip_api(opener, timeout):
    t0 = time.monotonic()
    req = urllib.request.Request(
        "https://api.2ip.io/?lang=ru",
        headers={"User-Agent": "curl/8.0", "Accept": "application/json", "Connection": "close"}
    )
    with opener.open(req, timeout=timeout) as r:
        d = json.loads(r.read().decode("utf-8", errors="ignore"))
    ip = (d.get("ip") or "").strip()
    if not ip:
        return None
    ms = max(10, int((time.monotonic() - t0) * 1000))
    country = (d.get("country") or "").strip()
    city = (d.get("city") or "").strip()
    cc = (d.get("code") or "").strip().upper()
    loc_part = f"{country}, {city}" if (country and city and city != country) else (country or city or "Активен")
    cc_part = f" [{cc}]" if cc else ""
    return f"{ip} • {loc_part}{cc_part} • {ms} мс (2ip.io)", cc

def _probe_ipapi_fallback(opener, timeout):
    t0 = time.monotonic()
    req = urllib.request.Request(
        "http://ip-api.com/json/?fields=status,query,country,countryCode,city&lang=ru",
        headers={"User-Agent": "curl/8.0", "Connection": "close"}
    )
    with opener.open(req, timeout=timeout) as r:
        d = json.loads(r.read().decode("utf-8", errors="ignore"))
    if d.get("status") != "success":
        return None
    ip = (d.get("query") or "").strip()
    if not ip:
        return None
    ms = max(10, int((time.monotonic() - t0) * 1000))
    country = (d.get("country") or "").strip()
    city = (d.get("city") or "").strip()
    cc = (d.get("countryCode") or "").strip().upper()
    loc_part = f"{country}, {city}" if (country and city and city != country) else (country or city or "Активен")
    cc_part = f" [{cc}]" if cc else ""
    return f"{ip} • {loc_part}{cc_part} • {ms} мс (2ip.io)", cc

def _detect_live_location_once(timeout=1.9):
    proxy_handler = urllib.request.ProxyHandler({"http": "http://127.0.0.1:2080", "https": "http://127.0.0.1:2080"})
    opener = urllib.request.build_opener(proxy_handler)
    ex = ThreadPoolExecutor(max_workers=2)
    f_2ip = ex.submit(_probe_2ip_api, opener, timeout)
    f_fb = ex.submit(_probe_ipapi_fallback, opener, timeout)
    try:
        for fut in as_completed([f_2ip, f_fb], timeout=timeout + 0.15):
            try:
                res = fut.result()
                if res:
                    ex.shutdown(wait=False, cancel_futures=True)
                    return res
            except Exception:
                pass
    except Exception:
        pass
    finally:
        ex.shutdown(wait=False, cancel_futures=True)
    return None, ""

def detect_live_location(timeout=2.6):
    deadline = time.monotonic() + timeout
    res, cc = _detect_live_location_once(timeout=min(1.75, timeout))
    if res:
        return res, cc
    rem = deadline - time.monotonic()
    if rem > 0.45:
        time.sleep(0.15)
        rem = deadline - time.monotonic()
        if rem > 0.25:
            return _detect_live_location_once(timeout=rem)
    return None, ""

def wait_network_ready(timeout=5.0):
    t0 = time.time()
    while time.time() - t0 < timeout:
        try:
            out = subprocess.check_output(["ip", "route", "show", "default"], text=True, stderr=subprocess.DEVNULL).strip()
            if out:
                return True
        except Exception:
            pass
        time.sleep(0.25)
    return False

def launch_singbox_process(sb_bin, cfg_path, append_log=False):
    mode = "a" if append_log else "w"
    lf = open("/tmp/singbox_vpn.log", mode)
    subprocess.Popen(
        [sb_bin, "run", "-c", cfg_path],
        stdin=subprocess.DEVNULL,
        stdout=lf,
        stderr=subprocess.STDOUT,
        close_fds=True,
        start_new_session=True
    )
    lf.close()

def start_vpn(fast_switch=False):
    if not fast_switch:
        wait_network_ready(3.0)
    st = load_state()
    st["vpn_enabled"] = True
    # НИКОГДА не перезаписываем active_is_wl значением whitelist_mode при рестарте!
    is_wl_active = bool(st.get("active_is_wl", False))
    st = sync_active_server_list(st, allow_network_probe=False)
    if not st.get("sub_servers") and not is_wl_active:
        st = fetch_subscriptions(is_wl=False)
    if "outbound" not in st:
        save_state(st)
        return False

    sb_bin = shutil.which("sing-box") or "/usr/bin/sing-box"
    if not os.path.exists(sb_bin):
        return False
    use_tun = has_cap_net_admin(sb_bin)

    # Строим и валидируем конфиг ДО остановки старого процесса, чтобы туннель не падал
    cfg = build_config(st["outbound"], st, use_tun)
    tmp_conf = SB_CONF + ".tmp"
    with open(tmp_conf, "w", encoding="utf-8") as f:
        json.dump(cfg, f, indent=2, ensure_ascii=False)

    if subprocess.run([sb_bin, "check", "-c", tmp_conf], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode != 0:
        log_wl_msg("⚠ Ошибка проверки конфига выбранного узла, откат на Авто-выбор...")
        if is_wl_active:
            st["wl_selected_index"] = 0
        else:
            st["sub_selected_index"] = 0
        st = sync_active_server_list(st, allow_network_probe=False)
        cfg = build_config(st["outbound"], st, use_tun)
        with open(tmp_conf, "w", encoding="utf-8") as f:
            json.dump(cfg, f, indent=2, ensure_ascii=False)

    os.replace(tmp_conf, SB_CONF)
    stop_vpn(save_disabled=False)
    launch_singbox_process(sb_bin, SB_CONF, append_log=False)

    def _auto_freeze_current_server(reason_prefix):
        target_key = "wl_servers" if is_wl_active else "sub_servers"
        idx_key = "wl_selected_index" if is_wl_active else "sub_selected_index"
        srv_list = st.get(target_key, [])
        sel_i = int(st.get(idx_key, 0))
        frozen_now = False
        srv_title = st.get("server_name", "Сервер")
        if 0 < sel_i < len(srv_list):
            srv_obj = srv_list[sel_i]
            srv_title = srv_obj.get("name", srv_title)
            ob_s = srv_obj.get("outbound", {})
            sig = srv_obj.get("sig") or server_sig(ob_s)
            if sig:
                frz = st.get("frozen_sigs", [])
                if sig not in frz:
                    frz.append(sig)
                    st["frozen_sigs"] = frz
                frozen_now = True
        if frozen_now:
            st_upd = sync_active_server_list(st, allow_network_probe=False)
            st.update(st_upd)
            msg = f"{reason_prefix} • Сервер заморожен ({srv_title[:32]})"
            log_wl_msg(f"❄ {msg}")
        else:
            msg = f"{reason_prefix} (2ip.io недоступен)"
            log_wl_msg(f"✗ {msg}")
        st["ip_check_state"] = 3
        st["ip_check_text"] = msg
        save_state(st)
        write_ipcheck(3, msg, reload_state=frozen_now)

    if wait_port(2080, 2.5):
        set_desktop_proxy(not use_tun)
        write_ipcheck(1, "Проверка локации (2ip.io)...")
        loc, cc = detect_live_location(timeout=2.6)
        if loc:
            st["ip_check_state"] = 2
            st["ip_check_text"] = loc
            save_state(st)
            write_ipcheck(2, loc, reload_state=False)
            log_wl_msg(f"✓ Туннель активен: {loc}")
        elif verify_active_tunnel_port(2080, timeout=2.0):
            msg = f"Туннель работает ✓ ({st.get('server_name', 'VPN')})"
            st["ip_check_state"] = 2
            st["ip_check_text"] = msg
            save_state(st)
            write_ipcheck(2, msg, reload_state=False)
        else:
            msg = "Нет ответа от сервера (> 3 сек)"
            st["ip_check_state"] = 3
            st["ip_check_text"] = msg
            save_state(st)
            write_ipcheck(3, msg, reload_state=False)
        return True
    else:
        st["ip_check_state"] = 3
        st["ip_check_text"] = "Ошибка запуска sing-box"
        save_state(st)
        write_ipcheck(3, st["ip_check_text"], reload_state=False)
        stop_vpn(save_disabled=False)
    return False

def dump_status_json():
    st = load_state()
    st = sync_active_server_list(st, allow_network_probe=False)
    save_state(st)
    frozen_set = set(st.get("frozen_sigs", []))
    pinned_set = set(st.get("pinned_sigs", []))
    verified_set = set(st.get("verified_sigs", []))
    ping_cache = st.get("ping_cache", {})
    country_cache = st.get("country_cache", {})
    urls = read_sub_urls()
    wl_urls = read_wl_sub_urls()

    _, sub_groups = rebuild_sub_servers_from_cache(
        urls, st.get("sub_cache", {}), frozen_set,
        mark_wl_badges=False, pinned_set=pinned_set,
        ping_cache=ping_cache, country_cache=country_cache,
        include_public_bl=True, allow_network_probe=False, verified_set=verified_set
    )
    _, wl_sub_groups = rebuild_sub_servers_from_cache(
        wl_urls, st.get("wl_sub_cache", {}), frozen_set,
        mark_wl_badges=True, pinned_set=pinned_set,
        ping_cache=ping_cache, country_cache=country_cache,
        include_public_bl=False, allow_network_probe=False, verified_set=verified_set
    )

    sub_srv_names = []
    sub_srv_items = []
    for i, s in enumerate(st.get("sub_servers", [])):
        nm = s.get("name", f"Сервер {i+1}")
        ob = s.get("outbound", {})
        uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
        sig = s.get("sig", "") or server_sig(ob)
        p_str = s.get("ping") or extract_ping_str(nm, int(s.get("ping_ms") or 0))
        cc = s.get("country", "")
        frz = bool(s.get("frozen", False) or (sig and sig in frozen_set))
        pin = bool(s.get("pinned", False) or (sig and sig in pinned_set))
        ver = bool(s.get("verified", False) or (sig and sig in verified_set)) and not frz
        sub_srv_names.append(nm)
        sub_srv_items.append({
            "name": nm, "country": cc, "uri": uri, "sig": sig,
            "ping": p_str, "frozen": frz, "pinned": pin, "verified": ver,
            "is_public_bl": bool(s.get("is_public_bl", False)),
            "global_index": i
        })

    wl_srv_names = []
    wl_srv_items = []
    for i, s in enumerate(st.get("wl_servers", [])):
        nm = s.get("name", f"Сервер {i+1}")
        ob = s.get("outbound", {})
        uri = s.get("uri", "") or rebuild_uri_from_outbound(ob, nm)
        sig = s.get("sig", "") or server_sig(ob)
        p_str = s.get("ping") or extract_ping_str(nm, int(s.get("ping_ms") or 0))
        cc = s.get("country", "")
        frz = bool(s.get("frozen", False) or (sig and sig in frozen_set))
        pin = bool(s.get("pinned", False) or (sig and sig in pinned_set))
        ver = bool(s.get("verified", False) or (sig and sig in verified_set)) and not frz
        wl_srv_names.append(nm)
        wl_srv_items.append({
            "name": nm, "country": cc, "uri": uri, "sig": sig,
            "ping": p_str, "frozen": frz, "pinned": pin, "verified": ver,
            "global_index": i
        })

    srv_names = wl_srv_names if st.get("whitelist_mode", False) else sub_srv_names
    wl_files = [{"key": k, "label": lbl} for k, lbl, _ in WHITELIST_SOURCES]
    hint = st.get("cached_hint", "")
    if not hint:
        blocked_d, ru_d, _, _ = load_bypass_routing_sets(st)
        hint = f"Маршруты: {len(blocked_d)} в обход • {len(ru_d)} РФ напрямую"
        st["cached_hint"] = hint
        save_state(st)
    last_upd = st.get("last_updated", "")
    if not last_upd:
        upd_log = os.path.join(HYSETT_DIR, "bypass-lists/update.log")
        if os.path.exists(upd_log):
            try:
                last_upd = time.strftime("%d.%m в %H:%M", time.localtime(os.path.getmtime(upd_log)))
            except Exception:
                pass
    out = {
        "last_updated": last_upd,
        "server_name": st.get("server_name", "VPN"),
        "sub_server_name": st.get("sub_server_name", "VPN"),
        "wl_server_name": st.get("wl_server_name", "Авто-выбор лучшего сервера"),
        "ru_direct": st.get("ru_direct", True),
        "split_mode": st.get("split_mode", "ru_direct"),
        "vpn_enabled": st.get("vpn_enabled", False),
        "active_is_wl": st.get("active_is_wl", False),
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
        "ip_check_state": st.get("ip_check_state", 0) if st.get("vpn_enabled", False) else 0,
        "ip_check_text": st.get("ip_check_text", "") if st.get("vpn_enabled", False) else "Туннель отключен",
        "log_level": st.get("log_level", "info")
    }
    print(json.dumps(out, ensure_ascii=False), flush=True)

def restart_if_running():
    if subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0:
        start_vpn()

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "status":
        dump_status_json()
    elif cmd == "boot":
        st = load_state()
        ensure_sub_cache_metadata(st.get("sub_cache", {}), st.setdefault("ping_cache", {}), st.setdefault("country_cache", {}))
        save_state(st)
        is_running = (subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0)
        if st.get("vpn_enabled", False) and not is_running:
            start_vpn()
        dump_status_json()
    elif cmd == "update_lists":
        try:
            os.nice(15)
        except Exception:
            pass
        write_progress(5, "Запуск обновления репозиториев БС и ЧС с GitHub...")
        if os.path.exists(UPDATE_SCRIPT):
            subprocess.run(["/usr/bin/bash", UPDATE_SCRIPT], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True)
        write_progress(80, "Обновление списков серверов...")
        st = load_state()
        st["last_updated"] = time.strftime("%d.%m в %H:%M")
        st["wl_servers"] = load_whitelist_servers(st, st.get("whitelist_file", "auto"), allow_network_probe=True)
        st = sync_active_server_list(st, allow_network_probe=False)
        save_state(st)
        write_progress(100, "Готово")
        dump_status_json()
    elif cmd in ("update", "update_subs"):
        # Отдельная кнопка обновления ТОЛЬКО ручных подписок
        write_progress(20, "Обновление личных подписок...")
        fetch_subscriptions(is_wl=False)
        fetch_subscriptions(is_wl=True)
        write_progress(100, "Подписки обновлены")
        dump_status_json()
    elif cmd == "test_normal":
        sub_tab = int(sys.argv[2]) if len(sys.argv) > 2 else 0
        st = load_state()
        st = run_sequential_config_audit(st, is_wl=False, sub_tab=sub_tab)
        dump_status_json()
    elif cmd == "stop_audit":
        try:
            with open(STOP_AUDIT_FLAG, "w") as f:
                f.write("1")
        except Exception:
            pass
        dump_status_json()
    elif cmd == "set_whitelist_mode":
        st = load_state()
        is_wl_m = (sys.argv[2] == "1") if len(sys.argv) > 2 else False
        st["whitelist_mode"] = is_wl_m
        if not st.get("vpn_enabled", False):
            st["active_is_wl"] = is_wl_m
        st = sync_active_server_list(st, allow_network_probe=False)
        save_state(st)
        dump_status_json()
    elif cmd == "start_mode":
        st = load_state()
        is_wl = (sys.argv[2] == "1") if len(sys.argv) > 2 else st.get("whitelist_mode", False)
        st["whitelist_mode"] = is_wl
        st["active_is_wl"] = is_wl
        st["vpn_enabled"] = True
        st = sync_active_server_list(st, allow_network_probe=False)
        save_state(st)
        start_vpn()
        dump_status_json()
    elif cmd == "set_whitelist_file":
        if len(sys.argv) > 2:
            st = load_state()
            st["whitelist_file"] = sys.argv[2].strip()
            st["wl_selected_index"] = 0
            st["wl_servers"] = load_whitelist_servers(st, st["whitelist_file"], allow_network_probe=True)
            st = sync_active_server_list(st, allow_network_probe=False)
            save_state(st)
            if st.get("vpn_enabled", False) and st.get("active_is_wl", False):
                st["ip_check_state"] = 1
                st["ip_check_text"] = "Смена категории и проверка на 2ip.io..."
                write_ipcheck(1, st["ip_check_text"])
                save_state(st)
                token = f"{time.monotonic():.6f}"
                with open("/tmp/hysett_vpn_switch.token", "w") as tf:
                    tf.write(token)
                with open("/tmp/hysett_vpn_switching.lock", "w") as lf:
                    lf.write(str(time.time()))
                subprocess.Popen(
                    [sys.executable, os.path.abspath(__file__), "apply_selected_bg", token],
                    stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                    close_fds=True, start_new_session=True
                )
        dump_status_json()
    elif cmd == "test_whitelist":
        st = load_state()
        st = run_sequential_config_audit(st, is_wl=True, sub_tab=0)
        if st.get("active_is_wl", False):
            restart_if_running()
        dump_status_json()
    elif cmd == "check_2ip":
        st = load_state()
        is_running = (subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0)
        if not st.get("vpn_enabled", False) or not is_running:
            st["ip_check_state"] = 0
            st["ip_check_text"] = "Туннель отключен"
            write_ipcheck(0, "Туннель отключен")
        else:
            write_ipcheck(1, "Проверка отклика и локации на 2ip.io (лимит 3 сек)...")
            loc, cc = detect_live_location(timeout=2.6)
            if loc:
                st["ip_check_state"] = 2
                st["ip_check_text"] = loc
                write_ipcheck(2, loc, reload_state=False)
            else:
                if verify_active_tunnel_port(2080, timeout=2.0):
                    st["ip_check_state"] = 2
                    st["ip_check_text"] = f"Туннель работает ✓ ({st.get('server_name', 'VPN')})"
                    write_ipcheck(2, st["ip_check_text"], reload_state=False)
                else:
                    st["ip_check_state"] = 3
                    st["ip_check_text"] = "Нет ответа через туннель (> 3 сек)"
                    write_ipcheck(3, st["ip_check_text"], reload_state=False)
        save_state(st)
        dump_status_json()
    elif cmd == "toggle_freeze":
        need_bg_restart = False
        if len(sys.argv) > 3:
            idx = int(sys.argv[2])
            is_wl = (sys.argv[3] == "1")
            st = load_state()
            target_list = st.get("wl_servers", []) if is_wl else st.get("sub_servers", [])
            if 0 <= idx < len(target_list):
                ob = target_list[idx].get("outbound", {})
                sig = target_list[idx].get("sig") or server_sig(ob)
                if sig:
                    frz = st.get("frozen_sigs", [])
                    was_frozen = sig in frz
                    if was_frozen:
                        frz.remove(sig)
                    else:
                        frz.append(sig)
                    st["frozen_sigs"] = frz
                    cur_sel = st.get("wl_selected_index", 0) if is_wl else st.get("sub_selected_index", 0)
                    if not was_frozen and cur_sel == idx:
                        if is_wl:
                            st["wl_selected_index"] = 0
                        else:
                            st["sub_selected_index"] = 0
                        need_bg_restart = True
                    elif cur_sel == 0:
                        need_bg_restart = True
                    st = sync_active_server_list(st, allow_network_probe=False)
                    save_state(st)
        dump_status_json()
        if need_bg_restart and st.get("vpn_enabled", False) and bool(st.get("active_is_wl", False)) == is_wl:
            token = f"{time.monotonic():.6f}"
            with open("/tmp/hysett_vpn_switch.token", "w") as tf:
                tf.write(token)
            subprocess.Popen([sys.executable, os.path.abspath(__file__), "apply_selected_bg", token],
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, close_fds=True, start_new_session=True)
    elif cmd == "toggle_pin":
        if len(sys.argv) > 3:
            idx = int(sys.argv[2])
            is_wl = (sys.argv[3] == "1")
            st = load_state()
            target_list = st.get("wl_servers", []) if is_wl else st.get("sub_servers", [])
            if 0 <= idx < len(target_list):
                srv = target_list[idx]
                ob = srv.get("outbound", {})
                sig = srv.get("sig") or server_sig(ob)
                if sig:
                    pins = st.get("pinned_sigs", [])
                    pin_items = [x for x in st.get("pinned_wl_items", []) if (x.get("sig") or server_sig(x.get("outbound", {}))) != sig]
                    if sig in pins:
                        pins.remove(sig)
                    else:
                        pins.insert(0, sig)
                        frz = st.get("frozen_sigs", [])
                        if sig in frz:
                            frz.remove(sig)
                            st["frozen_sigs"] = frz
                        if is_wl:
                            pin_items.insert(0, {
                                "name": srv.get("name", "Сервер"),
                                "country": srv.get("country", ""),
                                "ping": srv.get("ping", ""),
                                "ping_ms": srv.get("ping_ms", 0),
                                "outbound": ob,
                                "uri": srv.get("uri", "") or rebuild_uri_from_outbound(ob, srv.get("name", "Server")),
                                "sig": sig
                            })
                    st["pinned_sigs"] = pins
                    st["pinned_wl_items"] = pin_items
                    st = sync_active_server_list(st, allow_network_probe=False)
                    if is_wl and sig in pins:
                        for new_i, item in enumerate(st.get("wl_servers", [])):
                            if item.get("sig") == sig:
                                st["wl_selected_index"] = new_i
                                break
                        st = sync_active_server_list(st, allow_network_probe=False)
                    save_state(st)
        dump_status_json()
    elif cmd == "clear_frozen":
        st = load_state()
        st["frozen_sigs"] = []
        st = sync_active_server_list(st, allow_network_probe=False)
        save_state(st)
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
                st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs", allow_network_probe=True)
                st = sync_active_server_list(st, allow_network_probe=False)
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
                    st["wl_servers"] = load_whitelist_servers(st, "my_wl_subs", allow_network_probe=False)
                st = sync_active_server_list(st, allow_network_probe=False)
                save_state(st)
        dump_status_json()
    elif cmd == "select_server":
        if len(sys.argv) > 2:
            idx = int(sys.argv[2])
            st = load_state()
            is_wl = (sys.argv[3] == "1") if len(sys.argv) > 3 else bool(st.get("whitelist_mode", False))
            st["whitelist_mode"] = is_wl
            st["active_is_wl"] = is_wl
            if is_wl:
                st["wl_selected_index"] = idx
            else:
                st["sub_selected_index"] = idx
            st = sync_active_server_list(st, allow_network_probe=False)
            will_switch = bool(st.get("vpn_enabled", False)) and (bool(st.get("active_is_wl", False)) == is_wl)
            if will_switch:
                st["ip_check_state"] = 1
                st["ip_check_text"] = "Переключение сервера и проверка на 2ip.io..."
                write_ipcheck(1, st["ip_check_text"])
            save_state(st)
            dump_status_json()
            if will_switch:
                token = f"{time.monotonic():.6f}"
                try:
                    with open("/tmp/hysett_vpn_switch.token", "w") as tf:
                        tf.write(token)
                    with open("/tmp/hysett_vpn_switching.lock", "w") as lf:
                        lf.write(str(time.time()))
                except Exception:
                    pass
                subprocess.Popen(
                    [sys.executable, os.path.abspath(__file__), "apply_selected_bg", token],
                    stdin=subprocess.DEVNULL,
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    close_fds=True,
                    start_new_session=True
                )
        else:
            dump_status_json()
    elif cmd == "apply_selected_bg":
        token = sys.argv[2] if len(sys.argv) > 2 else ""
        time.sleep(0.06)
        try:
            cur_tok = open("/tmp/hysett_vpn_switch.token").read().strip()
            if token and cur_tok != token:
                sys.exit(0)
        except Exception:
            pass
        try:
            with open("/tmp/hysett_vpn_switching.lock", "w") as lf:
                lf.write(str(time.time()))
            start_vpn(fast_switch=True)
        finally:
            try:
                cur_tok = open("/tmp/hysett_vpn_switch.token").read().strip()
                if not token or cur_tok == token:
                    os.remove("/tmp/hysett_vpn_switching.lock")
            except Exception:
                pass
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
                    all_l = [re.sub(r"\x1b\[[0-9;]*m", "", ln.rstrip()) for ln in f.readlines() if ln.strip()]
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
    elif cmd == "watchdog":
        st = load_state()
        is_running = (subprocess.run(["pgrep", "-f", "sing-box.*singbox_vpn.json"], stdout=subprocess.DEVNULL).returncode == 0)
        if st.get("vpn_enabled", False) and st.get("active_is_wl", False) and is_running:
            if not verify_active_tunnel_port(2080, timeout=2.5):
                time.sleep(0.8)
                if not verify_active_tunnel_port(2080, timeout=2.5):
                    sel_idx = st.get("wl_selected_index", 0)
                    wl_list = st.get("wl_servers", [])
                    if 0 < sel_idx < len(wl_list):
                        dead_sig = wl_list[sel_idx].get("sig") or server_sig(wl_list[sel_idx].get("outbound", {}))
                        if dead_sig:
                            frz = st.get("frozen_sigs", [])
                            if dead_sig not in frz:
                                frz.append(dead_sig)
                                st["frozen_sigs"] = frz
                    log_wl_msg("↻ Текущий сервер БС перестал отвечать под нагрузкой. Авто-переключение...")
                    st["wl_selected_index"] = 0
                    save_state(st)
                    st = test_and_sort_whitelist(st, max_candidates=40)
                    start_vpn()
                    dump_status_json()
    elif cmd == "start":
        start_vpn()
        dump_status_json()
    elif cmd == "pause":
        stop_vpn(save_disabled=False)
    elif cmd == "stop":
        stop_vpn(save_disabled=True)
