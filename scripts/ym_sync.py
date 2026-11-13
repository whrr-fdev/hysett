#!/usr/bin/env python3
import sys, os, re, json, time, hashlib, urllib.request, urllib.parse

TOKEN_FILE = os.path.expanduser("~/.config/hysett_ym_token.txt")
DB_FILE = os.path.expanduser("~/.config/hypr/scripts/ym_downloaded.json")
PROG_FILE = "/tmp/hysett_ym_progress.json"
STOP_FILE = "/tmp/hysett_ym_stop"
MUSIC_DIR = os.path.expanduser("~/Music/YandexMusic")
OAUTH_URL = "https://oauth.yandex.ru/authorize?response_type=token&client_id=23cabbbdc6cd418abb4b39c32c41195d"

def write_prog(busy, pct, text):
    try:
        tmp = PROG_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"busy": bool(busy), "percent": int(pct), "text": str(text), "ts": time.time()}, f, ensure_ascii=False)
        os.replace(tmp, PROG_FILE)
    except Exception:
        pass

def read_token():
    if not os.path.exists(TOKEN_FILE):
        return ""
    try:
        return open(TOKEN_FILE, "r", encoding="utf-8").read().strip()
    except Exception:
        return ""

def save_token(raw):
    s = (raw or "").strip()
    m = re.search(r"access_token=([^&\s]+)", s)
    if m:
        s = m.group(1).strip()
    os.makedirs(os.path.dirname(TOKEN_FILE), exist_ok=True)
    with open(TOKEN_FILE, "w", encoding="utf-8") as f:
        f.write(s + "\n")
    os.chmod(TOKEN_FILE, 0o600)
    return s

def load_db():
    if os.path.exists(DB_FILE):
        try:
            return json.load(open(DB_FILE, "r", encoding="utf-8"))
        except Exception:
            pass
    return {"downloaded_ids": []}

def save_db(db):
    os.makedirs(os.path.dirname(DB_FILE), exist_ok=True)
    tmp = DB_FILE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False)
    os.replace(tmp, DB_FILE)

def ym_request(path_or_url, token, data=None, timeout=10):
    url = path_or_url if path_or_url.startswith("http") else f"https://api.music.yandex.net{path_or_url}"
    headers = {
        "Authorization": f"OAuth {token}",
        "X-Yandex-Music-Client": "YandexMusicAndroid/24023621",
        "User-Agent": "Yandex-Music-API",
        "Accept": "application/json"
    }
    body = None
    if data is not None:
        body = urllib.parse.urlencode(data).encode("utf-8")
        headers["Content-Type"] = "application/x-www-form-urlencoded"
    req = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read().decode("utf-8", errors="ignore"))

def safe_filename(s):
    s = re.sub(r'[\\/:*?"<>|]+', "_", (s or "").strip())
    s = re.sub(r"\s+", " ", s).strip(" .")
    return s[:110] or "Track"

def get_direct_mp3_url(track_id, token):
    info_resp = ym_request(f"/tracks/{track_id}/download-info", token)
    items = info_resp.get("result", [])
    if not items:
        return ""
    mp3_items = [x for x in items if x.get("codec") == "mp3"] or items
    mp3_items.sort(key=lambda x: int(x.get("bitrateInKbps", 0)), reverse=True)
    dl_url = mp3_items[0].get("downloadInfoUrl", "")
    if not dl_url:
        return ""
    sep = "&" if "?" in dl_url else "?"
    meta = ym_request(f"{dl_url}{sep}format=json", token)
    if "result" in meta and isinstance(meta["result"], dict):
        meta = meta["result"]
    host = meta.get("host", "")
    path = meta.get("path", "")
    ts = meta.get("ts", "")
    s = meta.get("s", "")
    if not (host and path and ts and s):
        return ""
    sign = hashlib.md5(("XGRl99FXlekgbPrRHuSiA" + path[1:] + s).encode("utf-8")).hexdigest()
    return f"https://{host}/get-mp3/{sign}/{ts}{path}"

def format_track_meta(tr):
    tid = str(tr.get("id", ""))
    title = tr.get("title", "Track")
    ver = tr.get("version", "")
    if ver:
        title = f"{title} ({ver})"
    artists = [a.get("name", "") for a in tr.get("artists", []) if a.get("name")]
    artist_str = ", ".join(artists) if artists else "Unknown"
    return tid, safe_filename(f"{artist_str} - {title}")

def download_track_list(tracks, folder_name, token, db_set, db_obj):
    dest_dir = os.path.join(MUSIC_DIR, safe_filename(folder_name))
    os.makedirs(dest_dir, exist_ok=True)
    added = 0
    total = len(tracks)
    for idx, tr in enumerate(tracks):
        if os.path.exists(STOP_FILE):
            break
        tid, fname = format_track_meta(tr)
        if not tid:
            continue
        out_path = os.path.join(dest_dir, f"{fname}.mp3")
        key = f"{folder_name}:{tid}"
        if key in db_set and os.path.exists(out_path) and os.path.getsize(out_path) > 32768:
            continue
        pct = max(5, int(((idx + 1) * 100) / max(1, total)))
        write_prog(True, pct, f"[{idx+1}/{total}] {folder_name}: {fname[:38]}...")
        try:
            mp3_url = get_direct_mp3_url(tid, token)
            if not mp3_url:
                continue
            req = urllib.request.Request(mp3_url, headers={"User-Agent": "Yandex-Music-API"})
            with urllib.request.urlopen(req, timeout=20) as r:
                data = r.read()
            if len(data) > 32768:
                tmp_p = out_path + ".part"
                with open(tmp_p, "wb") as f:
                    f.write(data)
                os.replace(tmp_p, out_path)
                db_set.add(key)
                db_obj["downloaded_ids"] = list(db_set)
                save_db(db_obj)
                added += 1
        except Exception:
            pass
    return added

