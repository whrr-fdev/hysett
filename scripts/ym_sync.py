#!/usr/bin/env python3
import sys, os, re, json, time, hashlib, urllib.request, urllib.parse

TOKEN_FILE = os.path.expanduser("~/.config/hysett_ym_token.txt")
DB_FILE = os.path.expanduser("~/.config/hypr/scripts/ym_downloaded.json")
INDEX_FILE = os.path.expanduser("~/Music/YandexMusic/playlists_index.json")
COVERS_DIR = os.path.expanduser("~/Music/YandexMusic/.covers")
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
            d = json.load(open(DB_FILE, "r", encoding="utf-8"))
            if "track_meta" not in d or not isinstance(d["track_meta"], dict):
                d["track_meta"] = {}
            return d
        except Exception:
            pass
    return {"downloaded_ids": [], "track_meta": {}}

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

def extract_cover_url(tr):
    uri = tr.get("coverUri") or tr.get("ogImage") or ""
    if not uri:
        albums = tr.get("albums", [])
        if albums and isinstance(albums[0], dict):
            uri = albums[0].get("coverUri") or albums[0].get("ogImage") or ""
    if not uri:
        return ""
    uri = uri.replace("%%", "200x200")
    if not uri.startswith("http"):
        uri = "https://" + uri.lstrip("/")
    return uri

def ensure_cover_downloaded(tr, fname):
    os.makedirs(COVERS_DIR, exist_ok=True)
    tid = str(tr.get("id", ""))
    cov_name = safe_filename(fname) + ".jpg"
    cov_path = os.path.join(COVERS_DIR, cov_name)
    if os.path.exists(cov_path) and os.path.getsize(cov_path) > 512:
        return cov_path
    url = extract_cover_url(tr)
    if not url:
        return ""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Yandex-Music-API"})
        with urllib.request.urlopen(req, timeout=8) as r:
            img = r.read()
        if len(img) > 512:
            tmp_c = cov_path + ".part"
            with open(tmp_c, "wb") as f:
                f.write(img)
            os.replace(tmp_c, cov_path)
            return cov_path
    except Exception:
        pass
    return ""

