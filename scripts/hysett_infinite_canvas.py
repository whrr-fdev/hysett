#!/usr/bin/env python3
import sys
import os
import glob
import struct
import select
import signal
import socket
import json
import time
import subprocess

EVENT_SIZE = struct.calcsize("llHHi")
EV_KEY = 1
EV_REL = 2
REL_X = 0
REL_Y = 1

KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
BTN_LEFT = 272
BTN_MIDDLE = 274

PANLOCK_FILE = "/tmp/hysett_canvas_panlock"
PID_FILE = "/tmp/hysett_canvas_evdev.pid"
CONF_FILE = os.path.expanduser("~/.config/hypr/canvas.json")
HYPR_LUA = os.path.expanduser("~/.config/hypr/hyprland.lua")


def get_hypr_sock_path(sock_name=".socket.sock"):
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
    if sig:
        p = os.path.join(xdg, "hypr", sig, sock_name)
        if os.path.exists(p):
            return p
    hypr_dir = os.path.join(xdg, "hypr")
    if os.path.isdir(hypr_dir):
        candidates = []
        for d in os.listdir(hypr_dir):
            p = os.path.join(hypr_dir, d, sock_name)
            if os.path.exists(p):
                try:
                    candidates.append((os.path.getmtime(p), p))
                except Exception:
                    pass
        if candidates:
            candidates.sort(reverse=True)
            return candidates[0][1]
    return None


CMD_SOCK_PATH = get_hypr_sock_path(".socket.sock")


