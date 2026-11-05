#!/usr/bin/env python3
import ctypes, glob, os, re, select, struct, sys, threading, socket, json, subprocess, signal

HAS_LAYER_SHELL = False
try:
    ctypes.CDLL("libgtk4-layer-shell.so", mode=ctypes.RTLD_GLOBAL)
    import gi
    gi.require_version("Gtk", "4.0")
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk, Gdk, GLib, Gtk4LayerShell
    HAS_LAYER_SHELL = True
except Exception:
    import gi
    gi.require_version("Gtk", "4.0")
    from gi.repository import Gtk, Gdk, GLib

THEME_STATE_FILE = os.path.expanduser("~/.config/hypr/scripts/theme_state.conf")
CELL_SIZE = 21
GAP = 3
KEY_HEIGHT = 18

KEYBOARD_ROWS = [
    [
        ("Esc", "Esc", 1, 1.0), ("F1", "F1", 59, 1.0), ("F2", "F2", 60, 1.0), ("F3", "F3", 61, 1.0),
        ("F4", "F4", 62, 1.0), ("F5", "F5", 63, 1.0), ("F6", "F6", 64, 1.0), ("F7", "F7", 65, 1.0),
        ("F8", "F8", 66, 1.0), ("F9", "F9", 67, 1.0), ("F10", "F10", 68, 1.0), ("F11", "F11", 87, 1.0),
        ("F12", "F12", 88, 1.0), ("Prt", "Prt", 99, 1.0), ("Ins", "Ins", 110, 1.0), ("Del", "Del", 111, 1.0),
    ],
    [
        ("`", "Ё", 41, 1.0), ("1", "1", 2, 1.0), ("2", "2", 3, 1.0), ("3", "3", 4, 1.0),
        ("4", "4", 5, 1.0), ("5", "5", 6, 1.0), ("6", "6", 7, 1.0), ("7", "7", 8, 1.0),
        ("8", "8", 9, 1.0), ("9", "9", 10, 1.0), ("0", "0", 11, 1.0), ("-", "-", 12, 1.0),
        ("=", "=", 13, 1.0), ("Bksp", "Bksp", 14, 2.0), ("Hm", "Hm", 102, 1.0),
    ],
    [
        ("Tab", "Tab", 15, 1.5), ("Q", "Й", 16, 1.0), ("W", "Ц", 17, 1.0), ("E", "У", 18, 1.0),
        ("R", "К", 19, 1.0), ("T", "Е", 20, 1.0), ("Y", "Н", 21, 1.0), ("U", "Г", 22, 1.0),
        ("I", "Ш", 23, 1.0), ("O", "Щ", 24, 1.0), ("P", "З", 25, 1.0), ("[", "Х", 26, 1.0),
        ("]", "Ъ", 27, 1.0), (chr(92), chr(92), 43, 1.5), ("PU", "PU", 104, 1.0),
    ],
    [
        ("Caps", "Caps", 58, 1.75), ("A", "Ф", 30, 1.0), ("S", "Ы", 31, 1.0), ("D", "В", 32, 1.0),
        ("F", "А", 33, 1.0), ("G", "П", 34, 1.0), ("H", "Р", 35, 1.0), ("J", "О", 36, 1.0),
        ("K", "Л", 37, 1.0), ("L", "Д", 38, 1.0), (";", "Ж", 39, 1.0), (chr(39), "Э", 40, 1.0),
        ("Ent", "Ent", 28, 2.25), ("PD", "PD", 109, 1.0),
    ],
    [
        ("Shift", "Shift", 42, 2.25), ("Z", "Я", 44, 1.0), ("X", "Ч", 45, 1.0), ("C", "С", 46, 1.0),
        ("V", "М", 47, 1.0), ("B", "И", 48, 1.0), ("N", "Т", 49, 1.0), ("M", "Ь", 50, 1.0),
        (",", "Б", 51, 1.0), (".", "Ю", 52, 1.0), ("/", ".", 53, 1.0), ("Shift", "Shift", 54, 1.75),
        ("↑", "↑", 103, 1.0), ("End", "End", 107, 1.0),
    ],
    [
        ("Ctrl", "Ctrl", 29, 1.25), ("Sup", "Sup", 125, 1.25), ("Alt", "Alt", 56, 1.25),
        ("Space", "Space", 57, 4.25),
        ("Alt", "Alt", 100, 1.25), ("Fn", "Fn", 464, 1.25), ("Sup", "Sup", 126, 1.25), ("Ctrl", "Ctrl", 97, 1.25),
        ("←", "←", 105, 1.0), ("↓", "↓", 108, 1.0), ("→", "→", 106, 1.0),
    ],
]

