#!/usr/bin/env python3
import os, sys, json, subprocess, shutil, re

HOME = os.path.expanduser("~")
CONF_DIR = os.path.join(HOME, ".config/hypr/scripts")
STATE_PATH = os.path.join(CONF_DIR, "terminal_settings.json")
CC_PATH = os.path.join(CONF_DIR, "control_center.conf")
ST_PATH = os.path.join(CONF_DIR, "theme_state.conf")
KITTY_DIR = os.path.join(HOME, ".config/kitty")
KITTY_CONF = os.path.join(KITTY_DIR, "kitty.conf")
KITTY_THEME_CONF = os.path.join(KITTY_DIR, "hysett-m3.conf")
FISH_DIR = os.path.join(HOME, ".config/fish")
FISH_CONF = os.path.join(FISH_DIR, "config.fish")
FISH_CONFD = os.path.join(FISH_DIR, "conf.d")
FISH_FUNCS = os.path.join(FISH_DIR, "functions")

DEFAULT_SETTINGS = {
    "tideEnabled": True,
    "tideStyle": "Rainbow",          # Lean | Classic | Rainbow
    "tideColors": "True color",      # True color | 16 colors
    "tideTime": "24-hour format",    # No | 24-hour format | 12-hour format
    "tideSeparators": "Round",       # Angled | Vertical | Slanted | Round
    "tideHeads": "Round",            # Sharp | Slanted | Round
    "tideTails": "Round",            # Flat | Sharp | Slanted | Round
    "tideHeight": "Two lines",       # One line | Two lines
    "tideFrame": False,
    "tideConnection": "Dotted",      # Disconnected | Dotted | Solid
    "tideSpacing": "Compact",        # Compact | Sparse
    "tideIcons": "Many icons",       # Few icons | Many icons
    "tideTransient": False,
    "tideChar": "❯",
    "dynamicTheme": True,
    "themePreset": 0,                # 0=Material You (Auto), 1=Catppuccin, 2=TokyoNight, 3=Gruvbox, 4=Nord, 5=Dracula, 6=Cyberpunk
    "fontFamily": "JetBrainsMono Nerd Font",
    "fontSize": 11,
    "paddingWidth": 12,
    "bgOpacity": 0.92,
    "cursorShape": "beam",           # beam | block | underline
    "cursorTrail": 2
}

PRESET_PALETTES = {
    1: { # Catppuccin Mocha
        "name": "Catppuccin Mocha",
        "bg": "#1e1e2e", "fg": "#cdd6f4", "cont": "#313244", "high": "#45475a",
        "pri": "#cba6f7", "sec": "#89b4fa", "ter": "#f5c2e7", "ok": "#a6e3a1", "warn": "#f9e2af", "err": "#f38ba8"
    },
    2: { # Tokyo Night
        "name": "Tokyo Night",
        "bg": "#1a1b26", "fg": "#c0caf5", "cont": "#24283b", "high": "#414868",
        "pri": "#7aa2f7", "sec": "#bb9af7", "ter": "#7dcfff", "ok": "#9ece6a", "warn": "#e0af68", "err": "#f7768e"
    },
    3: { # Gruvbox Dark
        "name": "Gruvbox Dark",
        "bg": "#1d2021", "fg": "#ebdbb2", "cont": "#282828", "high": "#3c3836",
        "pri": "#fabd2f", "sec": "#83a598", "ter": "#d3869b", "ok": "#b8bb26", "warn": "#fe8019", "err": "#fb4934"
    },
    4: { # Nord
        "name": "Nord",
        "bg": "#2e3440", "fg": "#eceff4", "cont": "#3b4252", "high": "#4c566a",
        "pri": "#88c0d0", "sec": "#81a1c1", "ter": "#b48ead", "ok": "#a3be8c", "warn": "#ebcb8b", "err": "#bf616a"
    },
    5: { # Dracula
        "name": "Dracula",
        "bg": "#282a36", "fg": "#f8f8f2", "cont": "#343746", "high": "#44475a",
        "pri": "#bd93f9", "sec": "#8be9fd", "ter": "#ff79c6", "ok": "#50fa7b", "warn": "#f1fa8c", "err": "#ff5555"
    },
    6: { # Cyberpunk Neon
        "name": "Cyberpunk Neon",
        "bg": "#0b0c16", "fg": "#e8f0ff", "cont": "#16192b", "high": "#252945",
        "pri": "#00f0ff", "sec": "#ff007f", "ter": "#fcee09", "ok": "#00ff9f", "warn": "#fcee09", "err": "#ff2a6d"
    }
}

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6:
        return (168, 199, 250)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def rgb_to_hex(r, g, b):
    return f"#{max(0,min(255,int(r))):02x}{max(0,min(255,int(g))):02x}{max(0,min(255,int(b))):02x}"

