#!/usr/bin/env python3
import sys, os, re, json, time, uuid, shutil, socket, zipfile, mimetypes, urllib.request, urllib.parse, subprocess, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE_FILE = "/tmp/hysett_web_share_state.json"
PID_FILE = "/tmp/hysett_web_share.pid"
CUSTOM_SITES_DIR = "/tmp/hysett_custom_sites"
os.makedirs(CUSTOM_SITES_DIR, exist_ok=True)

def load_state():
    st = {
        "running": False,
        "url": "",
        "qr_path": "",
        "status": "Сервер раздачи выключен",
        "mode": "files",
        "active_title": "",
        "primary_id": "",
        "port": 0,
        "items": []
    }
    if os.path.exists(STATE_FILE):
        try:
            st.update(json.load(open(STATE_FILE, "r", encoding="utf-8")))
        except Exception:
            pass
    return st

def save_state(st):
    try:
        items = st.get("items", [])
        prim_id = st.get("primary_id", "")
        prim_item = next((x for x in items if x.get("id") == prim_id), items[0] if items else None)
        if prim_item:
            st["primary_id"] = prim_item["id"]
            st["mode"] = prim_item.get("kind", "file")
            st["active_title"] = prim_item.get("label", "")
        else:
            st["primary_id"] = ""
            st["mode"] = "files"
            st["active_title"] = ""
        for x in items:
            x["is_primary"] = (x.get("id") == st["primary_id"])
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(st, f, ensure_ascii=False)
        os.replace(tmp, STATE_FILE)
    except Exception:
        pass

def get_lan_ip():
    try:
        out = subprocess.check_output(["ip", "-4", "-o", "addr", "show"], stderr=subprocess.DEVNULL).decode()
        for line in out.splitlines():
            parts = line.split()
            if len(parts) >= 4:
                dev, ip = parts[1], parts[3].split("/")[0]
                if dev not in ("lo", "singbox_tun0", "tun0") and not ip.startswith("127.") and not ip.startswith("172.19."):
                    return ip
    except Exception:
        pass
    return "127.0.0.1"

def generate_qr(url_str):
    if not url_str:
        return ""
    ts = int(time.time() * 1000)
    out_file = f"/tmp/hysett_webshare_qr_{ts}.png"
    for old in os.listdir("/tmp"):
        if old.startswith("hysett_webshare_qr_") and old.endswith(".png"):
            try:
                os.remove(os.path.join("/tmp", old))
            except Exception:
                pass
    try:
        if shutil.which("qrencode"):
            subprocess.run(["qrencode", "-o", out_file, "-s", "8", "-m", "2", url_str], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=4)
            if os.path.exists(out_file) and os.path.getsize(out_file) > 100:
                return out_file
    except Exception:
        pass
    return ""

def is_daemon_alive():
    if not os.path.exists(PID_FILE):
        return False
    try:
        pid = int(open(PID_FILE, "r").read().strip())
        os.kill(pid, 0)
        return True
    except Exception:
        return False

def render_file_page(st, focus_item=None):
    items = st.get("items", [])
    if not focus_item and items:
        focus_item = next((x for x in items if x.get("is_primary")), items[0])
    cards_html = ""
    for it in items:
        iid = it["id"]
        lbl = it["label"]
        sz = it.get("size", "")
        kind = it.get("kind", "file")
        ext = os.path.splitext(lbl)[1].lower()
        preview = ""
        if kind == "file":
            if ext in (".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg"):
                preview = f'<div style="margin:10px 0;"><img src="/raw/{iid}" style="max-width:100%;max-height:340px;border-radius:12px;display:block;margin:0 auto;"></div>'
            elif ext in (".mp4", ".webm", ".mov", ".mkv"):
                preview = f'<div style="margin:10px 0;"><video src="/raw/{iid}" controls style="width:100%;max-height:360px;border-radius:12px;"></video></div>'
            elif ext in (".mp3", ".flac", ".ogg", ".wav", ".m4a"):
                preview = f'<div style="margin:10px 0;"><audio src="/raw/{iid}" controls style="width:100%;"></audio></div>'
        act_btn = f'<a class="btn" href="/site/{iid}/">Открыть сайт</a>' if kind == "site" else f'<a class="btn" href="/dl/{iid}" download>Скачать файл ({sz})</a>'
        badge = "САЙТ" if kind == "site" else f"ФАЙЛ • {sz}"
        cards_html += f'''
        <div class="card">
          <div class="tag">{badge} • {it.get("time","")}</div>
          <div class="title">{lbl}</div>
          {preview}
          <div style="margin-top:12px;">{act_btn}</div>
        </div>'''
    if not cards_html:
        cards_html = '<div class="card"><div class="title">Пока нет опубликованных файлов или сайтов</div></div>'
    return f"""<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>HySett Share</title>
<style>
  * {{ box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }}
  body {{ background: #0d0f14; color: #f0f2f8; padding: 24px 16px; max-width: 640px; margin: 0 auto; }}
  h1 {{ font-size: 22px; margin-bottom: 16px; color: #a8c7fa; }}
  .card {{ background: #171a22; border: 1px solid rgba(255,255,255,0.09); border-radius: 16px; padding: 18px; margin-bottom: 14px; }}
  .tag {{ font-size: 11px; color: #8c92a4; font-weight: 700; margin-bottom: 4px; }}
  .title {{ font-size: 16px; font-weight: 700; color: #fff; word-break: break-word; }}
  .btn {{ display: inline-flex; align-items: center; justify-content: center; width: 100%; background: #a8c7fa; color: #081226; font-weight: 700; border-radius: 10px; padding: 12px 16px; font-size: 14px; text-decoration: none; }}
</style>
</head>
<body>
  <h1>HySett • Поделились с вами</h1>
  {cards_html}
</body>
</html>""".encode("utf-8")

class WebShareHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def serve_local_file(self, fp, as_download=False):
        if not fp or not os.path.exists(fp) or not os.path.isfile(fp):
            self.send_response(404)
            self.end_headers()
            return
        ctype, _ = mimetypes.guess_type(fp)
        if not ctype:
            ctype = "text/html; charset=utf-8" if fp.endswith((".html", ".htm")) else "application/octet-stream"
        elif ctype.startswith("text/"):
            ctype += "; charset=utf-8"
        sz = os.path.getsize(fp)
        self.send_response(200)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(sz))
        if as_download:
            fn = os.path.basename(fp)
            self.send_header("Content-Disposition", f'attachment; filename="{urllib.parse.quote(fn)}"')
        self.end_headers()
        with open(fp, "rb") as f:
            shutil.copyfileobj(f, self.wfile)

    def serve_site_item(self, item, sub_path):
        root_dir = item.get("site_dir", "")
        entry = item.get("entry_file", "index.html")
        clean_sub = sub_path.lstrip("/")
        if not clean_sub:
            target = os.path.join(root_dir, entry)
        else:
            target = os.path.abspath(os.path.join(root_dir, clean_sub))
            if not target.startswith(os.path.abspath(root_dir)):
                self.send_response(403)
                self.end_headers()
                return
            if os.path.isdir(target):
                target = os.path.join(target, "index.html")
        self.serve_local_file(target, as_download=False)

    def do_GET(self):
        st = load_state()
        items = st.get("items", [])
        path = urllib.parse.unquote(self.path.split("?")[0])

        if path.startswith("/dl/") or path.startswith("/raw/"):
            as_dl = path.startswith("/dl/")
            iid = path.split("/")[2] if len(path.split("/")) > 2 else ""
            it = next((x for x in items if x.get("id") == iid), None)
            if it and it.get("path"):
                self.serve_local_file(it["path"], as_download=as_dl)
                return
            self.send_response(404)
            self.end_headers()
            return

        if path.startswith("/f/"):
            iid = path.split("/")[2] if len(path.split("/")) > 2 else ""
            it = next((x for x in items if x.get("id") == iid), None)
            body = render_file_page({"items": [it]} if it else st, it)
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
            return

        if path.startswith("/site/"):
            parts = path.split("/")
            iid = parts[2] if len(parts) > 2 else ""
            sub = "/".join(parts[3:])
            it = next((x for x in items if x.get("id") == iid and x.get("kind") == "site"), None)
            if it:
                self.serve_site_item(it, sub)
                return

        prim = next((x for x in items if x.get("is_primary")), items[0] if items else None)
        if prim and prim.get("kind") == "site":
            self.serve_site_item(prim, path)
            return

        body = render_file_page(st, prim)
        self.send_response(200)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