def get_key_radius():
    if os.path.exists(THEME_STATE_FILE):
        try:
            with open(THEME_STATE_FILE, "r") as f:
                if f.read().strip() == "square": return "0px"
        except: pass
    return "4px"

def build_css():
    return f"""
    window, .transparent-bg {{ background: transparent; box-shadow: none; }}
    .kb-frame {{ background: transparent; border: none; padding: 5px; }}
    .key-cap {{
        background: rgba(30, 30, 30, 0.20);
        color: rgba(220, 220, 220, 0.40);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: {get_key_radius()};
        font-size: 8px;
        font-weight: bold;
        transition: all 0.05s ease;
    }}
    .key-active {{
        background: rgba(255, 255, 255, 0.60);
        color: rgba(0, 0, 0, 0.85);
        border-color: rgba(255, 255, 255, 0.70);
        box-shadow: 0px 0px 8px rgba(255, 255, 255, 0.3);
    }}
    .mouse-body {{
        background: rgba(30, 30, 30, 0.20);
        border: 1px solid rgba(255, 255, 255, 0.05);
        border-radius: 40px;
        overflow: hidden;
    }}
    .mouse-btn {{ background: transparent; transition: all 0.05s ease; }}
    .mouse-lmb {{ border-radius: 38px 0 0 0; border-right: 1px solid rgba(255,255,255,0.02); }}
    .mouse-rmb {{ border-radius: 0 38px 0 0; }}
    .mouse-palm {{ border-radius: 0 0 38px 38px; }}
    .mouse-lmb.key-active, .mouse-rmb.key-active {{
        background: rgba(255, 255, 255, 0.60);
        box-shadow: inset 0px 0px 10px rgba(255, 255, 255, 0.2);
    }}
    .mouse-mmb-wrapper {{ background: transparent; }}
    .mouse-mmb {{
        background: rgb(75, 75, 75);
        border-radius: 3px;
        border: 1px solid rgb(100, 100, 100);
    }}
    .mouse-mmb.key-active {{
        background: rgb(230, 230, 230);
        border-color: rgb(255, 255, 255);
        box-shadow: 0px 0px 8px rgba(255, 255, 255, 0.5);
    }}
    .mouse-line {{ background: rgb(90, 90, 90); }}
    .mouse-side-btn {{
        background: rgba(255, 255, 255, 0.10);
        border-radius: 2px;
        transition: all 0.05s ease;
    }}
    .mouse-side-btn.key-active {{
        background: rgba(255, 255, 255, 0.80);
        box-shadow: 0px 0px 6px rgba(255, 255, 255, 0.4);
    }}
    """

def find_input_devices():
    devices = set()
    for p in glob.glob("/dev/input/event*"):
        if os.access(p, os.R_OK):
            devices.add(p)
    return sorted(devices)