def repl_lua(code):
    global CMD_SOCK_PATH
    if not CMD_SOCK_PATH or not os.path.exists(CMD_SOCK_PATH):
        CMD_SOCK_PATH = get_hypr_sock_path(".socket.sock")
    if CMD_SOCK_PATH:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.settimeout(0.08)
                s.connect(CMD_SOCK_PATH)
                s.sendall(f"repl {code}".encode("utf-8"))
                s.recv(128)
                return
        except Exception:
            CMD_SOCK_PATH = None
    subprocess.Popen(
        ["hyprctl", "repl", code],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


def switch_hyprland_binds(canvas_on):
    if not os.path.exists(HYPR_LUA):
        return
    try:
        with open(HYPR_LUA, "r", encoding="utf-8") as f:
            lines = f.readlines()

        new_lines = []
        for ln in lines:
            if "-- [NORMAL_BIND]" in ln:
                clean = ln.lstrip()
                if clean.startswith("--"):
                    clean = clean.lstrip("- ").lstrip()
                if canvas_on:
                    new_lines.append("-- " + clean)
                else:
                    new_lines.append(clean)
            elif "-- [CANVAS_BIND]" in ln:
                clean = ln.lstrip()
                if clean.startswith("--"):
                    clean = clean.lstrip("- ").lstrip()
                if canvas_on:
                    new_lines.append(clean)
                else:
                    new_lines.append("-- " + clean)
            else:
                new_lines.append(ln)

        with open(HYPR_LUA, "w", encoding="utf-8") as f:
            f.writelines(new_lines)

        subprocess.run(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def stop_existing():
    my_pid = os.getpid()
    if os.path.exists(PID_FILE):
        try:
            with open(PID_FILE, "r") as f:
                old_pid = int(f.read().strip())
            if old_pid != my_pid:
                os.kill(old_pid, signal.SIGTERM)
        except Exception:
            pass
        try:
            os.remove(PID_FILE)
        except Exception:
            pass

    for proc_dir in glob.glob("/proc/[0-9]*"):
        try:
            pid = int(os.path.basename(proc_dir))
            if pid == my_pid:
                continue
            with open(f"{proc_dir}/cmdline", "rb") as f:
                cmd = f.read().decode("utf-8", errors="ignore")
            if "hysett_infinite_canvas.py" in cmd and ("start_evdev" in cmd or "_daemon" in cmd):
                os.kill(pid, signal.SIGTERM)
        except Exception:
            pass


def connect_hypr_event_sock():
    sock_path = get_hypr_sock_path(".socket2.sock")
    if not sock_path:
        return None
    try:
        s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        s.connect(sock_path)
        s.setblocking(False)
        return s
    except Exception:
        return None


def start_evdev_listener():
    stop_existing()
    try:
        with open(PID_FILE, "w") as f:
            f.write(str(os.getpid()))
    except Exception:
        pass

    fds = []
    for dev in sorted(glob.glob("/dev/input/event*")):
        try:
            if os.access(dev, os.R_OK):
                fd = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
                fds.append(fd)
        except Exception:
            pass

    hypr_sock = connect_hypr_event_sock()
    sock_buf = ""
    pending_new_wins = []

    super_down = False
    lmb_down = False
    mmb_down = False
    acc_x = 0.0
    acc_y = 0.0
    last_flush = time.monotonic()
    panlock_cached = False
    last_panlock_check = 0.0

    while True:
        if hypr_sock is None:
            hypr_sock = connect_hypr_event_sock()

        wait_list = list(fds)
        if hypr_sock is not None:
            wait_list.append(hypr_sock)

        try:
            rlist, _, _ = select.select(wait_list, [], [], 0.008)
        except Exception:
            break

        now = time.monotonic()
        if now - last_panlock_check > 0.04:
            panlock_cached = os.path.exists(PANLOCK_FILE)
            last_panlock_check = now

        for item in rlist:
            if hypr_sock is not None and item is hypr_sock:
                try:
                    chunk = hypr_sock.recv(4096).decode("utf-8", errors="ignore")
                    if not chunk:
                        hypr_sock.close()
                        hypr_sock = None
                    else:
                        sock_buf += chunk
                        while "\n" in sock_buf:
                            line, sock_buf = sock_buf.split("\n", 1)
                            if line.startswith("openwindow>>"):
                                payload = line.split(">>", 1)[1]
                                addr = payload.split(",", 1)[0].strip()
                                if addr:
                                    if not addr.startswith("0x"):
                                        addr = "0x" + addr
                                    pending_new_wins.append((now + 0.05, addr))
                except Exception:
                    pass
                continue

            fd = item
            try:
                raw = os.read(fd, EVENT_SIZE * 64)
            except Exception:
                continue
            if not raw:
                continue

            for off in range(0, len(raw) - EVENT_SIZE + 1, EVENT_SIZE):
                _, _, etype, code, val = struct.unpack("llHHi", raw[off:off + EVENT_SIZE])
                if etype == EV_KEY and val != 2:
                    pressed = (val == 1)
                    if code in (KEY_LEFTMETA, KEY_RIGHTMETA):
                        super_down = pressed
                    elif code == BTN_LEFT:
                        lmb_down = pressed
                    elif code == BTN_MIDDLE:
                        mmb_down = pressed
                elif etype == EV_REL:
                    # В режиме Холста: просто Super + ЛКМ (или Super + СКМ, или panlock) двигает весь холст!
                    is_canvas_drag = (super_down and (lmb_down or mmb_down)) or panlock_cached
                    if is_canvas_drag:
                        if code == REL_X:
                            acc_x += val
                        elif code == REL_Y:
                            acc_y += val

        if pending_new_wins:
            still_waiting = []
            for due_t, addr in pending_new_wins:
                if now >= due_t:
                    repl_lua(f"if _G.Canvas then _G.Canvas.on_window_open('{addr}') end")
                else:
                    still_waiting.append((due_t, addr))
            pending_new_wins = still_waiting

        if now - last_flush >= 0.008:
            last_flush = now
            dx = int(round(acc_x))
            dy = int(round(acc_y))
            acc_x -= dx
            acc_y -= dy
            if dx != 0 or dy != 0:
                repl_lua(f"if _G.Canvas then _G.Canvas.pan_delta({dx}, {dy}) end")


def update_setting(key, val_str):
    cfg = {}
    if os.path.exists(CONF_FILE):
        try:
            with open(CONF_FILE, "r") as f:
                cfg = json.load(f)
        except Exception:
            cfg = {}

    if val_str in ("true", "false"):
        val = (val_str == "true")
        lua_val = "true" if val else "false"
    else:
        try:
            if "." in val_str:
                val = float(val_str)
            else:
                val = int(val_str)
            lua_val = str(val)
        except Exception:
            val = val_str
            lua_val = f"'{val_str}'"

    cfg[key] = val
    os.makedirs(os.path.dirname(CONF_FILE), exist_ok=True)
    with open(CONF_FILE, "w") as f:
        json.dump(cfg, f, indent=2)

    repl_lua(f"if _G.Canvas then _G.Canvas.set_option('{key}', {lua_val}) end")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if cmd in ("start_evdev", "_daemon"):
        start_evdev_listener()
    elif cmd == "stop_evdev":
        stop_existing()
    elif cmd == "enable_binds_and_daemon":
        switch_hyprland_binds(True)
        start_evdev_listener()
    elif cmd == "disable_binds_and_stop":
        switch_hyprland_binds(False)
        stop_existing()
    elif cmd == "toggle":
        repl_lua("if _G.Canvas then _G.Canvas.toggle() end")
    elif cmd == "next":
        repl_lua("if _G.Canvas then _G.Canvas.focus_cycle('next') end")
    elif cmd == "prev":
        repl_lua("if _G.Canvas then _G.Canvas.focus_cycle('prev') end")
    elif cmd == "home":
        repl_lua("if _G.Canvas then _G.Canvas.gather_home() end")
    elif cmd == "invert":
        repl_lua("if _G.Canvas then _G.Canvas.toggle_invert() end")
    elif cmd == "panlock":
        repl_lua("if _G.Canvas then _G.Canvas.toggle_pan_lock() end")
    elif cmd == "nav" and len(sys.argv) > 2:
        repl_lua(f"if _G.Canvas then _G.Canvas.navigate('{sys.argv[2]}') end")
    elif cmd == "set" and len(sys.argv) > 3:
        update_setting(sys.argv[2], sys.argv[3])
