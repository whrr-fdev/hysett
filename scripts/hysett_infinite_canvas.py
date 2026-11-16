#!/usr/bin/env python3
import sys
import os
import json
import time
import glob
import math
import socket
import struct
import select
import signal
import subprocess
import threading

STATE_FILE = "/tmp/hysett_infinite_canvas_state.json"
PID_FILE = "/tmp/hysett_infinite_canvas.pid"
CMD_SOCK = "/tmp/hysett_infinite_canvas.sock"

EVENT_SIZE = struct.calcsize("llHHi")
EV_KEY = 1
EV_REL = 2
REL_X = 0
REL_Y = 1

KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
KEY_LEFTALT = 56
KEY_RIGHTALT = 100
KEY_LEFTCTRL = 29
KEY_RIGHTCTRL = 97
KEY_LEFT = 105
KEY_RIGHT = 106
BTN_LEFT = 272
BTN_MIDDLE = 274

IGNORED_CLASSES = {
    "hypratmooverlay",
    "hysett",
    "waybar",
    "mako",
}

PROTECTED_FOCUS_APPS = (
    "hypratmooverlay",
)


def get_hypr_socket_path():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    if sig:
        p1 = os.path.join(xdg, "hypr", sig, ".socket.sock")
        if os.path.exists(p1):
            return p1
        p2 = f"/tmp/hypr/{sig}/.socket.sock"
        if os.path.exists(p2):
            return p2
    for base in (os.path.join(xdg, "hypr"), "/tmp/hypr"):
        if os.path.exists(base):
            for d in os.listdir(base):
                cand = os.path.join(base, d, ".socket.sock")
                if os.path.exists(cand):
                    return cand
    return ""


HYPR_SOCK = get_hypr_socket_path()


def hypr_req(cmd_str):
    if not HYPR_SOCK:
        return ""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
            s.settimeout(0.25)
            s.connect(HYPR_SOCK)
            s.sendall(cmd_str.encode("utf-8"))
            chunks = []
            while True:
                data = s.recv(65536)
                if not data:
                    break
                chunks.append(data)
            return b"".join(chunks).decode("utf-8", errors="ignore")
    except Exception:
        return ""


def hypr_json(subcmd):
    raw = hypr_req(f"j/{subcmd}")
    if not raw:
        return None
    try:
        return json.loads(raw)
    except Exception:
        return None


def hypr_batch(commands):
    if not commands:
        return
    batch_str = "[[BATCH]]" + ";".join(commands)
    hypr_req(batch_str)


def notify(title, body):
    subprocess.Popen(
        ["notify-send", "-a", "HySett Canvas", title, body],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def load_state():
    st = {
        "enabled": False,
        "inverted": False,
        "speed": 1.45,
        "saved_tiled": {},
    }
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, "r", encoding="utf-8") as f:
                st.update(json.load(f))
        except Exception:
            pass
    return st


def save_state(st):
    try:
        tmp = STATE_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(st, f, ensure_ascii=False)
        os.replace(tmp, STATE_FILE)
    except Exception:
        pass


def is_daemon_running():
    if not os.path.exists(PID_FILE):
        return False
    try:
        pid = int(open(PID_FILE, "r").read().strip())
        os.kill(pid, 0)
        return True
    except Exception:
        return False


def get_monitor_geom():
    mons = hypr_json("monitors") or []
    for m in mons:
        if m.get("focused"):
            return (
                int(m.get("x", 0)),
                int(m.get("y", 0)),
                int(m.get("width", 1920)),
                int(m.get("height", 1080)),
            )
    if mons:
        m = mons[0]
        return (
            int(m.get("x", 0)),
            int(m.get("y", 0)),
            int(m.get("width", 1920)),
            int(m.get("height", 1080)),
        )
    return 0, 0, 1920, 1080


def get_active_workspace_id():
    ws = hypr_json("activeworkspace")
    if isinstance(ws, dict):
        return int(ws.get("id", 1))
    return 1


def is_canvas_window(w, ws_id):
    if not isinstance(w, dict):
        return False
    if w.get("workspace", {}).get("id") != ws_id:
        return False
    if w.get("pinned", False):
        return False
    cls = str(w.get("class", "")).lower()
    title = str(w.get("title", ""))
    if cls in IGNORED_CLASSES or title == "HySettAtmosphereOverlay":
        return False
    return True