def blend(c1, c2, t):
    return (c1[0]*(1-t)+c2[0]*t, c1[1]*(1-t)+c2[1]*t, c1[2]*(1-t)+c2[2]*t)

def get_m3_palette():
    is_rounded = True
    if os.path.exists(ST_PATH):
        is_rounded = open(ST_PATH).read().strip() != "square"
    conf = {}
    if os.path.exists(CC_PATH):
        for line in open(CC_PATH, errors="ignore"):
            if "=" in line:
                k, v = line.strip().split("=", 1)
                conf[k.strip()] = v.strip()
    tint = float(conf.get("m3_surface_tint", "0.22"))
    pri_raw = conf.get("accent_color", "#a8c7fa")
    is_mono = (not is_rounded) or (pri_raw.lower() == "#ffffff" and tint < 0.02)
    if not is_mono:
        pri = hex_to_rgb(pri_raw)
        sec = hex_to_rgb(conf.get("m3_secondary_color", "#bec6dc"))
        ter = hex_to_rgb(conf.get("m3_tertiary_color", "#debcdf"))
        win_bg = hex_to_rgb(conf.get("window_bg_color", "#0b0d12"))
        card_bg = hex_to_rgb(conf.get("card_bg_color", "#141720"))
        dark_win = (win_bg[0]*0.60, win_bg[1]*0.60, win_bg[2]*0.60)
        dark_card = (card_bg[0]*0.65, card_bg[1]*0.65, card_bg[2]*0.65)
        surf_rgb = blend(dark_win, pri, min(0.14, tint*0.22 + 0.03))
        cont_rgb = blend(dark_card, pri, min(0.18, tint*0.28 + 0.05))
        high_rgb = blend(dark_card, pri, min(0.25, tint*0.36 + 0.08))
    else:
        pri = (235, 235, 235)
        sec = (160, 160, 168)
        ter = (190, 190, 198)
        surf_rgb = (10, 11, 14)
        cont_rgb = (18, 20, 25)
        high_rgb = (26, 29, 36)
    return {
        "bg": rgb_to_hex(*surf_rgb),
        "fg": "#e6e8ee",
        "cont": rgb_to_hex(*cont_rgb),
        "high": rgb_to_hex(*high_rgb),
        "pri": rgb_to_hex(*pri),
        "sec": rgb_to_hex(*sec),
        "ter": rgb_to_hex(*ter),
        "ok": "#69f0ae",
        "warn": "#ffd740",
        "err": "#ff6b6b"
    }

def load_state():
    st = dict(DEFAULT_SETTINGS)
    if os.path.exists(STATE_PATH):
        try:
            with open(STATE_PATH, "r") as f:
                data = json.load(f)
                st.update(data)
        except Exception:
            pass
    else:
        # Read initial values from kitty.conf if available
        if os.path.exists(KITTY_CONF):
            for line in open(KITTY_CONF, errors="ignore"):
                s = line.strip()
                if s.startswith("font_family "):
                    st["fontFamily"] = s.split(" ", 1)[1].strip()
                elif s.startswith("font_size "):
                    try:
                        st["fontSize"] = int(float(s.split(" ", 1)[1].strip()))
                    except Exception:
                        pass
                elif s.startswith("window_padding_width "):
                    try:
                        st["paddingWidth"] = int(float(s.split(" ", 1)[1].strip()))
                    except Exception:
                        pass
                elif s.startswith("background_opacity "):
                    try:
                        st["bgOpacity"] = float(s.split(" ", 1)[1].strip())
                    except Exception:
                        pass
                elif s.startswith("cursor_shape "):
                    st["cursorShape"] = s.split(" ", 1)[1].strip()
                elif s.startswith("cursor_trail "):
                    try:
                        st["cursorTrail"] = int(float(s.split(" ", 1)[1].strip()))
                    except Exception:
                        pass
    return st

