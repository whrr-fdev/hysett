#!/usr/bin/env python3
import os, socket, subprocess, json, time

TRIGGERS = ("fullscreen>>", "workspace", "focusedmon", "closewindow>>", "openwindow>>", "movewindow>>")

def sync_mpvpaper():
    try:
        ws = json.loads(subprocess.check_output(["hyprctl", "activeworkspace", "-j"], text=True))
        pause = bool(ws.get("hasfullscreen", False))
        if pause:
            win = json.loads(subprocess.check_output(["hyprctl", "activewindow", "-j"], text=True))
            if win.get("class") == "com.whrr.HyprSettings":
                pause = False
        subprocess.run(["pkill", "-STOP" if pause else "-CONT", "-x", "mpvpaper"])
    except Exception:
        pass

def main():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    xdg = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    sock_path = f"{xdg}/hypr/{sig}/.socket2.sock"
    if not os.path.exists(sock_path):
        sock_path = f"/tmp/hypr/{sig}/.socket2.sock"

    sync_mpvpaper()
    while True:
        try:
            with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as s:
                s.connect(sock_path)
                buf = ""
                while True:
                    chunk = s.recv(4096).decode("utf-8", errors="ignore")
                    if not chunk:
                        break
                    buf += chunk
                    lines = buf.split("\n")
                    buf = lines.pop()
                    if any(line.startswith("monitoradded>>") for line in lines):
                        subprocess.Popen([os.path.expanduser("~/.config/hypr/scripts/resume_restore.sh")])
                    if any(line.startswith(TRIGGERS) for line in lines):
                        sync_mpvpaper()
        except Exception:
            time.sleep(1.0)

if __name__ == "__main__":
    main()