def get_canvas_windows(ws_id=None):
    if ws_id is None:
        ws_id = get_active_workspace_id()
    clients = hypr_json("clients") or []
    res = []
    for w in clients:
        if is_canvas_window(w, ws_id) and w.get("floating", False):
            res.append(w)
    res.sort(key=lambda x: str(x.get("address", "")))
    return res


def get_cursor_pos():
    raw = hypr_req("cursorpos").strip()
    if "," in raw:
        try:
            px, py = raw.split(",", 1)
            return float(px.strip()), float(py.strip())
        except Exception:
            pass
    return 960.0, 540.0


def convert_workspace_to_canvas():
    ws_id = get_active_workspace_id()
    clients = hypr_json("clients") or []
    mx, my, mw, mh = get_monitor_geom()
    cx, cy = mx + mw // 2, my + mh // 2

    st = load_state()
    saved_tiled = st.get("saved_tiled", {})

    ws_wins = [w for w in clients if is_canvas_window(w, ws_id)]
    tiled_wins = [w for w in ws_wins if not w.get("floating", False)]

    batch = []
    n = len(tiled_wins)
    for idx, w in enumerate(tiled_wins):
        addr = w["address"]
        saved_tiled[addr] = True
        w_w = min(int(mw * 0.58), max(680, int(w.get("size", [900, 620])[0])))
        w_h = min(int(mh * 0.66), max(460, int(w.get("size", [900, 620])[1])))
        offset_x = (idx - (n - 1) / 2.0) * 420
        offset_y = ((idx % 2) - 0.5) * 90 if n > 1 else 0
        tx = int(cx - w_w // 2 + offset_x)
        ty = int(cy - w_h // 2 + offset_y)
        batch.append(f"dispatch setfloating address:{addr}")
        batch.append(f"dispatch resizewindowpixel exact {w_w} {w_h},address:{addr}")
        batch.append(f"dispatch movewindowpixel exact {tx} {ty},address:{addr}")

    if batch:
        hypr_batch(batch)

    st["enabled"] = True
    st["saved_tiled"] = saved_tiled
    save_state(st)


def restore_workspace_from_canvas():
    st = load_state()
    saved_tiled = st.get("saved_tiled", {})
    ws_id = get_active_workspace_id()
    clients = hypr_json("clients") or []
    mx, my, mw, mh = get_monitor_geom()

    batch = []
    for w in clients:
        addr = w.get("address", "")
        if not addr:
            continue
        if addr in saved_tiled and w.get("floating", False):
            batch.append(f"dispatch settiled address:{addr}")
        elif is_canvas_window(w, ws_id) and w.get("floating", False):
            # Вернем плавающие окна в пределы экрана, если они улетели за край холста
            wx, wy = w.get("at", [mx + 100, my + 100])
            ww, wh = w.get("size", [600, 400])
            nx = max(mx + 20, min(mx + mw - ww - 20, wx))
            ny = max(my + 44, min(my + mh - wh - 20, wy))
            batch.append(f"dispatch movewindowpixel exact {int(nx)} {int(ny)},address:{addr}")

    if batch:
        hypr_batch(batch)

    st["enabled"] = False
    st["saved_tiled"] = {}
    save_state(st)


def animate_pan_delta(wins, total_dx, total_dy, duration=0.16):
    if not wins or (abs(total_dx) < 2 and abs(total_dy) < 2):
        return
    starts = [(w["address"], float(w["at"][0]), float(w["at"][1])) for w in wins]
    steps = max(6, int(duration / 0.008))
    t0 = time.perf_counter()
    for step in range(1, steps + 1):
        u = step / float(steps)
        # Cubic ease-out
        ease = 1.0 - pow(1.0 - u, 3)
        batch = []
        for addr, sx, sy in starts:
            nx = int(round(sx + total_dx * ease))
            ny = int(round(sy + total_dy * ease))
            batch.append(f"dispatch movewindowpixel exact {nx} {ny},address:{addr}")
        hypr_batch(batch)
        target_t = t0 + step * (duration / steps)
        rem = target_t - time.perf_counter()
        if rem > 0:
            time.sleep(rem)


def focus_cycle(direction):
    ws_id = get_active_workspace_id()
    wins = get_canvas_windows(ws_id)
    if not wins:
        return
    mx, my, mw, mh = get_monitor_geom()
    cx, cy = mx + mw // 2, my + mh // 2

    active = hypr_json("activewindow") or {}
    cur_addr = active.get("address", "")

    cur_idx = -1
    for i, w in enumerate(wins):
        if w.get("address") == cur_addr:
            cur_idx = i
            break

    if cur_idx == -1:
        target = wins[0]
    else:
        step = 1 if direction == "next" else -1
        target = wins[(cur_idx + step) % len(wins)]

    tx = target["at"][0] + target["size"][0] // 2
    ty = target["at"][1] + target["size"][1] // 2
    dx = cx - tx
    dy = cy - ty

    animate_pan_delta(wins, dx, dy, duration=0.16)
    t_addr = target["address"]
    hypr_batch([
        f"dispatch focuswindow address:{t_addr}",
        f"dispatch alterzorder top,address:{t_addr}",
    ])


def arrange_home_grid():
    ws_id = get_active_workspace_id()
    wins = get_canvas_windows(ws_id)
    if not wins:
        return
    mx, my, mw, mh = get_monitor_geom()
    n = len(wins)
    cols = math.ceil(math.sqrt(n))
    rows = math.ceil(n / float(cols))

    pad_x, pad_y = 36, 52
    avail_w = mw - pad_x * 2
    avail_h = mh - pad_y - 36
    cell_w = avail_w // cols
    cell_h = avail_h // rows

    batch = []
    for i, w in enumerate(wins):
        r = i // cols
        c = i % cols
        addr = w["address"]
        ww, wh = w.get("size", [700, 500])
        tx = mx + pad_x + c * cell_w + (cell_w - ww) // 2
        ty = my + pad_y + r * cell_h + (cell_h - wh) // 2
        batch.append(f"dispatch movewindowpixel exact {int(tx)} {int(ty)},address:{addr}")
    hypr_batch(batch)
    notify("Бесконечный холст", "Все окна собраны в центр экрана ✓")


def zoom_canvas(factor):
    ws_id = get_active_workspace_id()
    wins = get_canvas_windows(ws_id)
    if not wins:
        return
    mx, my, mw, mh = get_monitor_geom()
    cx, cy = mx + mw / 2.0, my + mh / 2.0

    batch = []
    for w in wins:
        addr = w["address"]
        wx, wy = float(w["at"][0]), float(w["at"][1])
        ww, wh = float(w["size"][0]), float(w["size"][1])
        wcx = wx + ww / 2.0
        wcy = wy + wh / 2.0

        nw = max(280, min(int(mw * 0.92), int(round(ww * factor))))
        nh = max(200, min(int(mh * 0.90), int(round(wh * factor))))
        ncx = cx + (wcx - cx) * factor
        ncy = cy + (wcy - cy) * factor
        nx = int(round(ncx - nw / 2.0))
        ny = int(round(ncy - nh / 2.0))

        batch.append(f"dispatch resizewindowpixel exact {nw} {nh},address:{addr}")
        batch.append(f"dispatch movewindowpixel exact {nx} {ny},address:{addr}")
    hypr_batch(batch)


def discover_input_devices():
    kbds, mice = [], []
    for dev in sorted(glob.glob("/dev/input/event*")):
        base = os.path.basename(dev)
        try:
            ev_cap = int(open(f"/sys/class/input/{base}/device/capabilities/ev").read().strip(), 16)
            rel_path = f"/sys/class/input/{base}/device/capabilities/rel"
            rel_cap = int(open(rel_path).read().strip(), 16) if os.path.exists(rel_path) else 0
            if (rel_cap & 0x3) == 0x3:
                mice.append(dev)
            elif ev_cap & 0x2:
                kbds.append(dev)
        except Exception:
            continue
    return kbds, mice


def run_daemon():
    with open(PID_FILE, "w") as f:
        f.write(str(os.getpid()))

    if os.path.exists(CMD_SOCK):
        try:
            os.remove(CMD_SOCK)
        except Exception:
            pass

    srv = socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM)
    srv.bind(CMD_SOCK)
    srv.setblocking(False)

    st = load_state()
    inverted = bool(st.get("inverted", False))
    speed = float(st.get("speed", 1.45))

    lock = threading.Lock()
    state_flags = {
        "super": False,
        "alt": False,
        "ctrl": False,
        "lmb": False,
        "ipc_pan": False,
        "dx": 0.0,
        "dy": 0.0,
        "running": True,
    }

    # Попытка чтения /dev/input/event* (как в оригинальном плагине, но сразу со всех устройств)
    kbds, mice = discover_input_devices()
    fds = []
    fd_kind = {}
    for d in kbds:
        try:
            f = os.open(d, os.O_RDONLY | os.O_NONBLOCK)
            fds.append(f)
            fd_kind[f] = "kbd"
        except Exception:
            pass
    for d in mice:
        try:
            f = os.open(d, os.O_RDONLY | os.O_NONBLOCK)
            fds.append(f)
            fd_kind[f] = "mouse"
        except Exception:
            pass

    def evdev_worker():
        if not fds:
            return
        last_nav = 0.0
        while state_flags["running"]:
            try:
                rlist, _, _ = select.select(fds, [], [], 0.05)
            except Exception:
                break
            for fd in rlist:
                try:
                    raw = os.read(fd, EVENT_SIZE * 16)
                except Exception:
                    continue
                for offset in range(0, len(raw) - EVENT_SIZE + 1, EVENT_SIZE):
                    _, _, etype, code, val = struct.unpack("llHHi", raw[offset:offset + EVENT_SIZE])
                    if etype == EV_KEY and val != 2:
                        pressed = (val == 1)
                        with lock:
                            if code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                                state_flags["super"] = pressed
                            elif code in (KEY_LEFTALT, KEY_RIGHTALT):
                                state_flags["alt"] = pressed
                            elif code in (KEY_LEFTCTRL, KEY_RIGHTCTRL):
                                state_flags["ctrl"] = pressed
                            elif code in (BTN_LEFT, BTN_MIDDLE):
                                state_flags["lmb"] = pressed
                            if pressed and state_flags["ctrl"] and state_flags["super"] and not state_flags["alt"]:
                                now = time.time()
                                if now - last_nav > 0.18:
                                    if code == KEY_Right if hasattr(sys, "KEY_Right") else code == KEY_RIGHT:
                                        last_nav = now
                                        threading.Thread(target=focus_cycle, args=("next",), daemon=True).start()
                                    elif code == KEY_LEFT:
                                        last_nav = now
                                        threading.Thread(target=focus_cycle, args=("prev",), daemon=True).start()
                    elif etype == EV_REL:
                        with lock:
                            if state_flags["super"] and state_flags["alt"] and state_flags["lmb"] and not state_flags["ipc_pan"]:
                                sgn = -1.0 if inverted else 1.0
                                if code == REL_X:
                                    state_flags["dx"] += val * speed * sgn
                                elif code == REL_Y:
                                    state_flags["dy"] += val * speed * sgn

    if fds:
        threading.Thread(target=evdev_worker, daemon=True).start()

    last_cur_x, last_cur_y = get_cursor_pos()
    cached_wins = []
    cached_ts = 0.0

    def handle_sigterm(*_):
        state_flags["running"] = False

    signal.signal(signal.SIGTERM, handle_sigterm)
    signal.signal(signal.SIGINT, handle_sigterm)

    try:
        while state_flags["running"]:
            # Проверяем команды из сокета
            while True:
                try:
                    msg = srv.recv(1024).decode("utf-8", errors="ignore").strip()
                except BlockingIOError:
                    break
                except Exception:
                    break
                if not msg:
                    break
                if msg == "pan_start":
                    with lock:
                        state_flags["ipc_pan"] = True
                        last_cur_x, last_cur_y = get_cursor_pos()
                        cached_wins = get_canvas_windows()
                        cached_ts = time.perf_counter()
                elif msg == "pan_stop":
                    with lock:
                        state_flags["ipc_pan"] = False
                        state_flags["dx"] = 0.0
                        state_flags["dy"] = 0.0
                elif msg == "invert":
                    inverted = not inverted
                    st = load_state()
                    st["inverted"] = inverted
                    save_state(st)
                    notify("Бесконечный холст", "Направление: " + ("Инвертированное" if inverted else "Обычное"))
                elif msg == "next":
                    threading.Thread(target=focus_cycle, args=("next",), daemon=True).start()
                elif msg == "prev":
                    threading.Thread(target=focus_cycle, args=("prev",), daemon=True).start()
                elif msg == "home":
                    threading.Thread(target=arrange_home_grid, daemon=True).start()
                elif msg == "zoom_in":
                    threading.Thread(target=zoom_canvas, args=(1.12,), daemon=True).start()
                elif msg == "zoom_out":
                    threading.Thread(target=zoom_canvas, args=(0.89,), daemon=True).start()
                elif msg == "stop":
                    state_flags["running"] = False

            now = time.perf_counter()
            with lock:
                ipc_pan = state_flags["ipc_pan"]
                ev_pan = state_flags["super"] and state_flags["alt"] and state_flags["lmb"]
                dx = state_flags["dx"]
                dy = state_flags["dy"]
                state_flags["dx"] = 0.0
                state_flags["dy"] = 0.0

            if ipc_pan:
                cx, cy = get_cursor_pos()
                sgn = -1.0 if inverted else 1.0
                dx = (cx - last_cur_x) * speed * sgn
                dy = (cy - last_cur_y) * speed * sgn
                last_cur_x, last_cur_y = cx, cy

            if ipc_pan or ev_pan:
                idx = int(round(dx))
                idy = int(round(dy))
                if idx != 0 or idy != 0:
                    if not cached_wins or (now - cached_ts) > 0.25:
                        cached_wins = get_canvas_windows()
                        cached_ts = now
                    batch = []
                    for w in cached_wins:
                        w["at"][0] += idx
                        w["at"][1] += idy
                        addr = w["address"]
                        batch.append(f"dispatch movewindowpixel exact {int(w['at'][0])} {int(w['at'][1])},address:{addr}")
                    hypr_batch(batch)
            else:
                cached_wins = []

            time.sleep(0.00625)  # 160 FPS
    finally:
        for fd in fds:
            try:
                os.close(fd)
            except Exception:
                pass
        try:
            srv.close()
        except Exception:
            pass
        for fp in (CMD_SOCK, PID_FILE):
            if os.path.exists(fp):
                try:
                    os.remove(fp)
                except Exception:
                    pass


def send_cmd(cmd_str):
    if not os.path.exists(CMD_SOCK):
        return False
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_DGRAM) as s:
            s.sendto(cmd_str.encode("utf-8"), CMD_SOCK)
        return True
    except Exception:
        return False