def save_state(st):
    os.makedirs(CONF_DIR, exist_ok=True)
    with open(STATE_PATH, "w") as f:
        json.dump(st, f, ensure_ascii=False, indent=2)

def list_monospace_fonts():
    preferred = [
        "JetBrainsMono Nerd Font",
        "MesloLGS Nerd Font",
        "FiraCode Nerd Font",
        "Hack Nerd Font",
        "CaskaydiaCove Nerd Font",
        "Iosevka Nerd Font",
        "UbuntuMono Nerd Font",
        " DejaVuSansM Nerd Font",
        "JetBrains Mono",
        "Fira Code",
        "Cascadia Code",
        "Source Code Pro",
        "Hack",
        "Monospace"
    ]
    found = []
    try:
        out = subprocess.check_output(["fc-list", ":", "family"], text=True, stderr=subprocess.DEVNULL)
        all_fams = set()
        for line in out.splitlines():
            for part in line.split(","):
                name = part.strip()
                if name:
                    all_fams.add(name)
        for p in preferred:
            p_clean = p.strip()
            if p_clean in all_fams and p_clean not in found:
                found.append(p_clean)
        mono_kw = ("mono", "nerd", "code", "console", "iosevka", "meslo", "hack", "terminus", "courier", "fixed")
        for fam in sorted(all_fams):
            low = fam.lower()
            if any(k in low for k in mono_kw) and not fam.startswith("."):
                if fam not in found:
                    found.append(fam)
    except Exception:
        pass
    for p in ["JetBrainsMono Nerd Font", "MesloLGS Nerd Font", "FiraCode Nerd Font", "Monospace"]:
        if p not in found:
            found.append(p)
    return found[:45]

def is_tide_installed():
    return (
        os.path.exists(os.path.join(FISH_FUNCS, "tide.fish")) or
        os.path.exists(os.path.join(FISH_FUNCS, "_tide_sub_configure.fish"))
    )