def sync_all_playlists():
    if os.path.exists(STOP_FILE):
        os.remove(STOP_FILE)
    token = read_token()
    if not token:
        write_prog(False, 0, "Токен не задан. Нажмите «Получить токен» и вставьте его.")
        return
    write_prog(True, 5, "Подключение к Яндекс.Музыке...")
    try:
        acc = ym_request("/account/status", token)
        uid = acc.get("result", {}).get("account", {}).get("uid")
        if not uid:
            write_prog(False, 0, "Ошибка авторизации: проверьте OAuth-токен")
            return
    except Exception as e:
        write_prog(False, 0, f"Ошибка подключения к API Яндекс.Музыки")
        return

    db_obj = load_db()
    db_set = set(db_obj.get("downloaded_ids", []))
    total_new = 0

    # 1. Плейлист "Мне нравится"
    try:
        write_prog(True, 10, "Получение списка «Мне нравится»...")
        likes_resp = ym_request(f"/users/{uid}/likes/tracks", token)
        like_short = likes_resp.get("result", {}).get("library", {}).get("tracks", [])
        like_ids = [str(x.get("id")) for x in like_short if x.get("id")]
        full_likes = []
        for i in range(0, len(like_ids), 150):
            if os.path.exists(STOP_FILE):
                break
            chunk_ids = like_ids[i:i+150]
            tr_resp = ym_request("/tracks", token, data={"track-ids": ",".join(chunk_ids)})
            full_likes.extend(tr_resp.get("result", []))
        if full_likes:
            total_new += download_track_list(full_likes, "Мне нравится", token, db_set, db_obj)
    except Exception:
        pass

    # 2. Пользовательские плейлисты
    try:
        pls_resp = ym_request(f"/users/{uid}/playlists/list", token)
        playlists = pls_resp.get("result", [])
        for pl in playlists:
            if os.path.exists(STOP_FILE):
                break
            kind = pl.get("kind")
            pl_title = pl.get("title", f"Плейлист {kind}")
            pl_full = ym_request(f"/users/{uid}/playlists/{kind}", token).get("result", {})
            raw_items = pl_full.get("tracks", [])
            tracks = []
            missing_ids = []
            for it in raw_items:
                if isinstance(it, dict) and "track" in it and isinstance(it["track"], dict):
                    tracks.append(it["track"])
                elif isinstance(it, dict) and it.get("title"):
                    tracks.append(it)
                elif isinstance(it, dict) and it.get("id"):
                    missing_ids.append(str(it["id"]))
            for i in range(0, len(missing_ids), 150):
                tr_resp = ym_request("/tracks", token, data={"track-ids": ",".join(missing_ids[i:i+150])})
                tracks.extend(tr_resp.get("result", []))
            if tracks:
                total_new += download_track_list(tracks, pl_title, token, db_set, db_obj)
    except Exception:
        pass

    if os.path.exists(STOP_FILE):
        write_prog(False, 0, f"Остановлено • Скачано новых: {total_new}")
    else:
        write_prog(False, 100, f"Синхронизировано ✓ Новых треков: {total_new} (~/Music/YandexMusic)")

def download_my_wave(batch_target=20):
    if os.path.exists(STOP_FILE):
        os.remove(STOP_FILE)
    token = read_token()
    if not token:
        write_prog(False, 0, "Токен не задан. Нажмите «Получить токен» и вставьте его.")
        return
    write_prog(True, 8, "Запрос потока станции «Моя волна»...")
    db_obj = load_db()
    db_set = set(db_obj.get("downloaded_ids", []))
    vibe_tracks = []
    seen_ids = set()
    try:
        for _ in range(4):
            if len(vibe_tracks) >= batch_target or os.path.exists(STOP_FILE):
                break
            queue_param = f"&queue={','.join(list(seen_ids)[-5:])}" if seen_ids else ""
            resp = ym_request(f"/rotor/station/user:onyourwave/tracks?settings2=true{queue_param}", token)
            seq = resp.get("result", {}).get("sequence", [])
            if not seq:
                break
            for item in seq:
                tr = item.get("track") if isinstance(item, dict) else None
                if isinstance(tr, dict) and tr.get("id"):
                    tid = str(tr["id"])
                    if tid not in seen_ids:
                        seen_ids.add(tid)
                        vibe_tracks.append(tr)
                        if len(vibe_tracks) >= batch_target:
                            break
    except Exception:
        write_prog(False, 0, "Ошибка получения «Моей волны» (проверьте токен и подписку Плюс)")
        return

    if not vibe_tracks:
        write_prog(False, 0, "Не удалось получить треки «Моей волны»")
        return

    added = download_track_list(vibe_tracks, "Моя волна", token, db_set, db_obj)
    if os.path.exists(STOP_FILE):
        write_prog(False, 0, f"Остановлено • Скачано из Моей волны: {added}")
    else:
        write_prog(False, 100, f"Моя волна ✓ Скачано треков: {added} (~/Music/YandexMusic/Моя волна)")

if __name__ == "__main__":
    try:
        os.nice(12)
    except Exception:
        pass
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "save_token":
        tok = save_token(sys.argv[2] if len(sys.argv) > 2 else "")
        write_prog(False, 0, "Токен Яндекс.Музыки сохранен ✓" if tok else "Токен очищен")
    elif cmd == "sync":
        sync_all_playlists()
    elif cmd == "my_wave":
        download_my_wave(20)
    elif cmd == "stop":
        open(STOP_FILE, "w").write("1")
        write_prog(False, 0, "Синхронизация остановлена")