def cmd_toggle():
    if is_daemon_running():
        send_cmd("stop")
        time.sleep(0.08)
        if os.path.exists(PID_FILE):
            try:
                os.kill(int(open(PID_FILE).read().strip()), 9)
            except Exception:
                pass
            try:
                os.remove(PID_FILE)
            except Exception:
                pass
        restore_workspace_from_canvas()
        notify("Бесконечный холст ВЫКЛЮЧЕН", "Окна возвращены в обычный режим рабочего стола")
    else:
        convert_workspace_to_canvas()
        subprocess.Popen(
            [sys.executable, __file__, "_daemon"],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        notify(
            "Бесконечный холст ВКЛЮЧЕН",
            "Super+Alt+ЛКМ — двигать холст\nCtrl+Super+←/→ — перелёт между окнами\nSuper+Alt+Колесо — масштаб\nSuper+Alt+C — собрать окна\nSuper+I — выключить",
        )


if __name__ == "__main__":
    action = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if action == "_daemon":
        run_daemon()
    elif action == "toggle":
        cmd_toggle()
    elif action in ("pan_start", "pan_stop", "next", "prev", "home", "invert", "zoom_in", "zoom_out"):
        if not send_cmd(action):
            if action == "next":
                focus_cycle("next")
            elif action == "prev":
                focus_cycle("prev")
            elif action == "home":
                arrange_home_grid()
            elif action == "zoom_in":
                zoom_canvas(1.12)
            elif action == "zoom_out":
                zoom_canvas(0.89)