def format_track_meta(tr):
    tid = str(tr.get("id", ""))
    title = tr.get("title", "Track")
    ver = tr.get("version", "")
    if ver:
        title = f"{title} ({ver})"
    artists = [a.get("name", "") for a in tr.get("artists", []) if a.get("name")]
    artist_str = ", ".join(artists) if artists else "Unknown"
    dur_ms = int(tr.get("durationMs") or 0)
    dur_sec = max(0, dur_ms // 1000)
    dur_str = f"{dur_sec // 60:02d}:{dur_sec % 60:02d}" if dur_sec > 0 else ""
    return tid, safe_filename(f"{artist_str} - {title}"), artist_str, title, dur_str

def rebuild_local_index():
    os.makedirs(MUSIC_DIR, exist_ok=True)
    os.makedirs(COVERS_DIR, exist_ok=True)
    db_obj = load_db()
    tmeta = db_obj.get("track_meta", {})

    playlists = []
    if not os.path.exists(MUSIC_DIR):
        return playlists

    dirs = []
    for d in sorted(os.listdir(MUSIC_DIR)):
        if d.startswith("."):
            continue
        fp = os.path.join(MUSIC_DIR, d)
        if os.path.isdir(fp):
            dirs.append(d)

    # Приоритетный порядок: Мне нравится, Моя волна, затем остальные
    priority = {"Мне нравится": 0, "Моя волна": 1, "Скрытые": 999}
    dirs.sort(key=lambda x: (priority.get(x, 10), x.lower()))

    for d in dirs:
        pl_dir = os.path.join(MUSIC_DIR, d)
        m3u_path = os.path.join(pl_dir, f"{d}.m3u8")
        ordered_files = []
        seen = set()
        if os.path.exists(m3u_path):
            try:
                for ln in open(m3u_path, "r", encoding="utf-8", errors="ignore"):
                    ln = ln.strip()
                    if ln and not ln.startswith("#") and ln.endswith(".mp3"):
                        if os.path.exists(os.path.join(pl_dir, ln)) and ln not in seen:
                            ordered_files.append(ln)
                            seen.add(ln)
            except Exception:
                pass
        all_mp3 = [f for f in os.listdir(pl_dir) if f.lower().endswith(".mp3")]
        all_mp3.sort(key=lambda x: os.path.getmtime(os.path.join(pl_dir, x)), reverse=True)
        for f in all_mp3:
            if f not in seen:
                ordered_files.append(f)
                seen.add(f)

        if not ordered_files:
            continue

        tracks_out = []
        for fn in ordered_files:
            base = fn[:-4]
            full_p = os.path.join(pl_dir, fn)
            cov_p = os.path.join(COVERS_DIR, base + ".jpg")
            if not os.path.exists(cov_p):
                cov_p = ""
            meta = tmeta.get(base, {})
            if " - " in base:
                art_fb, tit_fb = base.split(" - ", 1)
            else:
                art_fb, tit_fb = "Яндекс.Музыка", base
            tracks_out.append({
                "title": meta.get("title") or tit_fb,
                "artist": meta.get("artist") or art_fb,
                "fullTitle": base,
                "duration": meta.get("duration") or "",
                "path": full_p,
                "cover": cov_p
            })

        playlists.append({
            "title": d,
            "folder": pl_dir,
            "count": len(tracks_out),
            "tracks": tracks_out
        })

    try:
        tmp_i = INDEX_FILE + ".tmp"
        with open(tmp_i, "w", encoding="utf-8") as f:
            json.dump({"playlists": playlists, "ts": time.time()}, f, ensure_ascii=False)
        os.replace(tmp_i, INDEX_FILE)
    except Exception:
        pass
    return playlists

def download_track_list(tracks, folder_name, token, db_set, db_obj):
    dest_dir = os.path.join(MUSIC_DIR, safe_filename(folder_name))
    os.makedirs(dest_dir, exist_ok=True)
    tmeta = db_obj.setdefault("track_meta", {})
    added = 0
    total = len(tracks)
    for idx, tr in enumerate(tracks):
        if os.path.exists(STOP_FILE):
            break
        tid, fname, artist_str, title_str, dur_str = format_track_meta(tr)
        if not tid:
            continue
        tmeta[fname] = {"id": tid, "artist": artist_str, "title": title_str, "duration": dur_str}
        out_path = os.path.join(dest_dir, f"{fname}.mp3")
        key = f"{folder_name}:{tid}"
        hidden_path = os.path.join(MUSIC_DIR, "Скрытые", f"{fname}.mp3")
        if os.path.exists(hidden_path) and os.path.getsize(hidden_path) > 32768:
            continue
        if key in db_set and os.path.exists(out_path) and os.path.getsize(out_path) > 32768:
            # Докачиваем обложку, если трек уже был скачан ранее без обложки
            ensure_cover_downloaded(tr, fname)
            continue
        pct = max(5, int(((idx + 1) * 100) / max(1, total)))
        write_prog(True, pct, f"[{idx+1}/{total}] {folder_name}: {fname[:38]}...")
        try:
            ensure_cover_downloaded(tr, fname)
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

    try:
        save_db(db_obj)
        m3u_lines = ["#EXTM3U"]
        for tr in tracks:
            _, fn, _, _, _ = format_track_meta(tr)
            if os.path.exists(os.path.join(dest_dir, f"{fn}.mp3")):
                m3u_lines.append(f"{fn}.mp3")
        if len(m3u_lines) > 1:
            with open(os.path.join(dest_dir, f"{safe_filename(folder_name)}.m3u8"), "w", encoding="utf-8") as mf:
                mf.write("\n".join(m3u_lines) + "\n")
    except Exception:
        pass
    rebuild_local_index()
    return added

def sync_all_playlists():
    if os.path.exists(STOP_FILE):
        os.remove(STOP_FILE)
    token = read_token()
    if not token:
        write_prog(False, 0, "Токен не задан. Нажмите «Получить токен» и вставьте его.")
        return 0
    write_prog(True, 5, "Подключение к Яндекс.Музыке...")
    try:
        acc = ym_request("/account/status", token)
        uid = acc.get("result", {}).get("account", {}).get("uid")
        if not uid:
            write_prog(False, 0, "Ошибка авторизации: проверьте OAuth-токен")
            return 0
    except Exception:
        write_prog(False, 0, "Ошибка подключения к API Яндекс.Музыки")
        return 0

    db_obj = load_db()
    db_set = set(db_obj.get("downloaded_ids", []))
    total_new = 0

    try:
        write_prog(True, 10, "Проверка плейлиста «Мне нравится»...")
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

    rebuild_local_index()
    if os.path.exists(STOP_FILE):
        write_prog(False, 0, f"Остановлено • Скачано новых: {total_new}")
    else:
        write_prog(False, 100, f"Синхронизировано ✓ Новых треков: {total_new} (~/Music/YandexMusic)")
    return total_new

def download_my_wave(batch_target=100):
    batch_target = max(10, min(500, int(batch_target)))
    if os.path.exists(STOP_FILE):
        os.remove(STOP_FILE)
    token = read_token()
    if not token:
        write_prog(False, 0, "Токен не задан. Нажмите «Получить токен» и вставьте ссылку с access_token.")
        return 0
    write_prog(True, 5, f"Сбор {batch_target} новых треков со станции «Моя волна»...")
    db_obj = load_db()
    db_set = set(db_obj.get("downloaded_ids", []))
    vibe_tracks = []
    seen_ids = set()
    max_rounds = max(6, (batch_target // 4) + 5)
    try:
        for _ in range(max_rounds):
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
                        if f"Моя волна:{tid}" not in db_set:
                            vibe_tracks.append(tr)
                            write_prog(True, min(15, 5 + int(len(vibe_tracks) * 10 / batch_target)), f"Найдено треков Моей волны: {len(vibe_tracks)}/{batch_target}...")
                            if len(vibe_tracks) >= batch_target:
                                break
    except Exception:
        if not vibe_tracks:
            write_prog(False, 0, "Ошибка получения «Моей волны» (проверьте токен)")
            return 0

    if not vibe_tracks:
        write_prog(False, 0, "Не удалось получить треки «Моей волны»")
        return 0

    added = download_track_list(vibe_tracks, "Моя волна", token, db_set, db_obj)
    rebuild_local_index()
    if os.path.exists(STOP_FILE):
        write_prog(False, 0, f"Остановлено • Скачано из Моей волны: {added}")
    else:
        write_prog(False, 100, f"Моя волна ✓ Скачано треков: {added} (~/Music/YandexMusic/Моя волна)")
    return added

if __name__ == "__main__":
    try:
        os.nice(12)
    except Exception:
        pass
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "save_token":
        tok = save_token(sys.argv[2] if len(sys.argv) > 2 else "")
        write_prog(False, 0, "Токен Яндекс.Музыки сохранен ✓" if tok else "Токен очищен")
    elif cmd == "scan_local":
        rebuild_local_index()
    elif cmd == "sync":
        sync_all_playlists()
    elif cmd == "my_wave":
        cnt = int(sys.argv[2]) if len(sys.argv) > 2 else 100
        download_my_wave(cnt)
    elif cmd == "auto_sync":
        do_pls = (sys.argv[2] == "1") if len(sys.argv) > 2 else True
        do_wave = (sys.argv[3] == "1") if len(sys.argv) > 3 else False
        w_cnt = int(sys.argv[4]) if len(sys.argv) > 4 else 50
        tot = 0
        if do_pls:
            tot += sync_all_playlists()
        if do_wave and not os.path.exists(STOP_FILE):
            tot += download_my_wave(w_cnt)
        if not os.path.exists(STOP_FILE):
            write_prog(False, 100, f"Автообновление завершено ✓ Новых треков: {tot}")
    elif cmd == "play_wave_init":
        cnt = int(sys.argv[2]) if len(sys.argv) > 2 else 30
        download_my_wave(min(cnt, 15))
    elif cmd == "like_track":
        base_name = sys.argv[2] if len(sys.argv) > 2 else ""
        tok = read_token()
        db_obj = load_db()
        tid = (db_obj.get("track_meta", {}).get(base_name, {}) or {}).get("id", "")
        if tok and tid:
            try:
                acc = ym_request("/account/status", tok)
                uid = acc.get("result", {}).get("account", {}).get("uid")
                if uid:
                    ym_request(f"/users/{uid}/likes/tracks/add-multiple", tok, data={"track-ids": str(tid)})
            except Exception:
                pass
    elif cmd == "stop":
        open(STOP_FILE, "w").write("1")
        write_prog(False, 0, "Синхронизация остановлена")