def ensure_tide_installed():
    if is_tide_installed():
        return True
    cmd = (
        "if not functions -q fisher; "
        "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source; "
        "end; "
        "fisher install IlanCosman/tide@v6"
    )
    subprocess.run(["fish", "-c", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return is_tide_installed()

def apply_fish_tide_activation(enabled):
    os.makedirs(FISH_CONFD, exist_ok=True)
    os.makedirs(FISH_FUNCS, exist_ok=True)
    fp_active = os.path.join(FISH_FUNCS, "fish_prompt.fish")
    fp_disabled = os.path.join(FISH_FUNCS, "fish_prompt.fish.tide_disabled")
    fmp_active = os.path.join(FISH_FUNCS, "fish_mode_prompt.fish")
    fmp_disabled = os.path.join(FISH_FUNCS, "fish_mode_prompt.fish.tide_disabled")
    confd_hook = os.path.join(FISH_CONFD, "zz_hysett_tide.fish")

    # Clean old marker from config.fish
    if os.path.exists(FISH_CONF):
        raw = open(FISH_CONF, errors="ignore").read()
        raw = re.sub(r"\n*# HYSETT_TIDE_START.*?# HYSETT_TIDE_END\n*", "\n", raw, flags=re.S)
    else:
        raw = "source /usr/share/cachyos-fish-config/cachyos-config.fish\n"

    if enabled:
        ensure_tide_installed()
        if not os.path.exists(fp_active) and os.path.exists(fp_disabled):
            shutil.move(fp_disabled, fp_active)
        if not os.path.exists(fmp_active) and os.path.exists(fmp_disabled):
            shutil.move(fmp_disabled, fmp_active)
        if not os.path.exists(fp_active):
            subprocess.run(["fish", "-c", "fisher install IlanCosman/tide@v6"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

        hook_block = (
            "\n# HYSETT_TIDE_START\n"
            "if status is-interactive\n"
            "    test -f ~/.config/fish/functions/fish_prompt.fish && source ~/.config/fish/functions/fish_prompt.fish\n"
            "end\n"
            "# HYSETT_TIDE_END\n"
        )
        raw = raw.rstrip() + "\n" + hook_block
        with open(FISH_CONF, "w") as f:
            f.write(raw)
        with open(confd_hook, "w") as f:
            f.write("if status is-interactive; test -f ~/.config/fish/functions/fish_prompt.fish && source ~/.config/fish/functions/fish_prompt.fish; end\n")
    else:
        if os.path.exists(fp_active):
            shutil.move(fp_active, fp_disabled)
        if os.path.exists(fmp_active):
            shutil.move(fmp_active, fmp_disabled)
        if os.path.exists(confd_hook):
            os.remove(confd_hook)
        hook_block = (
            "\n# HYSETT_TIDE_START\n"
            "# Tide prompt disabled via HySett (using default CachyOS / fish prompt)\n"
            "# HYSETT_TIDE_END\n"
        )
        raw = raw.rstrip() + "\n" + hook_block
        with open(FISH_CONF, "w") as f:
            f.write(raw)

def build_tide_auto_args(st):
    style = st.get("tideStyle", "Rainbow")
    colors = st.get("tideColors", "True color")
    show_time = st.get("tideTime", "24-hour format")
    seps = st.get("tideSeparators", "Round")
    heads = st.get("tideHeads", "Round")
    tails = st.get("tideTails", "Round")
    height = st.get("tideHeight", "Two lines")
    frame = bool(st.get("tideFrame", False))
    conn = st.get("tideConnection", "Dotted")
    spacing = st.get("tideSpacing", "Compact")
    icons = st.get("tideIcons", "Many icons")
    transient = "Yes" if st.get("tideTransient", False) else "No"

    args = [
        f"--style={style}",
        f"--prompt_colors={colors}",
    ]
    if style == "Classic" and colors == "True color":
        args.append("--classic_prompt_color=Dark")
    args.append(f"--show_time={show_time}")

    if style == "Lean":
        args.append(f"--lean_prompt_height={height}")
        if height == "Two lines":
            args.append(f"--prompt_connection={conn}")
            if conn != "Disconnected" and colors == "True color":
                args.append("--prompt_connection_andor_frame_color=Dark")
    else:
        if style == "Rainbow":
            args.append(f"--rainbow_prompt_separators={seps}")
        else:
            args.append(f"--classic_prompt_separators={seps}")
        args.append(f"--powerline_prompt_heads={heads}")
        args.append(f"--powerline_prompt_tails={tails}")
        if height == "One line":
            args.append("--powerline_prompt_style=One line")
        else:
            pstyle = "Two lines, character and frame" if frame else "Two lines, character"
            args.append(f"--powerline_prompt_style={pstyle}")
            args.append(f"--prompt_connection={conn}")
            args.append(f"--powerline_right_prompt_frame={'Yes' if frame else 'No'}")
            if (frame or conn != "Disconnected") and colors == "True color":
                args.append("--prompt_connection_andor_frame_color=Dark")

    args.append(f"--prompt_spacing={spacing}")
    args.append(f"--icons={icons}")
    args.append(f"--transient={transient}")
    return args

def apply_tide_colors_and_vars(st, pal):
    if not st.get("tideEnabled", True):
        return
    char_icon = st.get("tideChar", "❯") or "❯"
    pri = pal["pri"].lstrip("#")
    sec = pal["sec"].lstrip("#")
    ter = pal["ter"].lstrip("#")
    bg = pal["bg"].lstrip("#")
    cont = pal["cont"].lstrip("#")
    high = pal["high"].lstrip("#")
    ok = pal["ok"].lstrip("#")
    err = pal["err"].lstrip("#")

    style = st.get("tideStyle", "Rainbow")
    use_theme_colors = st.get("dynamicTheme", True) or int(st.get("themePreset", 0)) > 0

    fish_cmds = [
        f"set -U tide_character_icon {json.dumps(char_icon)}",
        f"set -U tide_character_color {pri}",
        f"set -U tide_character_color_failure {err}",
    ]

    if use_theme_colors and st.get("tideColors", "True color") == "True color":
        if style == "Lean":
            fish_cmds += [
                f"set -U tide_pwd_bg_color normal",
                f"set -U tide_pwd_color_anchors {pri}",
                f"set -U tide_pwd_color_dirs {sec}",
                f"set -U tide_pwd_color_truncated_dirs {sec}",
                f"set -U tide_git_bg_color normal",
                f"set -U tide_git_color_branch {ter}",
                f"set -U tide_os_bg_color normal",
                f"set -U tide_os_color {pri}",
                f"set -U tide_time_bg_color normal",
                f"set -U tide_time_color {sec}",
                f"set -U tide_cmd_duration_bg_color normal",
                f"set -U tide_cmd_duration_color {ter}",
                f"set -U tide_prompt_color_frame_and_connection {high}",
            ]
        elif style == "Classic":
            fish_cmds += [
                f"set -U tide_pwd_bg_color {cont}",
                f"set -U tide_pwd_color_anchors {pri}",
                f"set -U tide_pwd_color_dirs E6E8EE",
                f"set -U tide_pwd_color_truncated_dirs {sec}",
                f"set -U tide_git_bg_color {cont}",
                f"set -U tide_git_color_branch {ter}",
                f"set -U tide_os_bg_color {high}",
                f"set -U tide_os_color {pri}",
                f"set -U tide_time_bg_color {cont}",
                f"set -U tide_time_color {sec}",
                f"set -U tide_cmd_duration_bg_color {cont}",
                f"set -U tide_cmd_duration_color {ter}",
                f"set -U tide_prompt_color_frame_and_connection {high}",
            ]
        else:  # Rainbow synced with theme palette!
            # Check brightness of pri for contrast text
            r, g, b = hex_to_rgb("#" + pri)
            dark_txt = "0B0D12" if (r*0.299 + g*0.587 + b*0.114) > 135 else "FFFFFF"
            fish_cmds += [
                f"set -U tide_os_bg_color {high}",
                f"set -U tide_os_color {pri}",
                f"set -U tide_pwd_bg_color {pri}",
                f"set -U tide_pwd_color_anchors {dark_txt}",
                f"set -U tide_pwd_color_dirs {dark_txt}",
                f"set -U tide_pwd_color_truncated_dirs {dark_txt}",
                f"set -U tide_git_bg_color {cont}",
                f"set -U tide_git_bg_color_unstable {high}",
                f"set -U tide_git_bg_color_urgent {err}",
                f"set -U tide_git_color_branch {pri}",
                f"set -U tide_git_color_staged {ok}",
                f"set -U tide_git_color_dirty {ter}",
                f"set -U tide_git_color_untracked {sec}",
                f"set -U tide_cmd_duration_bg_color {cont}",
                f"set -U tide_cmd_duration_color {ter}",
                f"set -U tide_time_bg_color {high}",
                f"set -U tide_time_color {sec}",
                f"set -U tide_prompt_color_frame_and_connection {high}",
            ]

    fish_cmds.append(
        "for v in (set -U --names | string match '_tide_prompt_*'); set -U -e $v; end; "
        "test -f ~/.config/fish/functions/fish_prompt.fish && source ~/.config/fish/functions/fish_prompt.fish"
    )
    subprocess.run(["fish", "-c", "; ".join(fish_cmds)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def apply_kitty_config(st, pal):
    os.makedirs(KITTY_DIR, exist_ok=True)
    font_fam = st.get("fontFamily", "JetBrainsMono Nerd Font")
    font_sz = int(st.get("fontSize", 11))
    pad_w = int(st.get("paddingWidth", 12))
    bg_op = float(st.get("bgOpacity", 0.92))
    c_shape = st.get("cursorShape", "beam")
    c_trail = int(st.get("cursorTrail", 2))

    kitty_main = f"""confirm_os_window_close 0
cursor_trail {c_trail}
cursor_trail_start_threshold 2
cursor_trail_decay 0.15 0.5
cursor_shape {c_shape}
allow_remote_control yes

window_padding_width {pad_w}
font_family {font_fam}
font_size {font_sz}
background_opacity {bg_op:.2f}
include hysett-m3.conf
"""
    with open(KITTY_CONF, "w") as f:
        f.write(kitty_main)

    surf_hex = pal["bg"]
    fg_hex = pal["fg"]
    pri_hex = pal["pri"]
    sec_hex = pal["sec"]
    ter_hex = pal["ter"]
    cont_hex = pal["cont"]
    high_hex = pal["high"]

    with open(KITTY_THEME_CONF, "w") as f:
        f.write(f"""background {surf_hex}
foreground {fg_hex}
cursor {pri_hex}
cursor_text_color {surf_hex}
url_color {pri_hex}
selection_background {cont_hex}
selection_foreground {pri_hex}
active_border_color {pri_hex}
inactive_border_color {high_hex}
bell_border_color {pri_hex}
active_tab_background {pri_hex}
active_tab_foreground #0b0d12
inactive_tab_background {cont_hex}
inactive_tab_foreground #b8bece
tab_bar_background {surf_hex}
color0 {surf_hex}
color8 {high_hex}
color1 {pal['err']}
color9 {pal['err']}
color2 {pri_hex}
color10 {pri_hex}
color3 {sec_hex}
color11 {sec_hex}
color4 {pri_hex}
color12 {pri_hex}
color5 {ter_hex}
color13 {ter_hex}
color6 {sec_hex}
color14 {sec_hex}
color7 {fg_hex}
color15 #ffffff
""")
    subprocess.run("kill -USR1 $(pgrep -x kitty) 2>/dev/null || true", shell=True)

def resolve_active_palette(st):
    preset = int(st.get("themePreset", 0))
    if st.get("dynamicTheme", True) or preset == 0 or preset not in PRESET_PALETTES:
        return get_m3_palette()
    return PRESET_PALETTES[preset]

def full_apply(st, run_tide_configure=True):
    save_state(st)
    pal = resolve_active_palette(st)
    apply_kitty_config(st, pal)
    tide_on = bool(st.get("tideEnabled", True))
    apply_fish_tide_activation(tide_on)
    if tide_on:
        if run_tide_configure:
            t_args = build_tide_auto_args(st)
            quoted = " ".join(json.dumps(a) for a in t_args)
            cmd = f"source ~/.config/fish/functions/tide.fish; source ~/.config/fish/functions/_tide_sub_configure.fish; _tide_sub_configure --auto {quoted}"
            subprocess.run(["fish", "-c", cmd], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        apply_tide_colors_and_vars(st, pal)

def make_status_json(st):
    st_out = dict(st)
    st_out["tideInstalled"] = is_tide_installed()
    st_out["fonts"] = list_monospace_fonts()
    st_out["palette"] = resolve_active_palette(st)
    return json.dumps(st_out, ensure_ascii=False)

def main():
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    st = load_state()

    if cmd == "status":
        print(make_status_json(st))
    elif cmd == "sync_theme":
        # Called by sync_m3_windows.py on wallpaper/theme change
        if st.get("dynamicTheme", True) or int(st.get("themePreset", 0)) == 0:
            pal = get_m3_palette()
            apply_kitty_config(st, pal)
            if st.get("tideEnabled", True) and is_tide_installed():
                apply_tide_colors_and_vars(st, pal)
        print(make_status_json(st))
    elif cmd == "apply_json":
        if len(sys.argv) > 2:
            try:
                patch = json.loads(sys.argv[2])
                reconf_keys = {"tideEnabled", "tideStyle", "tideColors", "tideTime", "tideSeparators", "tideHeads", "tideTails", "tideHeight", "tideFrame", "tideConnection", "tideSpacing", "tideIcons", "tideTransient"}
                need_tide_reconf = any((k in patch and patch[k] != st.get(k)) for k in reconf_keys)
                st.update(patch)
                full_apply(st, run_tide_configure=need_tide_reconf)
            except Exception as e:
                sys.stderr.write(str(e) + "\n")
        print(make_status_json(st))
    elif cmd == "reinstall_tide":
        ensure_tide_installed()
        st["tideEnabled"] = True
        full_apply(st, run_tide_configure=True)
        print(make_status_json(st))
    elif cmd == "open_terminal":
        subprocess.Popen(["kitty"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(make_status_json(st))
    else:
        print(make_status_json(st))

if __name__ == "__main__":
    main()
