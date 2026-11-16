#!/usr/bin/env python3
import sys
import os
import glob
import struct
import select
import signal
import time
import subprocess

EVENT_SIZE = struct.calcsize("llHHi")
EV_KEY = 1
EV_REL = 2
REL_X = 0
REL_Y = 1

KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
KEY_LEFTALT = 56
KEY_RIGHTALT = 100
BTN_LEFT = 272
BTN_MIDDLE = 274

PANLOCK_FILE = "/tmp/hysett_canvas_panlock"
PID_FILE = "/tmp/hysett_canvas_evdev.pid"


def repl_lua(code):
    subprocess.Popen(
        ["hyprctl", "repl", code],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )


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
            pid = int( os.path.basename(proc_dir) )
            if pid == my_pid:
                continue
            with open(f"{proc_dir}/cmdline", "rb") as f:
                cmd = f.read().decode("utf-8", errors="ignore")
            if "hysett_infinite_canvas.py" in cmd and ("start_evdev" in cmd or "_daemon" in cmd):
                os.kill(pid, signal.SIGTERM)
        except Exception:
            pass


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

    if not fds:
        return

    super_down = False
    alt_down = False
    lmb_down = False
    acc_x = 0.0
    acc_y = 0.0
    edge_x = 0.0
    edge_y = 0.0
    last_flush = time.monotonic()
    panlock_cached = False
    last_panlock_check = 0.0

    while True:
        try:
            rlist, _, _ = select.select(fds, [], [], 0.014)
        except Exception:
            break

        now = time.monotonic()
        if now - last_panlock_check > 0.04:
            panlock_cached = os.path.exists(PANLOCK_FILE)
            last_panlock_check = now

        for fd in rlist:
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
                    elif code in (KEY_LEFTALT, KEY_RIGHTALT):
                        alt_down = pressed
                    elif code in (BTN_LEFT, BTN_MIDDLE):
                        lmb_down = pressed
                elif etype == EV_REL:
                    if (super_down and alt_down) or panlock_cached:
                        if code == REL_X:
                            acc_x += val
                        elif code == REL_Y:
                            acc_y += val
                    elif super_down and lmb_down and not alt_down:
                        if code == REL_X:
                            edge_x += val
                        elif code == REL_Y:
                            edge_y += val

        if now - last_flush >= 0.014:
            last_flush = now
            dx = int(round(acc_x))
            dy = int(round(acc_y))
            acc_x -= dx
            acc_y -= dy
            if dx != 0 or dy != 0:
                repl_lua(f"if _G.Canvas then _G.Canvas.pan_delta({dx}, {dy}) end")

            edx = int(round(edge_x))
            edy = int(round(edge_y))
            edge_x = 0.0
            edge_y = 0.0
            if edx != 0 or edy != 0:
                repl_lua(f"if _G.Canvas then _G.Canvas.edge_push({edx}, {edy}) end")


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if cmd in ("start_evdev", "_daemon"):
        start_evdev_listener()
    elif cmd == "stop_evdev":
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
    elif cmd == "zoom_in":
        repl_lua("if _G.Canvas then _G.Canvas.zoom(1.15) end")
    elif cmd == "zoom_out":
        repl_lua("if _G.Canvas then _G.Canvas.zoom(0.86) end")