class KeyboardOverlay(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="com.whrr.KeyboardOverlay")
        self.key_widgets = {}
        self.running = True
        self.is_ru = False

    def do_activate(self):
        provider = Gtk.CssProvider()
        provider.load_from_data(build_css().encode("utf-8"))
        Gtk.StyleContext.add_provider_for_display(Gdk.Display.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)
        self.win = Gtk.ApplicationWindow(application=self)
        self.win.set_title("KeyboardOverlay")
        self.win.set_decorated(False)
        self.win.set_resizable(False)
        self.win.add_css_class("transparent-bg")

        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGUSR1, self.toggle_visibility)

        if HAS_LAYER_SHELL:
            Gtk4LayerShell.init_for_window(self.win)
            Gtk4LayerShell.set_namespace(self.win, "kb-overlay")
            Gtk4LayerShell.set_layer(self.win, Gtk4LayerShell.Layer.OVERLAY)
            Gtk4LayerShell.set_keyboard_mode(self.win, Gtk4LayerShell.KeyboardMode.NONE)
            pos = sys.argv[1] if len(sys.argv) > 1 else "bottom-right"
            Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.BOTTOM, True)
            if "left" in pos: Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.LEFT, True); Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.LEFT, 24)
            elif "center" not in pos: Gtk4LayerShell.set_anchor(self.win, Gtk4LayerShell.Edge.RIGHT, True); Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.RIGHT, 24)
            Gtk4LayerShell.set_margin(self.win, Gtk4LayerShell.Edge.BOTTOM, 24)

        main_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=GAP * 4)
        frame_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=GAP)
        frame_box.add_css_class("kb-frame")

        for row in KEYBOARD_ROWS:
            row_box = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=GAP)
            for en_lbl, ru_lbl, keycode, width_u in row:
                key_box = Gtk.Box()
                key_box.set_size_request(int(round(width_u * CELL_SIZE)) - GAP, KEY_HEIGHT)
                key_box.add_css_class("key-cap")
                lbl = Gtk.Label(label=en_lbl)
                lbl.set_hexpand(True); lbl.set_vexpand(True); lbl.set_halign(Gtk.Align.CENTER); lbl.set_valign(Gtk.Align.CENTER)
                key_box.append(lbl)
                row_box.append(key_box)
                self.key_widgets.setdefault(keycode, []).append((key_box, lbl, en_lbl, ru_lbl))
            frame_box.append(row_box)

        main_box.append(frame_box)

        mouse_overlay = Gtk.Overlay()
        mouse_overlay.set_valign(Gtk.Align.CENTER)
        PALM_W = int(CELL_SIZE * 2.8)
        HALF_W = PALM_W // 2
        TOP_H = int(KEY_HEIGHT * 1.6)
        PALM_H = int(KEY_HEIGHT * 3.4)

        mouse_body = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        mouse_body.add_css_class("mouse-body")
        top_row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)

        lmb_box = Gtk.Box(); lmb_box.set_size_request(HALF_W, TOP_H)
        lmb_box.add_css_class("mouse-btn"); lmb_box.add_css_class("mouse-lmb")
        self.key_widgets.setdefault(272, []).append((lmb_box, None, "", ""))

        rmb_box = Gtk.Box(); rmb_box.set_size_request(HALF_W, TOP_H)
        rmb_box.add_css_class("mouse-btn"); rmb_box.add_css_class("mouse-rmb")
        self.key_widgets.setdefault(273, []).append((rmb_box, None, "", ""))

        top_row.append(lmb_box); top_row.append(rmb_box)
        mouse_body.append(top_row)

        palm_box = Gtk.Box(); palm_box.set_size_request(PALM_W, PALM_H)
        palm_box.add_css_class("mouse-btn"); palm_box.add_css_class("mouse-palm")
        self.key_widgets.setdefault(0, []).append((palm_box, None, "", ""))
        mouse_body.append(palm_box)
        mouse_overlay.set_child(mouse_body)

        WHL_W = int(CELL_SIZE * 0.4)
        WHL_H = int(KEY_HEIGHT * 0.9)
        mmb_wrapper = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        mmb_wrapper.set_size_request(WHL_W, TOP_H)
        mmb_wrapper.set_halign(Gtk.Align.CENTER)
        mmb_wrapper.set_valign(Gtk.Align.START)
        mmb_wrapper.add_css_class("mouse-mmb-wrapper")

        top_line = Gtk.Box(); top_line.set_size_request(2, 6)
        top_line.set_halign(Gtk.Align.CENTER); top_line.add_css_class("mouse-line")
        mmb_wrapper.append(top_line)

        mmb_box = Gtk.Box(); mmb_box.set_size_request(WHL_W, WHL_H)
        mmb_box.add_css_class("mouse-mmb")
        mmb_wrapper.append(mmb_box)
        self.key_widgets.setdefault(274, []).append((mmb_box, None, "", ""))

        bottom_line = Gtk.Box(); bottom_line.set_size_request(2, 6)
        bottom_line.set_halign(Gtk.Align.CENTER); bottom_line.add_css_class("mouse-line")
        mmb_wrapper.append(bottom_line)
        mouse_overlay.add_overlay(mmb_wrapper)

        SIDE_W = 4
        SIDE_H = 14
        side_buttons = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        side_buttons.set_halign(Gtk.Align.START)
        side_buttons.set_valign(Gtk.Align.CENTER)
        side_buttons.set_margin_start(1)
        side_buttons.set_margin_top(14)

        m5_box = Gtk.Box(); m5_box.set_size_request(SIDE_W, SIDE_H)
        m5_box.add_css_class("mouse-side-btn")
        self.key_widgets.setdefault(276, []).append((m5_box, None, "", ""))

        m4_box = Gtk.Box(); m4_box.set_size_request(SIDE_W, SIDE_H)
        m4_box.add_css_class("mouse-side-btn")
        self.key_widgets.setdefault(275, []).append((m4_box, None, "", ""))

        side_buttons.append(m5_box)
        side_buttons.append(m4_box)
        mouse_overlay.add_overlay(side_buttons)
        main_box.append(mouse_overlay)

        self.win.set_child(main_box)
        self.win.present()
        self.check_initial_lang()
        threading.Thread(target=self.listen_input_events, daemon=True).start()
        threading.Thread(target=self.listen_hyprland_lang, daemon=True).start()

    def toggle_visibility(self):
        self.win.set_visible(not self.win.get_visible())
        return True

    def set_language(self, is_ru):
        if self.is_ru == is_ru: return False
        self.is_ru = is_ru
        for widgets in self.key_widgets.values():
            for _, lbl, en_text, ru_text in widgets:
                if lbl is not None:
                    lbl.set_label(ru_text if is_ru else en_text)
        return False

    def check_initial_lang(self):
        try:
            out = subprocess.getoutput("hyprctl devices -j")
            for k in json.loads(out).get("keyboards", []):
                if k.get("main"): self.set_language("ru" in k.get("active_keymap", "").lower())
        except: pass

    def listen_hyprland_lang(self):
        his = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
        if not his: return
        p1 = f"/run/user/{os.getuid()}/hypr/{his}/.socket2.sock"
        p2 = f"/tmp/hypr/{his}/.socket2.sock"
        sock_path = p1 if os.path.exists(p1) else p2
        while self.running:
            try:
                s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
                s.connect(sock_path)
                for line in s.makefile("r"):
                    if line.startswith("activelayout>>"):
                        ly = line.strip().split(">>")[1].split(",")[1].lower()
                        GLib.idle_add(self.set_language, "russian" in ly or "ru" in ly)
            except: import time; time.sleep(2)

    def _unflash(self, box):
        box.remove_css_class("key-active")
        return False

    def _flash_scroll_idle(self, box):
        box.add_css_class("key-active")
        GLib.timeout_add(100, self._unflash, box)
        return False

    def listen_input_events(self):
        ev_st = struct.Struct("llHHi")
        fds = []
        for dev in find_input_devices():
            try: fds.append(os.open(dev, os.O_RDONLY | os.O_NONBLOCK))
            except: pass
        if not fds: return
        while self.running:
            try:
                r, _, _ = select.select(fds, [], [], 1.0)
                for fd in r:
                    try:
                        data = os.read(fd, ev_st.size * 1024)
                        for off in range(0, len(data), ev_st.size):
                            if off + ev_st.size > len(data): break
                            _, _, ev_type, code, value = ev_st.unpack_from(data, off)
                            if ev_type == 1 and value in (0, 1):
                                mapped_code = code
                                if code in (278, 158): mapped_code = 275
                                elif code in (277, 159): mapped_code = 276
                                for box, _, _, _ in self.key_widgets.get(mapped_code, []):
                                    GLib.idle_add(lambda b=box, v=value: b.add_css_class("key-active") if v == 1 else b.remove_css_class("key-active"))
                            elif ev_type == 2 and code in (8, 11) and value != 0:
                                for box, _, _, _ in self.key_widgets.get(274, []):
                                    GLib.idle_add(self._flash_scroll_idle, box)
                    except OSError: pass
            except: break

if __name__ == "__main__":
    app = KeyboardOverlay()
    app.run(None)
