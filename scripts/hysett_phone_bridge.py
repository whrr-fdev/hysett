#!/usr/bin/env python3
import sys, os, re, json, time, uuid, shutil, socket, urllib.request, urllib.parse, subprocess, threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE_FILE = "/tmp/hysett_phone_bridge_state.json"
PID_FILE = "/tmp/hysett_phone_bridge.pid"
SCRCPY_LOG = "/tmp/hysett_scrcpy.log"
DOWNLOAD_DIR = os.path.expanduser("~/Downloads/PhoneTransfer")
os.makedirs(DOWNLOAD_DIR, exist_ok=True)

def is_scrcpy_alive():
    return subprocess.run(["pgrep", "-x", "scrcpy"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0

def load_state():
    st = {
        "running": False,
        "scrcpy_running": False,
        "url": "",
        "qr_path": "",
        "status": "Мост выключен",
        "token": "",
        "port": 0,
        "phone_ip": "",
        "items": []
    }
    if os.path.exists(STATE_FILE):
        try:
            loaded = json.load(open(STATE_FILE, "r", encoding="utf-8"))
            st.update(loaded)
        except Exception:
            pass
    st["scrcpy_running"] = is_scrcpy_alive()
    return st

def save_state(st):
    try:
        st["scrcpy_running"] = is_scrcpy_alive()
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(st, f, ensure_ascii=False)
        os.replace(tmp, STATE_FILE)
    except Exception:
        pass

def get_lan_ip():
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def generate_qr(url_str):
    if not url_str:
        return ""
    ts = int(time.time() * 1000)
    out_file = f"/tmp/hysett_phone_qr_{ts}.png"
    for old in os.listdir("/tmp"):
        if old.startswith("hysett_phone_qr_") and old.endswith(".png"):
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
    try:
        q_url = "https://api.qrserver.com/v1/create-qr-code/?size=260x260&margin=10&data=" + urllib.parse.quote(url_str)
        req = urllib.request.Request(q_url, headers={"User-Agent": "HySett-Bridge"})
        with urllib.request.urlopen(req, timeout=6) as r:
            data = r.read()
        if len(data) > 100:
            with open(out_file, "wb") as f:
                f.write(data)
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

MOBILE_HTML = """<!DOCTYPE html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
<title>HySett Bridge</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; font-family: system-ui, -apple-system, sans-serif; }
  body { background: #0e1015; color: #f0f2f8; padding: 16px; max-width: 540px; margin: 0 auto; }
  h1 { font-size: 20px; margin-bottom: 14px; color: #a8c7fa; }
  .card { background: #181b22; border: 1px solid rgba(255,255,255,0.09); border-radius: 16px; padding: 14px; margin-bottom: 14px; }
  .card h2 { font-size: 14px; margin-bottom: 10px; color: #dce2f0; }
  textarea { width: 100%; height: 84px; background: #101218; color: #fff; border: 1px solid rgba(255,255,255,0.15); border-radius: 10px; padding: 10px; font-size: 14px; resize: none; margin-bottom: 10px; }
  .btn { display: inline-flex; align-items: center; justify-content: center; width: 100%; background: #a8c7fa; color: #081226; font-weight: 700; border: none; border-radius: 10px; padding: 11px 14px; font-size: 14px; cursor: pointer; text-decoration: none; }
  .btn:active { transform: scale(0.98); opacity: 0.9; }
  .btn-sec { background: #262b38; color: #e2e6f0; padding: 7px 12px; font-size: 12px; width: auto; border-radius: 8px; }
  input[type=file] { display: none; }
  .file-lbl { display: flex; align-items: center; justify-content: center; border: 1.5px dashed #a8c7fa; color: #a8c7fa; border-radius: 12px; padding: 16px; text-align: center; font-weight: 600; font-size: 14px; cursor: pointer; }
  .item { background: #12141a; border: 1px solid rgba(255,255,255,0.07); border-radius: 12px; padding: 10px 12px; margin-bottom: 8px; display: flex; justify-content: space-between; align-items: center; gap: 10px; }
  .item-body { flex: 1; min-width: 0; }
  .item-tag { font-size: 11px; color: #8c92a4; margin-bottom: 2px; }
  .item-txt { font-size: 13px; color: #fff; word-break: break-word; }
  .toast { position: fixed; bottom: 18px; left: 50%; transform: translateX(-50%); background: #69f0ae; color: #052010; padding: 8px 18px; border-radius: 20px; font-weight: 700; font-size: 13px; display: none; z-index: 99; }
</style>
</head>
<body>
  <h1>HySett • Телефон ⇄ ПК</h1>

  <div class="card">
    <h2>Отправить текст на ПК</h2>
    <textarea id="txtIn" placeholder="Введите текст..."></textarea>
    <button class="btn" onclick="sendText()">Отправить</button>
  </div>

  <div class="card">
    <h2>Отправить файлы на ПК</h2>
    <label class="file-lbl" for="fileIn" id="fileStatus">Выбрать файлы или фото</label>
    <input type="file" id="fileIn" multiple onchange="uploadFiles(this.files)">
  </div>

  <div class="card">
    <h2>Лента обмена</h2>
    <div id="itemsBox">Пусто</div>
  </div>

  <div class="toast" id="toast">Готово ✓</div>

<script>
const TOKEN = "__TOKEN__";
let lastSig = "";
function showToast(msg) {
  const t = document.getElementById('toast');
  t.textContent = msg;
  t.style.display = 'block';
  setTimeout(() => t.style.display = 'none', 2200);
}
async function sendText() {
  const el = document.getElementById('txtIn');
  const val = el.value.trim();
  if (!val) return;
  await fetch('/' + TOKEN + '/api/text', { method: 'POST', body: val });
  el.value = '';
  showToast('Отправлено на ПК ✓');
  loadItems(true);
}
async function uploadFiles(files) {
  if (!files || !files.length) return;
  const lbl = document.getElementById('fileStatus');
  for (let i = 0; i < files.length; i++) {
    lbl.textContent = `Загрузка (${i+1}/${files.length}): ${files[i].name}...`;
    await fetch('/' + TOKEN + '/api/upload?name=' + encodeURIComponent(files[i].name), {
      method: 'POST',
      body: files[i]
    });
  }
  lbl.textContent = 'Выбрать файлы или фото';
  showToast('Файлы сохранены на ПК ✓');
  loadItems(true);
}
function copyTxt(str) {
  navigator.clipboard.writeText(str);
  showToast('Скопировано ✓');
}
async function loadItems(force) {
  try {
    const r = await fetch('/' + TOKEN + '/api/state');
    const d = await r.json();
    const sig = JSON.stringify(d.items || []);
    if (!force && sig === lastSig) return;
    lastSig = sig;
    const box = document.getElementById('itemsBox');
    if (!d.items || !d.items.length) {
      box.innerHTML = '<div style="color:#666;font-size:13px;">Пока пусто</div>';
      return;
    }
    box.innerHTML = d.items.map(it => {
      const dir = it.dir === 'pc2phone' ? 'ПК → Телефон' : 'Телефон → ПК';
      if (it.kind === 'file') {
        return `<div class="item"><div class="item-body"><div class="item-tag">${dir} • ${it.time} • ${it.size || ''}</div><div class="item-txt">${it.label}</div></div><a class="btn btn-sec" href="/${TOKEN}/download/${it.id}" download>Скачать</a></div>`;
      } else {
        const safe = it.label.replace(/'/g, "\\'").replace(/\\n/g, " ");
        return `<div class="item"><div class="item-body"><div class="item-tag">${dir} • ${it.time}</div><div class="item-txt">${it.label}</div></div><button class="btn btn-sec" onclick="copyTxt('${safe}')">Копировать</button></div>`;
      }
    }).join('');
  } catch (e) {}
}
loadItems(true);
setInterval(() => loadItems(false), 2000);
</script>
</body>
</html>
"""

class BridgeHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        st = load_state()
        tok = st.get("token", "")
        path = urllib.parse.unquote(self.path.split("?")[0])
        if path in ("/", f"/{tok}", f"/{tok}/"):
            html = MOBILE_HTML.replace("__TOKEN__", tok).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(html)))
            self.end_headers()
            self.wfile.write(html)
        elif path == f"/{tok}/api/state":
            raw = json.dumps({"items": st.get("items", [])}, ensure_ascii=False).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json; charset=utf-8")
            self.end_headers()
            self.wfile.write(raw)
        elif path.startswith(f"/{tok}/download/"):
            item_id = path.split("/")[-1]
            for it in st.get("items", []):
                if it.get("id") == item_id and it.get("path") and os.path.exists(it["path"]):
                    fp = it["path"]
                    fn = os.path.basename(fp)
                    self.send_response(200)
                    self.send_header("Content-Type", "application/octet-stream")
                    self.send_header("Content-Length", str(os.path.getsize(fp)))
                    self.send_header("Content-Disposition", f'attachment; filename="{urllib.parse.quote(fn)}"')
                    self.end_headers()
                    with open(fp, "rb") as f:
                        shutil.copyfileobj(f, self.wfile)
                    return
            self.send_response(404)
            self.end_headers()
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        st = load_state()
        tok = st.get("token", "")
        parsed = urllib.parse.urlparse(self.path)
        path = urllib.parse.unquote(parsed.path)
        qs = urllib.parse.parse_qs(parsed.query)
        now_str = time.strftime("%H:%M:%S")
        length = int(self.headers.get("Content-Length", 0))

        if path == f"/{tok}/api/text":
            txt = self.rfile.read(length).decode("utf-8", errors="ignore").strip()
            if txt:
                try:
                    p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
                    p.communicate(txt.encode("utf-8"))
                except Exception:
                    pass
                subprocess.Popen(["notify-send", "-a", "HySett", "Текст с телефона скопирован", txt[:120]])
                items = st.get("items", [])
                items.insert(0, {
                    "id": uuid.uuid4().hex[:8],
                    "kind": "text",
                    "dir": "phone2pc",
                    "label": txt,
                    "path": "",
                    "size": "",
                    "time": now_str
                })
                st["items"] = items[:40]
                save_state(st)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        elif path == f"/{tok}/api/upload":
            raw_name = (qs.get("name", ["file.bin"])[0] or "file.bin")
            safe_name = os.path.basename(urllib.parse.unquote(raw_name)) or "file.bin"
            dst = os.path.join(DOWNLOAD_DIR, safe_name)
            if os.path.exists(dst):
                base, ext = os.path.splitext(safe_name)
                dst = os.path.join(DOWNLOAD_DIR, f"{base}_{int(time.time())}{ext}")
            remaining = length
            with open(dst, "wb") as wf:
                while remaining > 0:
                    chunk = self.rfile.read(min(65536, remaining))
                    if not chunk:
                        break
                    wf.write(chunk)
                    remaining -= len(chunk)
            sz_mb = os.path.getsize(dst) / (1024.0 * 1024.0)
            sz_str = f"{sz_mb:.1f} MB" if sz_mb >= 1.0 else f"{max(1, int(os.path.getsize(dst)/1024))} KB"
            subprocess.Popen(["notify-send", "-a", "HySett", "Получен файл с телефона", f"{os.path.basename(dst)} ({sz_str})"])
            items = st.get("items", [])
            items.insert(0, {
                "id": uuid.uuid4().hex[:8],
                "kind": "file",
                "dir": "phone2pc",
                "label": os.path.basename(dst),
                "path": dst,
                "size": sz_str,
                "time": now_str
            })
            st["items"] = items[:40]
            save_state(st)
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
        else:
            self.send_response(404)
            self.end_headers()