def run_daemon():
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("0.0.0.0", 0))
    port = sock.getsockname()[1]
    sock.close()

    st = load_state()
    lan_url = f"http://{get_lan_ip()}:{port}"
    st["running"] = True
    st["port"] = port
    st["url"] = lan_url
    st["qr_path"] = generate_qr(lan_url)
    st["status"] = "Подключение публичного интернет-туннеля..."
    save_state(st)

    srv = ThreadingHTTPServer(("0.0.0.0", port), WebShareHandler)
    threading.Thread(target=srv.serve_forever, daemon=True).start()

    tunnels = [
        (["ssh", "-T", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ServerAliveInterval=20", "-o", "ConnectTimeout=8", "-R", f"80:127.0.0.1:{port}", "nokey@localhost.run"], r"(https://[a-zA-Z0-9.-]+\.lhr\.life)"),
        (["ssh", "-T", "-p", "443", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ServerAliveInterval=20", "-o", "ConnectTimeout=8", f"-R0:127.0.0.1:{port}", "a.pinggy.io"], r"(https://[a-zA-Z0-9.-]+\.pinggy\.link)"),
        (["ssh", "-T", "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null", "-o", "ServerAliveInterval=20", "-o", "ConnectTimeout=8", "-R", f"80:127.0.0.1:{port}", "serveo.net"], r"(https://[a-zA-Z0-9.-]+\.serveo\.net)")
    ]

    for cmd, pattern in tunnels:
        if not is_daemon_alive():
            break
        try:
            proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
            bound_url = ""
            for line in proc.stdout:
                if not bound_url:
                    m = re.search(pattern, line)
                    if m:
                        bound_url = m.group(1)
                        st = load_state()
                        st["running"] = True
                        st["url"] = bound_url
                        st["qr_path"] = generate_qr(bound_url)
                        st["status"] = "Публичная ссылка активна ✓ Можно скидывать другу"
                        save_state(st)
            proc.wait()
        except Exception:
            pass

    while is_daemon_alive():
        time.sleep(2)

def ensure_started():
    if not is_daemon_alive():
        subprocess.Popen([sys.executable, __file__, "_daemon"], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(10):
            time.sleep(0.25)
            st = load_state()
            if st.get("running") and st.get("url"):
                break

def format_size(sz):
    mb = sz / (1024.0 * 1024.0)
    return f"{mb:.1f} MB" if mb >= 1.0 else f"{max(1, int(sz / 1024))} KB"

def cmd_add_path(raw_path):
    fp = os.path.expanduser((raw_path or "").strip())
    if not fp or not os.path.exists(fp):
        st = load_state()
        st["status"] = f"Путь не найден: {fp}"
        save_state(st)
        cmd_status()
        return

    ensure_started()
    st = load_state()
    items = st.get("items", [])
    iid = uuid.uuid4().hex[:8]
    now_str = time.strftime("%H:%M:%S")

    if os.path.isdir(fp):
        entry = "index.html"
        if not os.path.exists(os.path.join(fp, entry)):
            htmls = [f for f in os.listdir(fp) if f.lower().endswith((".html", ".htm"))]
            if htmls:
                entry = htmls[0]
        items.insert(0, {
            "id": iid,
            "kind": "site",
            "label": os.path.basename(fp.rstrip("/")) or "Сайт",
            "path": fp,
            "site_dir": fp,
            "entry_file": entry,
            "size": "Папка сайта",
            "time": now_str
        })
        st["primary_id"] = iid
        st["status"] = f"Сайт «{os.path.basename(fp)}» опубликован по ссылке ✓"
    elif fp.lower().endswith((".html", ".htm")):
        items.insert(0, {
            "id": iid,
            "kind": "site",
            "label": os.path.basename(fp),
            "path": fp,
            "site_dir": os.path.dirname(os.path.abspath(fp)),
            "entry_file": os.path.basename(fp),
            "size": format_size(os.path.getsize(fp)),
            "time": now_str
        })
        st["primary_id"] = iid
        st["status"] = f"HTML-сайт «{os.path.basename(fp)}» опубликован ✓"
    elif fp.lower().endswith(".zip") and zipfile.is_zipfile(fp):
        ext_dir = os.path.join(CUSTOM_SITES_DIR, iid)
        os.makedirs(ext_dir, exist_ok=True)
        with zipfile.ZipFile(fp, "r") as zf:
            zf.extractall(ext_dir)
        html_entry = ""
        site_root = ext_dir
        for root, _, files in os.walk(ext_dir):
            for f in files:
                if f.lower() == "index.html":
                    site_root, html_entry = root, f
                    break
                elif f.lower().endswith((".html", ".htm")) and not html_entry:
                    site_root, html_entry = root, f
            if html_entry == "index.html":
                break
        if html_entry:
            items.insert(0, {
                "id": iid,
                "kind": "site",
                "label": os.path.basename(fp),
                "path": fp,
                "site_dir": site_root,
                "entry_file": html_entry,
                "size": format_size(os.path.getsize(fp)),
                "time": now_str
            })
            st["primary_id"] = iid
            st["status"] = f"ZIP-сайт «{os.path.basename(fp)}» распакован и опубликован ✓"
        else:
            items.insert(0, {
                "id": iid,
                "kind": "file",
                "label": os.path.basename(fp),
                "path": fp,
                "size": format_size(os.path.getsize(fp)),
                "time": now_str
            })
            st["primary_id"] = iid
            st["status"] = f"Архив «{os.path.basename(fp)}» готов к скачиванию ✓"
    else:
        items.insert(0, {
            "id": iid,
            "kind": "file",
            "label": os.path.basename(fp),
            "path": fp,
            "size": format_size(os.path.getsize(fp)),
            "time": now_str
        })
        st["primary_id"] = iid
        st["status"] = f"Файл «{os.path.basename(fp)}» доступен по ссылке ✓"

    st["items"] = items[:40]
    save_state(st)
    cmd_status()

def cmd_add_html(title, code):
    ensure_started()
    iid = uuid.uuid4().hex[:8]
    sdir = os.path.join(CUSTOM_SITES_DIR, iid)
    os.makedirs(sdir, exist_ok=True)
    clean_title = os.path.basename(title.strip() or "index.html")
    if not clean_title.lower().endswith((".html", ".htm")):
        clean_title += ".html"
    fp = os.path.join(sdir, "index.html")
    with open(fp, "w", encoding="utf-8") as f:
        f.write(code)
    st = load_state()
    items = st.get("items", [])
    items.insert(0, {
        "id": iid,
        "kind": "site",
        "label": clean_title,
        "path": fp,
        "site_dir": sdir,
        "entry_file": "index.html",
        "size": format_size(os.path.getsize(fp)),
        "time": time.strftime("%H:%M:%S")
    })
    st["primary_id"] = iid
    st["items"] = items[:40]
    st["status"] = f"HTML-страница «{clean_title}» опубликована ✓"
    save_state(st)
    cmd_status()

def cmd_stop():
    if os.path.exists(PID_FILE):
        try:
            pid = int(open(PID_FILE).read().strip())
            os.kill(pid, 9)
        except Exception:
            pass
        try:
            os.remove(PID_FILE)
        except Exception:
            pass
    st = load_state()
    st["running"] = False
    st["url"] = ""
    st["status"] = "Сервер раздачи выключен"
    save_state(st)
    cmd_status()

def cmd_pick(is_folder):
    for cmd in (
        ["zenity", "--file-selection"] + (["--directory"] if is_folder else []),
        ["kdialog", "--getexistingdirectory" if is_folder else "--getopenfilename", os.path.expanduser("~")]
    ):
        if shutil.which(cmd[0]):
            try:
                out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
                if out:
                    print(out)
                return
            except Exception:
                return
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        res = filedialog.askdirectory() if is_folder else filedialog.askopenfilename()
        if res:
            print(res)
    except Exception:
        pass

def cmd_status():
    st = load_state()
    alive = is_daemon_alive()
    if st.get("running") != alive:
        st["running"] = alive
    save_state(st)
    print(json.dumps(st, ensure_ascii=False))

if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "status"
    if c == "_daemon":
        run_daemon()
    elif c == "start":
        ensure_started()
        cmd_status()
    elif c == "stop":
        cmd_stop()
    elif c == "add_path":
        cmd_add_path(sys.argv[2] if len(sys.argv) > 2 else "")
    elif c == "add_html":
        cmd_add_html(sys.argv[2] if len(sys.argv) > 2 else "index.html", sys.argv[3] if len(sys.argv) > 3 else "")
    elif c == "pick_file":
        cmd_pick(False)
    elif c == "pick_folder":
        cmd_pick(True)
    elif c == "remove":
        iid = sys.argv[2] if len(sys.argv) > 2 else ""
        st = load_state()
        st["items"] = [x for x in st.get("items", []) if x.get("id") != iid]
        save_state(st)
        cmd_status()
    elif c == "set_primary":
        iid = sys.argv[2] if len(sys.argv) > 2 else ""
        st = load_state()
        st["primary_id"] = iid
        save_state(st)
        cmd_status()
    elif c == "clear":
        st = load_state()
        st["items"] = []
        st["primary_id"] = ""
        save_state(st)
        cmd_status()
    else:
        cmd_status()
