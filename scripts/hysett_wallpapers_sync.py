#!/usr/bin/env python3
import sys, os, json, time, shutil, subprocess, urllib.request, urllib.parse

REPO_API = "https://api.github.com/repos/whrr-fdev/wallpapers/git/trees/HEAD?recursive=1"
RAW_BASE = "https://raw.githubusercontent.com/whrr-fdev/wallpapers/HEAD/"
REPO_GIT = "https://github.com/whrr-fdev/wallpapers.git"
PROG_FILE = "/tmp/hysett_wall_sync.json"
CONF_FILE = os.path.expanduser("~/.config/hypr/scripts/control_center.conf")
ALLOWED_EXTS = (".jpg", ".jpeg", ".png", ".webp", ".mp4", ".webm", ".mkv")

def write_prog(busy, pct, text):
    try:
        tmp = PROG_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"busy": bool(busy), "percent": int(pct), "text": str(text), "ts": time.time()}, f, ensure_ascii=False)
        os.replace(tmp, PROG_FILE)
    except Exception:
        pass

def get_wallpapers_dir():
    default_dir = os.path.expanduser("~/Pictures/Wallpapers")
    if os.path.exists(CONF_FILE):
        try:
            for ln in open(CONF_FILE, "r", encoding="utf-8", errors="ignore"):
                if ln.strip().startswith("wallpapers_dir="):
                    val = ln.strip().split("=", 1)[1].strip()
                    if val:
                        return os.path.expanduser(val)
        except Exception:
            pass
    return default_dir

def sync_via_git_clone(dest_dir):
    write_prog(True, 15, "Клонирование репозитория обоев whrr-fdev/wallpapers...")
    tmp_clone = "/tmp/hysett_wallpapers_clone"
    shutil.rmtree(tmp_clone, ignore_errors=True)
    res = subprocess.run(["git", "clone", "--depth", "1", REPO_GIT, tmp_clone], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if res.returncode != 0 or not os.path.exists(tmp_clone):
        write_prog(False, 0, "Не удалось подключиться к GitHub (whrr-fdev/wallpapers)")
        return 0
    added = 0
    for root, dirs, files in os.walk(tmp_clone):
        if ".git" in root.split(os.sep):
            continue
        rel_dir = os.path.relpath(root, tmp_clone)
        cat_dir = os.path.join(dest_dir, "General" if rel_dir == "." else rel_dir)
        for fn in files:
            if not fn.lower().endswith(ALLOWED_EXTS):
                continue
            os.makedirs(cat_dir, exist_ok=True)
            dst = os.path.join(cat_dir, fn)
            if not os.path.exists(dst) or os.path.getsize(dst) == 0:
                shutil.copy2(os.path.join(root, fn), dst)
                added += 1
    shutil.rmtree(tmp_clone, ignore_errors=True)
    return added

def sync_wallpapers():
    dest_dir = get_wallpapers_dir()
    os.makedirs(dest_dir, exist_ok=True)
    write_prog(True, 5, "Проверка обоев в репозитории whrr-fdev/wallpapers...")
    try:
        req = urllib.request.Request(REPO_API, headers={"User-Agent": "HySett-Updater", "Accept": "application/vnd.github.v3+json"})
        with urllib.request.urlopen(req, timeout=12) as r:
            data = json.loads(r.read().decode("utf-8", errors="ignore"))
        tree = data.get("tree", [])
        media_items = [
            it for it in tree
            if it.get("type") == "blob" and it.get("path", "").lower().endswith(ALLOWED_EXTS)
        ]
        if not media_items:
            added = sync_via_git_clone(dest_dir)
            write_prog(False, 100, f"Обои синхронизированы ✓ Добавлено: {added}")
            return

        to_download = []
        for it in media_items:
            rel_path = it["path"]
            parts = rel_path.split("/")
            if len(parts) == 1:
                local_path = os.path.join(dest_dir, "General", parts[0])
            else:
                local_path = os.path.join(dest_dir, *parts)
            if not os.path.exists(local_path) or os.path.getsize(local_path) < 1024:
                to_download.append((rel_path, local_path))

        if not to_download:
            write_prog(False, 100, f"Все обои с GitHub уже загружены ({len(media_items)} шт.) ✓")
            return

        added = 0
        total = len(to_download)
        for idx, (rel_p, loc_p) in enumerate(to_download):
            pct = max(8, int(((idx + 1) * 100) / max(1, total)))
            short_name = os.path.basename(rel_p)
            write_prog(True, pct, f"Загрузка обоев [{idx+1}/{total}]: {short_name}...")
            os.makedirs(os.path.dirname(loc_p), exist_ok=True)
            url = RAW_BASE + urllib.parse.quote(rel_p)
            try:
                dl_req = urllib.request.Request(url, headers={"User-Agent": "HySett-Updater"})
                with urllib.request.urlopen(dl_req, timeout=30) as resp:
                    blob = resp.read()
                if len(blob) > 512:
                    tmp_f = loc_p + ".part"
                    with open(tmp_f, "wb") as wf:
                        wf.write(blob)
                    os.replace(tmp_f, loc_p)
                    added += 1
            except Exception:
                pass
        write_prog(False, 100, f"Загружено новых обоев с GitHub: {added} ✓")
    except Exception:
        added = sync_via_git_clone(dest_dir)
        write_prog(False, 100, f"Обои синхронизированы ✓ Новых: {added}")

if __name__ == "__main__":
    try:
        os.nice(10)
    except Exception:
        pass
    sync_wallpapers()
