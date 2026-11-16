#!/usr/bin/env python3
import sys
import os
import json
import urllib.request
import urllib.parse
import tempfile
import shutil
from concurrent.futures import ThreadPoolExecutor

UA = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"

CURATED_CURSORS = [
    {
        "id": "curated_bibata_modern",
        "title": "Bibata Modern Cursors",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "520k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/Bibata_Cursor/main/assets/bibata_modern.png",
        "variants": [
            {"name": "Bibata-Modern-Ice.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Ice.tar.xz"},
            {"name": "Bibata-Modern-Classic.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz"},
            {"name": "Bibata-Modern-Amber.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Amber.tar.xz"}
        ]
    },
    {
        "id": "curated_bibata_original",
        "title": "Bibata Original (Sharp)",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "310k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/Bibata_Cursor/main/assets/bibata_original.png",
        "variants": [
            {"name": "Bibata-Original-Ice.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Ice.tar.xz"},
            {"name": "Bibata-Original-Classic.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Classic.tar.xz"},
            {"name": "Bibata-Original-Amber.tar.xz", "url": "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Original-Amber.tar.xz"}
        ]
    },
    {
        "id": "curated_catppuccin",
        "title": "Catppuccin Cursors",
        "author": "catppuccin",
        "source": "GitHub",
        "downloads": "290k+",
        "preview": "https://raw.githubusercontent.com/catppuccin/cursors/main/assets/preview.webp",
        "variants": [
            {"name": "Mocha Dark (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-dark-cursors.zip"},
            {"name": "Mocha Light (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-light-cursors.zip"},
            {"name": "Mocha Mauve (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-mauve-cursors.zip"},
            {"name": "Mocha Blue (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-mocha-blue-cursors.zip"},
            {"name": "Macchiato Dark (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-macchiato-dark-cursors.zip"},
            {"name": "Frappe Dark (.zip)", "url": "https://github.com/catppuccin/cursors/releases/latest/download/catppuccin-frappe-dark-cursors.zip"}
        ]
    },
    {
        "id": "curated_phinger",
        "title": "Phinger Cursors",
        "author": "phisch",
        "source": "GitHub",
        "downloads": "185k+",
        "preview": "https://raw.githubusercontent.com/phisch/phinger-cursors/main/preview.png",
        "variants": [
            {"name": "phinger-cursors-variants.tar.bz2", "url": "https://github.com/phisch/phinger-cursors/releases/latest/download/phinger-cursors-variants.tar.bz2"}
        ]
    },
    {
        "id": "curated_breezex",
        "title": "BreezeX Cursor",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "210k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/BreezeX_Cursor/main/assets/samples.png",
        "variants": [
            {"name": "BreezeX-Dark.tar.xz", "url": "https://github.com/ful1e5/BreezeX_Cursor/releases/latest/download/BreezeX-Dark.tar.xz"},
            {"name": "BreezeX-Light.tar.xz", "url": "https://github.com/ful1e5/BreezeX_Cursor/releases/latest/download/BreezeX-Light.tar.xz"}
        ]
    },
    {
        "id": "curated_apple",
        "title": "macOS Apple Cursor",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "340k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/apple_cursor/main/assets/samples.png",
        "variants": [
            {"name": "macOS.tar.xz", "url": "https://github.com/ful1e5/apple_cursor/releases/latest/download/macOS.tar.xz"},
            {"name": "macOS-White.tar.xz", "url": "https://github.com/ful1e5/apple_cursor/releases/latest/download/macOS-White.tar.xz"}
        ]
    },
    {
        "id": "curated_fuchsia",
        "title": "Fuchsia Cursor",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "95k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/fuchsia-cursor/main/assets/samples.png",
        "variants": [
            {"name": "Fuchsia.tar.xz", "url": "https://github.com/ful1e5/fuchsia-cursor/releases/latest/download/Fuchsia.tar.xz"},
            {"name": "Fuchsia-Pop.tar.xz", "url": "https://github.com/ful1e5/fuchsia-cursor/releases/latest/download/Fuchsia-Pop.tar.xz"}
        ]
    },
    {
        "id": "curated_google_dot",
        "title": "GoogleDot Cursor",
        "author": "ful1e5",
        "source": "GitHub",
        "downloads": "130k+",
        "preview": "https://raw.githubusercontent.com/ful1e5/Google_Cursor/main/assets/samples.png",
        "variants": [
            {"name": "GoogleDot-Black.tar.gz", "url": "https://github.com/ful1e5/Google_Cursor/releases/latest/download/GoogleDot-Black.tar.gz"},
            {"name": "GoogleDot-White.tar.gz", "url": "https://github.com/ful1e5/Google_Cursor/releases/latest/download/GoogleDot-White.tar.gz"},
            {"name": "GoogleDot-Blue.tar.gz", "url": "https://github.com/ful1e5/Google_Cursor/releases/latest/download/GoogleDot-Blue.tar.gz"}
        ]
    }
]


def http_get_json(url, timeout=8):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return json.loads(resp.read().decode("utf-8", errors="replace"))


def is_valid_archive(name_or_url):
    low = (name_or_url or "").lower()
    exts = (".tar.gz", ".tgz", ".tar.xz", ".txz", ".tar.bz2", ".tbz2", ".tar.zst", ".zip", ".hlc", ".tar")
    return any(low.endswith(ext) or (ext + "?") in low for ext in exts)