def run_daemon():
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))
    sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    sock.bind(("0.0.0.0", 0))
    port = sock.getsockname()[1]
    sock.close()

    st = load_state()
    tok = st.get("token") or uuid.uuid4().hex[:10]
    lan_url = f"http://{get_lan_ip()}:{port}/{tok}"
    qr_init = generate_qr(lan_url)

    st["running"] = True
    st["port"] = port
    st["token"] = tok
    st["url"] = lan_url
    st["qr_path"] = qr_init
    st["status"] = "Подключение интернет-туннеля..."
    save_state(st)

    srv = ThreadingHTTPServer(("0.0.0.0", port), BridgeHandler)
    t = threading.Thread(target=srv.serve_forever, daemon=True)
    t.start()

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
                        bound_url = f"{m.group(1)}/{tok}"
                        qr_p = generate_qr(bound_url)
                        st = load_state()
                        st["running"] = True
                        st["url"] = bound_url
                        st["qr_path"] = qr_p
                        st["status"] = "Мост активен ✓ Отсканируйте QR-код"
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

def cmd_start():
    ensure_started()
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
    subprocess.run(["pkill", "-f", "nokey@localhost.run"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-f", "a.pinggy.io"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["pkill", "-f", "serveo.net"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    st = load_state()
    st["running"] = False
    st["url"] = ""
    st["status"] = "Мост выключен"
    save_state(st)
    cmd_status()

def cmd_add_text(txt):
    txt = (txt or "").strip()
    if not txt:
        cmd_status()
        return
    ensure_started()
    st = load_state()
    items = st.get("items", [])
    items.insert(0, {
        "id": uuid.uuid4().hex[:8],
        "kind": "text",
        "dir": "pc2phone",
        "label": txt,
        "path": "",
        "size": "",
        "time": time.strftime("%H:%M:%S")
    })
    st["items"] = items[:40]
    st["status"] = "Текст отправлен в ленту ✓"
    save_state(st)
    cmd_status()

def cmd_add_file(fp):
    fp = os.path.expanduser((fp or "").strip())
    if not fp or not os.path.exists(fp) or not os.path.isfile(fp):
        st = load_state()
        st["status"] = f"Файл не найден: {fp}"
        save_state(st)
        cmd_status()
        return
    ensure_started()
    sz_mb = os.path.getsize(fp) / (1024.0 * 1024.0)
    sz_str = f"{sz_mb:.1f} MB" if sz_mb >= 1.0 else f"{max(1, int(os.path.getsize(fp)/1024))} KB"
    st = load_state()
    items = st.get("items", [])
    items.insert(0, {
        "id": uuid.uuid4().hex[:8],
        "kind": "file",
        "dir": "pc2phone",
        "label": os.path.basename(fp),
        "path": fp,
        "size": sz_str,
        "time": time.strftime("%H:%M:%S")
    })
    st["items"] = items[:40]
    st["status"] = f"Файл «{os.path.basename(fp)}» готов к скачиванию ✓"
    save_state(st)
    cmd_status()

def cmd_quick_cloud(target, is_file):
    st = load_state()
    st["status"] = "Загрузка в облако..."
    save_state(st)
    tmp_txt = None
    upload_path = os.path.expanduser(target.strip())
    if not is_file:
        tmp_txt = "/tmp/hysett_quick_note.txt"
        with open(tmp_txt, "w", encoding="utf-8") as f:
            f.write(target)
        upload_path = tmp_txt
    elif not os.path.exists(upload_path):
        st = load_state()
        st["status"] = f"Файл не найден: {upload_path}"
        save_state(st)
        cmd_status()
        return

    link = ""
    for cmd in [
        ["curl", "-s", "-S", "-m", "25", "-A", "HySett/1.0", "-F", f"file=@{upload_path}", "https://0x0.st"],
        ["curl", "-s", "-S", "-m", "30", "-F", "reqtype=fileupload", "-F", "time=24h", "-F", f"fileToUpload=@{upload_path}", "https://litterbox.catbox.moe/resources/internals/api.php"]
    ]:
        try:
            out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
            if out.startswith("http"):
                link = out.splitlines()[-1].strip()
                break
        except Exception:
            pass

    if tmp_txt and os.path.exists(tmp_txt):
        os.remove(tmp_txt)

    if link:
        try:
            p = subprocess.Popen(["wl-copy"], stdin=subprocess.PIPE)
            p.communicate(link.encode("utf-8"))
        except Exception:
            pass
        qr_p = generate_qr(link)
        st = load_state()
        st["url"] = link
        st["qr_path"] = qr_p
        st["status"] = f"Ссылка скопирована: {link} ✓"
        save_state(st)
    else:
        st = load_state()
        st["status"] = "Ошибка выгрузки в облако"
        save_state(st)
    cmd_status()

def cmd_scrcpy(mode, ip_addr, mouse_mode, turn_off):
    st = load_state()
    if mode == "stop":
        subprocess.run(["pkill", "-x", "scrcpy"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        st["scrcpy_running"] = False
        st["status"] = "Экран телефона закрыт"
        save_state(st)
        cmd_status()
        return

    if mode == "power_key":
        subprocess.run(["adb", "shell", "input", "keyevent", "26"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["adb", "shell", "input", "keyevent", "82"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        st["status"] = "Команда питания отправлена на телефон ✓"
        save_state(st)
        cmd_status()
        return

    if not shutil.which("scrcpy"):
        subprocess.Popen(["kitty", "--title", "Установка scrcpy", "-e", "bash", "-c", "sudo pacman -S --needed --noconfirm scrcpy android-tools; read -p 'Готово! Нажмите Enter...'"])
        st["status"] = "Установка пакета scrcpy..."
        save_state(st)
        cmd_status()
        return

    if mode == "tcpip_init":
        subprocess.run(["adb", "tcpip", "5555"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        detected_ip = ""
        for dev in ("rndis0", "usb0", "ncm0", "wlan0"):
            try:
                out = subprocess.check_output(["adb", "shell", "ip", "-f", "inet", "addr", "show", dev], stderr=subprocess.DEVNULL).decode()
                m = re.search(r"inet\s+(\d+\.\d+\.\d+\.\d+)", out)
                if m:
                    detected_ip = m.group(1)
                    break
            except Exception:
                pass
        if not detected_ip:
            try:
                rout = subprocess.check_output(["ip", "route"], stderr=subprocess.DEVNULL).decode()
                for ln in rout.splitlines():
                    if ln.startswith("default via ") and any(k in ln for k in ("usb", "rndis", "enp0s29")):
                        detected_ip = ln.split()[2].strip()
                        break
            except Exception:
                pass
        if detected_ip:
            st["phone_ip"] = detected_ip
            st["status"] = f"Порт 5555 открыт ({detected_ip}) ✓"
        else:
            st["status"] = "Порт 5555 открыт ✓"
        save_state(st)
        cmd_status()
        return

    # Всегда перезапускаем scrcpy при новом вызове, чтобы применились свежие настройки
    subprocess.run(["pkill", "-x", "scrcpy"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(0.15)

    # Пробуем разблокировать разрешение ввода через ADB (если доступно)
    subprocess.run(["adb", "shell", "settings", "put", "secure", "usb_debug_sec", "1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    mip_so = os.path.expanduser("~/hysett/bin/libscrcpy_mipmap.so")
    if os.path.exists(mip_so):
        os.environ["LD_PRELOAD"] = mip_so
    args = ["scrcpy", "--max-fps=120", "--max-size=1600", "--video-bit-rate=12M", "--hwdec=disabled", "--render-driver=opengl", "--stay-awake"]
    if mouse_mode == "1":
        args.extend(["--mouse=uhid", "--keyboard=uhid"])
    elif mouse_mode == "2":
        args.extend(["--mouse=aoa", "--keyboard=aoa"])
    else:
        args.extend(["--mouse=sdk", "--keyboard=sdk"])

    # --turn-screen-off совместим только с sdk
    if turn_off == "1" and mouse_mode == "0":
        args.append("--turn-screen-off")

    if mode == "wireless" and ip_addr.strip():
        target = ip_addr.strip()
        if ":" not in target:
            target += ":5555"
        st["phone_ip"] = ip_addr.strip()
        subprocess.run(["adb", "connect", target], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5)
        args.extend(["-s", target])
        st["status"] = f"Экран телефона запущен (120 FPS • {target})"
    else:
        args.append("-d")
        st["status"] = "Экран телефона запущен по USB (120 FPS)"

    log_f = open(SCRCPY_LOG, "w")
    subprocess.Popen(args, stdin=subprocess.DEVNULL, stdout=log_f, stderr=subprocess.STDOUT, start_new_session=True)
    time.sleep(0.45)

    if not is_scrcpy_alive() and mouse_mode != "0":
        # Фолбэк на SDK, если ядро телефона не поддерживает UHID/AOA
        fallback_args = ["scrcpy", "--max-fps=120", "--max-size=1600", "--video-bit-rate=12M", "--hwdec=disabled", "--render-driver=opengl", "--stay-awake", "-d"] if mode != "wireless" else ["scrcpy", "--max-fps=120", "--max-size=1600", "--video-bit-rate=12M", "--hwdec=disabled", "--render-driver=opengl", "--stay-awake", "-s", (ip_addr.strip() if ":" in ip_addr else ip_addr.strip() + ":5555")]
        if turn_off == "1":
            fallback_args.append("--turn-screen-off")
        subprocess.Popen(fallback_args, stdin=subprocess.DEVNULL, stdout=log_f, stderr=subprocess.STDOUT, start_new_session=True)
        time.sleep(0.35)
        st["status"] = "Запущен режим SDK (120 FPS). Для кликов на Xiaomi включите «Отладка по USB (Настройки безопасности)»"

    save_state(st)
    cmd_status()

def cmd_status():
    st = load_state()
    alive = is_daemon_alive()
    if st.get("running") != alive:
        st["running"] = alive
    st["scrcpy_running"] = is_scrcpy_alive()
    save_state(st)
    print(json.dumps(st, ensure_ascii=False))

if __name__ == "__main__":
    c = sys.argv[1] if len(sys.argv) > 1 else "status"
    if c == "_daemon":
        run_daemon()
    elif c == "start":
        cmd_start()
    elif c == "stop":
        cmd_stop()
    elif c == "add_text":
        cmd_add_text(sys.argv[2] if len(sys.argv) > 2 else "")
    elif c == "add_file":
        cmd_add_file(sys.argv[2] if len(sys.argv) > 2 else "")
    elif c == "quick_cloud":
        cmd_quick_cloud(sys.argv[2] if len(sys.argv) > 2 else "", (sys.argv[3] == "1") if len(sys.argv) > 3 else False)
    elif c == "scrcpy":
        mode = sys.argv[2] if len(sys.argv) > 2 else "usb"
        ip_a = sys.argv[3] if len(sys.argv) > 3 else ""
        m_mode = sys.argv[4] if len(sys.argv) > 4 else "0"
        toff = sys.argv[5] if len(sys.argv) > 5 else "0"
        cmd_scrcpy(mode, ip_a, m_mode, toff)
    elif c == "clear":
        st = load_state()
        st["items"] = []
        save_state(st)
        cmd_status()
    else:
        cmd_status()
