#!/usr/bin/env python3
import sys, os, glob, struct, select, subprocess

EVENT_SIZE = struct.calcsize("llHHi")
EV_KEY = 1
KEY_LEFTMETA = 125
KEY_RIGHTMETA = 126
KEY_LEFTALT = 56
KEY_RIGHTALT = 100
BTN_LEFT = 272
BTN_MIDDLE = 274

def eval_lua(code):
    subprocess.run(["hyprctl", "eval", code], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def start_evdev_listener():
    fds = []
    for dev in sorted(glob.glob("/dev/input/event*")):
        try:
            f = os.open(dev, os.O_RDONLY | os.O_NONBLOCK)
            fds.append(f)
        except Exception:
            pass
    if not fds:
        return

    super_down = False
    alt_down = False
    lmb_down = False
    was_panning = False

    while True:
        try:
            rlist, _, _ = select.select(fds, [], [], 0.2)
        except Exception:
            break
        for fd in rlist:
            try:
                raw = os.read(fd, EVENT_SIZE * 16)
            except Exception:
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

                    now_pan = super_down and alt_down and lmb_down
                    if now_pan != was_panning:
                        was_panning = now_pan
                        eval_lua(f"if _G.Canvas then _G.Canvas.set_panning({'true' if now_pan else 'false'}) end")

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "toggle"
    if cmd == "toggle":
        eval_lua("if _G.Canvas then _G.Canvas.toggle() end")
    elif cmd == "start_evdev":
        start_evdev_listener()
    elif cmd == "next":
        eval_lua("if _G.Canvas then _G.Canvas.focus_cycle('next') end")
    elif cmd == "prev":
        eval_lua("if _G.Canvas then _G.Canvas.focus_cycle('prev') end")
    elif cmd == "home":
        eval_lua("if _G.Canvas then _G.Canvas.gather_home() end")
    elif cmd == "invert":
        eval_lua("if _G.Canvas then _G.Canvas.toggle_invert() end")
    elif cmd == "zoom_in":
        eval_lua("if _G.Canvas then _G.Canvas.zoom(1.15) end")
    elif cmd == "zoom_out":
        eval_lua("if _G.Canvas then _G.Canvas.zoom(0.86) end")