def search_ocs(query):
    results = []
    params = {
        "categories": "107",
        "format": "json",
        "pagesize": "24",
        "sortmode": "high" if not query else "new"
    }
    if query:
        params["search"] = query

    endpoints = [
        "https://api.kde-look.org/ocs/v1/content/data?" + urllib.parse.urlencode(params),
        "https://api.opendesktop.org/ocs/v1/content/data?" + urllib.parse.urlencode(params)
    ]

    data = None
    for ep in endpoints:
        try:
            data = http_get_json(ep, timeout=7)
            if data and "data" in data:
                break
        except Exception:
            continue

    if not data or not isinstance(data.get("data"), list):
        return results

    for item in data["data"]:
        title = str(item.get("name") or "").strip()
        if not title:
            continue

        variants = []
        for idx in range(1, 15):
            dl_url = str(item.get(f"downloadlink{idx}") or "").strip()
            dl_name = str(item.get(f"downloadname{idx}") or "").strip()
            if not dl_url:
                continue
            if not dl_name:
                dl_name = os.path.basename(urllib.parse.urlparse(dl_url).path) or f"archive_{idx}.tar.gz"
            if is_valid_archive(dl_name) or is_valid_archive(dl_url):
                variants.append({"name": dl_name, "url": dl_url})

        if not variants:
            continue

        preview = str(item.get("previewpic1") or item.get("smallpreviewpic1") or "").strip()
        downloads = str(item.get("downloads") or "0")
        author = str(item.get("personid") or "Gnome-Look")
        cid = "ocs_" + str(item.get("id") or title)

        results.append({
            "id": cid,
            "title": title,
            "author": author,
            "source": "Gnome-Look",
            "downloads": downloads,
            "preview": preview,
            "variants": variants
        })
    return results


def search_github(query):
    results = []
    q = f"{query} cursor theme" if query else "cursor theme linux xcursor"
    url = "https://api.github.com/search/repositories?" + urllib.parse.urlencode({
        "q": q,
        "sort": "stars",
        "order": "desc",
        "per_page": "8"
    })
    try:
        data = http_get_json(url, timeout=6)
        items = data.get("items") or []
    except Exception:
        return results

    def fetch_repo_release(repo):
        full_name = repo.get("full_name", "")
        if not full_name:
            return None
        try:
            rel = http_get_json(f"https://api.github.com/repos/{full_name}/releases/latest", timeout=5)
        except Exception:
            return None
        assets = rel.get("assets") or []
        variants = []
        for a in assets:
            aname = str(a.get("name") or "")
            aurl = str(a.get("browser_download_url") or "")
            if aurl and is_valid_archive(aname) and "windows" not in aname.lower():
                variants.append({"name": aname, "url": aurl})
        if not variants:
            return None
        stars = repo.get("stargazers_count", 0)
        owner = (repo.get("owner") or {}).get("login", "github")
        return {
            "id": "gh_" + str(repo.get("id", full_name)),
            "title": str(repo.get("name") or full_name),
            "author": owner,
            "source": "GitHub",
            "downloads": f"★ {stars}",
            "preview": f"https://opengraph.githubassets.com/1/{full_name}",
            "variants": variants
        }

    with ThreadPoolExecutor(max_workers=4) as ex:
        for res in ex.map(fetch_repo_release, items):
            if res:
                results.append(res)
    return results


def do_search(query, source):
    q_low = (query or "").strip().lower()
    src_low = (source or "all").strip().lower()

    out = []
    seen_titles = set()

    if src_low in ("all", "popular", "github"):
        for c in CURATED_CURSORS:
            if not q_low or q_low in c["title"].lower() or q_low in c["author"].lower():
                out.append(c)
                seen_titles.add(c["title"].lower())

    if src_low == "popular" and not q_low:
        return out

    with ThreadPoolExecutor(max_workers=2) as ex:
        fut_ocs = ex.submit(search_ocs, query) if src_low in ("all", "gnome-look", "popular") else None
        fut_gh = ex.submit(search_github, query) if (src_low in ("all", "github") and q_low) else None

        if fut_ocs:
            for item in fut_ocs.result():
                t = item["title"].lower()
                if t not in seen_titles:
                    seen_titles.add(t)
                    out.append(item)
        if fut_gh:
            for item in fut_gh.result():
                t = item["title"].lower()
                if t not in seen_titles:
                    seen_titles.add(t)
                    out.append(item)

    return out


def do_download(url, filename_hint=""):
    dl_dir = "/tmp/hysett_cursor_dl"
    os.makedirs(dl_dir, exist_ok=True)

    parsed_name = os.path.basename(urllib.parse.urlparse(url).path)
    fname = filename_hint.strip() or parsed_name or "cursor_archive.tar.gz"
    fname = "".join(ch for ch in fname if ch.isalnum() or ch in ("-", "_", "."))
    if not is_valid_archive(fname):
        fname += ".tar.gz"

    dst_path = os.path.join(dl_dir, fname)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=45) as resp, open(dst_path, "wb") as out_f:
        shutil.copyfileobj(resp, out_f)

    return dst_path


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "search"
    if cmd == "search":
        q = sys.argv[2] if len(sys.argv) > 2 else ""
        src = sys.argv[3] if len(sys.argv) > 3 else "all"
        items = do_search(q, src)
        print(json.dumps(items, ensure_ascii=False))
    elif cmd == "download":
        url = sys.argv[2] if len(sys.argv) > 2 else ""
        hint = sys.argv[3] if len(sys.argv) > 3 else ""
        try:
            saved = do_download(url, hint)
            print(json.dumps({"ok": True, "path": saved}, ensure_ascii=False))
        except Exception as e:
            print(json.dumps({"ok": False, "error": str(e)}, ensure_ascii=False))
            sys.exit(1)
