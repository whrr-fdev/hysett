#!/usr/bin/env python3
import os, sys, re, glob, json, hashlib, subprocess, zipfile, struct, zlib, shutil, colorsys

opacity_only = ("--opacity" in sys.argv)
ayugram_only = ("--ayugram" in sys.argv)
home = os.path.expanduser("~")
cc_path = os.path.join(home, ".config/hypr/scripts/control_center.conf")
st_path = os.path.join(home, ".config/hypr/scripts/theme_state.conf")
look_lua_path = os.path.join(home, ".config/hypr/look.lua")

is_rounded = True
if os.path.exists(st_path):
    is_rounded = open(st_path, errors="ignore").read().strip() != "square"

conf = {}
if os.path.exists(cc_path):
    for line in open(cc_path, errors="ignore"):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            conf[k.strip()] = v.strip()

bg_only_opacity = True
raw_act_op = 0.85
raw_inact_op = 0.75
border_sync_on = True
if os.path.exists(look_lua_path):
    l_txt = open(look_lua_path, errors="ignore").read()
    if "border_wallpaper_sync = false" in l_txt:
        border_sync_on = False
    if "bg_only_opacity = false" in l_txt:
        bg_only_opacity = False
    m = re.search(r"raw_active_opacity\s*=\s*([0-9.]+)", l_txt) or re.search(r"active_opacity\s*=\s*([0-9.]+)", l_txt)
    if m:
        raw_act_op = max(0.0, min(1.0, float(m.group(1))))
    m = re.search(r"raw_inactive_opacity\s*=\s*([0-9.]+)", l_txt) or re.search(r"inactive_opacity\s*=\s*([0-9.]+)", l_txt)
    if m:
        raw_inact_op = max(0.0, min(1.0, float(m.group(1))))

win_act_alpha = raw_act_op if bg_only_opacity else 1.0
win_inact_alpha = raw_inact_op if bg_only_opacity else 1.0

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6:
        return (168, 199, 250)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def rgb_to_hex(r, g, b):
    return f"#{max(0,min(255,int(r))):02x}{max(0,min(255,int(g))):02x}{max(0,min(255,int(b))):02x}"

def rgb_to_rgba_css(rgb, a):
    return f"rgba({max(0,min(255,int(rgb[0])))}, {max(0,min(255,int(rgb[1])))}, {max(0,min(255,int(rgb[2])))}, {max(0.0,min(1.0,float(a))):.3f})"

def blend(c1, c2, t):
    return (c1[0]*(1-t)+c2[0]*t, c1[1]*(1-t)+c2[1]*t, c1[2]*(1-t)+c2[2]*t)

def adjust_hsl(rgb, min_l=None, max_l=None, scale_l=1.0, scale_s=1.0):
    r, g, b = rgb[0]/255.0, rgb[1]/255.0, rgb[2]/255.0
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    l = max(0.0, min(1.0, l * scale_l))
    s = max(0.0, min(1.0, s * scale_s))
    if min_l is not None:
        l = max(min_l, l)
    if max_l is not None:
        l = min(max_l, l)
    nr, ng, nb = colorsys.hls_to_rgb(h, l, s)
    return (nr*255.0, ng*255.0, nb*255.0)

def luma(rgb):
    return (0.299 * rgb[0] + 0.587 * rgb[1] + 0.114 * rgb[2]) / 255.0

tint = float(conf.get("m3_surface_tint", "0.22"))
wall_dark = max(0.0, min(1.0, float(conf.get("m3_wallpaper_darkness", "0.55"))))
dyn_wall = conf.get("m3_dynamic_wallpaper_colors", conf.get("m3_dynamic_wallpaper", "1")) in ("1", "true")
pri_raw = conf.get("accent_color", "#a8c7fa")
win_bg_raw = conf.get("window_bg_color", "#000000")

# Если цвета с обоев выключены и не задан свой цвет — максимально чёрный режим
is_pure_black = (not dyn_wall) and (pri_raw.lower() in ("#ffffff", "#ebebeb")) and (win_bg_raw.lower() in ("#000000", "#010101", "#050505"))

if not is_pure_black:
    pri = hex_to_rgb(pri_raw)
    sec = hex_to_rgb(conf.get("m3_secondary_color", "#bec6dc"))
    ter = hex_to_rgb(conf.get("m3_tertiary_color", "#debcdf"))
    win_bg = hex_to_rgb(win_bg_raw)
    card_bg = hex_to_rgb(conf.get("card_bg_color", "#10141a"))

    dark_scale = max(0.30, 0.72 - wall_dark * 0.42)
    dark_win = (win_bg[0] * dark_scale, win_bg[1] * dark_scale, win_bg[2] * dark_scale)
    dark_card = (card_bg[0] * (dark_scale + 0.08), card_bg[1] * (dark_scale + 0.08), card_bg[2] * (dark_scale + 0.08))

    surf_rgb = blend(dark_win, pri, min(0.11, tint * 0.18 + 0.02))
    cont_rgb = blend(dark_card, pri, min(0.15, tint * 0.24 + 0.04))
    high_rgb = blend(dark_card, pri, min(0.22, tint * 0.32 + 0.07))

    # Папки: гарантированный контраст, чтобы никогда не пропадали на тёмном фоне
    folder_front_rgb = adjust_hsl(pri, min_l=0.38, max_l=0.72)
    folder_back_rgb = adjust_hsl(folder_front_rgb, min_l=0.22, max_l=0.50, scale_l=0.68, scale_s=0.90)
    folder_paper_rgb = blend(folder_front_rgb, (238, 240, 244), 0.42)
    folder_glyph_rgb = (10, 12, 16) if luma(folder_front_rgb) > 0.36 else (235, 238, 244)

    # Неактивная рамка окна — заметно светлее фона, но спокойнее активной
    inact_border_rgb = adjust_hsl(pri, min_l=0.38, max_l=0.56, scale_l=0.72, scale_s=0.65)

    # AyuGram: точное совпадение с активной тёмной палитрой
    ayu_surf_rgb = surf_rgb
    ayu_cont_rgb = cont_rgb
    ayu_high_rgb = high_rgb
    ayu_pri_rgb = pri
    ayu_out_rgb = blend(ayu_high_rgb, pri, 0.22)
else:
    pri = (255, 255, 255)
    sec = (165, 165, 165)
    ter = (205, 205, 205)
    surf_rgb = (0, 0, 0)
    cont_rgb = (4, 4, 4)
    high_rgb = (12, 12, 12)
    inact_border_rgb = (118, 118, 118)
    folder_front_rgb = (196, 196, 196)
    folder_back_rgb = (120, 120, 120)
    folder_paper_rgb = (234, 234, 234)
    folder_glyph_rgb = (14, 14, 14)
    ayu_surf_rgb = (0, 0, 0)
    ayu_cont_rgb = (0, 0, 0)
    ayu_high_rgb = (12, 12, 12)
    ayu_pri_rgb = (240, 240, 240)
    ayu_out_rgb = (16, 16, 16)

pri_hex = rgb_to_hex(*pri)
sec_hex = rgb_to_hex(*sec)
ter_hex = rgb_to_hex(*ter)
surf_hex = rgb_to_hex(*surf_rgb)
cont_hex = rgb_to_hex(*cont_rgb)
high_hex = rgb_to_hex(*high_rgb)
inact_border_hex = rgb_to_hex(*inact_border_rgb)
on_pri_hex = "#060709" if luma(pri) > 0.50 else "#ffffff"

folder_front_hex = rgb_to_hex(*folder_front_rgb)
folder_back_hex = rgb_to_hex(*folder_back_rgb)
folder_paper_hex = rgb_to_hex(*folder_paper_rgb)
folder_glyph_hex = rgb_to_hex(*folder_glyph_rgb)

ayu_surf_hex = rgb_to_hex(*ayu_surf_rgb)
ayu_cont_hex = rgb_to_hex(*ayu_cont_rgb)
ayu_high_hex = rgb_to_hex(*ayu_high_rgb)
ayu_pri_hex = rgb_to_hex(*ayu_pri_rgb)
ayu_out_hex = rgb_to_hex(*ayu_out_rgb)
ayu_on_pri_hex = "#060709" if luma(ayu_pri_rgb) > 0.50 else "#ffffff"

# 1. Kitty (мгновенная прозрачность только фона + цвета)
kitty_dir = os.path.join(home, ".config/kitty")
os.makedirs(kitty_dir, exist_ok=True)
with open(os.path.join(kitty_dir, "hysett-m3.conf"), "w") as f:
    f.write(f"""dynamic_background_opacity yes
background_opacity {win_act_alpha:.2f}
background {surf_hex}
foreground #eef0f5
cursor {pri_hex}
cursor_text_color {surf_hex}
url_color {pri_hex}
selection_background {cont_hex}
selection_foreground {pri_hex}
active_border_color {pri_hex}
inactive_border_color {high_hex}
bell_border_color {pri_hex}
active_tab_background {pri_hex}
active_tab_foreground {on_pri_hex}
inactive_tab_background {cont_hex}
inactive_tab_foreground #b8bece
tab_bar_background {surf_hex}
color0 {surf_hex}
color8 {high_hex}
color1 #ff6b6b
color9 #ff6b6b
color2 #69f0ae
color10 {pri_hex}
color3 {sec_hex}
color11 {sec_hex}
color4 {pri_hex}
color12 {cont_hex}
color5 {ter_hex}
color13 {ter_hex}
color6 {sec_hex}
color14 {sec_hex}
color7 #e6e8ee
color15 #ffffff
""")
subprocess.run("kill -USR1 $(pgrep -x kitty) 2>/dev/null || true", shell=True)

# 2. Btop (тема + прозрачный фон через Kitty)
btop_themes_dir = os.path.join(home, ".config/btop/themes")
os.makedirs(btop_themes_dir, exist_ok=True)
btop_theme_path = os.path.join(btop_themes_dir, "hysett-m3.theme")
with open(btop_theme_path, "w") as f:
    f.write(f"""theme[main_bg]="{surf_hex}"
theme[main_fg]="#eef0f5"
theme[title]="#ffffff"
theme[hi_fg]="{pri_hex}"
theme[selected_bg]="{cont_hex}"
theme[selected_fg]="{pri_hex}"
theme[inactive_fg]="#727885"
theme[proc_misc]="{sec_hex}"
theme[cpu_box]="{high_hex}"
theme[mem_box]="{high_hex}"
theme[net_box]="{high_hex}"
theme[proc_box]="{high_hex}"
theme[div_line]="{high_hex}"
theme[temp_start]="{sec_hex}"
theme[temp_mid]="{pri_hex}"
theme[temp_end]="{ter_hex}"
theme[cpu_start]="{sec_hex}"
theme[cpu_mid]="{pri_hex}"
theme[cpu_end]="{ter_hex}"
theme[free_start]="{sec_hex}"
theme[free_mid]="{pri_hex}"
theme[free_end]="{ter_hex}"
theme[cached_start]="{sec_hex}"
theme[cached_mid]="{pri_hex}"
theme[cached_end]="{ter_hex}"
theme[available_start]="{sec_hex}"
theme[available_mid]="{pri_hex}"
theme[available_end]="{ter_hex}"
theme[used_start]="{pri_hex}"
theme[used_mid]="{ter_hex}"
theme[used_end]="{pri_hex}"
theme[download_start]="{sec_hex}"
theme[download_mid]="{pri_hex}"
theme[download_end]="{ter_hex}"
theme[upload_start]="{sec_hex}"
theme[upload_mid]="{pri_hex}"
theme[upload_end]="{ter_hex}"
""")

btop_conf_path = os.path.join(home, ".config/btop/btop.conf")
if os.path.exists(btop_conf_path):
    try:
        bt = open(btop_conf_path, errors="ignore").read()
        bt = re.sub(r"^color_theme\s*=.*$", "color_theme = \"" + btop_theme_path + "\"", bt, flags=re.M)
        bg_flag = "false" if (bg_only_opacity and win_act_alpha < 0.99) else "true"
        bt = re.sub(r"^theme_background\s*=.*$", f"theme_background = {bg_flag}", bt, flags=re.M)
        with open(btop_conf_path, "w") as bf:
            bf.write(bt)
    except Exception:
        pass

# 3. GTK 3 / GTK 4 (прозрачный фон с 100% чётким текстом и иконками)
gtk_act_a = max(0.025, win_act_alpha) if bg_only_opacity else 1.0
gtk_inact_a = max(0.025, win_inact_alpha) if bg_only_opacity else 1.0
surf_act_css = rgb_to_rgba_css(surf_rgb, gtk_act_a)
surf_inact_css = rgb_to_rgba_css(surf_rgb, gtk_inact_a)
cont_act_a = min(1.0, gtk_act_a + (0.035 if win_act_alpha > 0.02 else 0.0))
cont_inact_a = min(1.0, gtk_inact_a + (0.025 if win_inact_alpha > 0.02 else 0.0))
cont_act_css = rgb_to_rgba_css(cont_rgb, cont_act_a)
cont_inact_css = rgb_to_rgba_css(cont_rgb, cont_inact_a)
pop_css = rgb_to_rgba_css(cont_rgb, max(0.88, win_act_alpha))

gtk_css = f"""@define-color accent_color {pri_hex};
@define-color accent_bg_color {pri_hex};
@define-color accent_fg_color {on_pri_hex};
@define-color window_bg_color {surf_act_css};
@define-color window_fg_color #f2f4f8;
@define-color window_backdrop_color {surf_inact_css};
@define-color view_bg_color transparent;
@define-color view_fg_color #f2f4f8;
@define-color view_backdrop_color transparent;
@define-color headerbar_bg_color {cont_act_css};
@define-color headerbar_fg_color #f2f4f8;
@define-color headerbar_backdrop_color {cont_inact_css};
@define-color headerbar_border_color {high_hex};
@define-color card_bg_color {cont_act_css};
@define-color card_fg_color #f2f4f8;
@define-color card_backdrop_color {cont_inact_css};
@define-color sidebar_bg_color {cont_act_css};
@define-color sidebar_fg_color #f2f4f8;
@define-color sidebar_backdrop_color {cont_inact_css};
@define-color secondary_sidebar_bg_color {cont_act_css};
@define-color secondary_sidebar_backdrop_color {cont_inact_css};
@define-color popover_bg_color {pop_css};
@define-color popover_fg_color #f2f4f8;
@define-color dialog_bg_color {pop_css};
@define-color dialog_fg_color #f2f4f8;
@define-color theme_bg_color {surf_act_css};
@define-color theme_fg_color #f2f4f8;
@define-color theme_base_color transparent;
@define-color theme_text_color #f2f4f8;
@define-color theme_selected_bg_color {pri_hex};
@define-color theme_selected_fg_color {on_pri_hex};
@define-color insensitive_bg_color {surf_act_css};
@define-color theme_unfocused_bg_color {surf_inact_css};
@define-color theme_unfocused_base_color transparent;
@define-color theme_unfocused_selected_bg_color {pri_hex};

:root {{
    --accent-color: {pri_hex};
    --accent-bg-color: {pri_hex};
    --accent-fg-color: {on_pri_hex};
    --window-bg-color: {surf_act_css};
    --window-fg-color: #f2f4f8;
    --view-bg-color: transparent;
    --view-fg-color: #f2f4f8;
    --headerbar-bg-color: {cont_act_css};
    --headerbar-fg-color: #f2f4f8;
    --headerbar-backdrop-color: {cont_inact_css};
    --sidebar-bg-color: {cont_act_css};
    --sidebar-fg-color: #f2f4f8;
    --sidebar-backdrop-color: {cont_inact_css};
    --secondary-sidebar-bg-color: {cont_act_css};
    --secondary-sidebar-backdrop-color: {cont_inact_css};
    --card-bg-color: {cont_act_css};
    --popover-bg-color: {pop_css};
    --dialog-bg-color: {pop_css};
}}

window, .background {{
    background-color: {surf_act_css} !important;
    color: #f2f4f8 !important;
}}
window:backdrop, .background:backdrop {{
    background-color: {surf_inact_css} !important;
    color: #e6e8ee !important;
}}
.view, scrolledwindow, viewport, gridview, listview, columnview,
navigation-split-view > .content-pane, overlay-split-view > .content-pane,
toolbarview, .nautilus-window .view, nautilus-view, nautilus-list-base {{
    background-color: transparent !important;
    color: #f2f4f8 !important;
}}
headerbar, .titlebar, .top-bar {{
    background-color: {cont_act_css} !important;
    background-image: none !important;
    color: #f2f4f8 !important;
}}
headerbar:backdrop, .titlebar:backdrop, .top-bar:backdrop {{
    background-color: {cont_inact_css} !important;
    background-image: none !important;
    color: #e6e8ee !important;
}}
.sidebar, .navigation-sidebar, .sidebar-pane, placessidebar,
navigation-split-view > .sidebar-pane, overlay-split-view > .sidebar-pane {{
    background-color: {cont_act_css} !important;
    color: #f2f4f8 !important;
}}
.sidebar:backdrop, .navigation-sidebar:backdrop, .sidebar-pane:backdrop, placessidebar:backdrop {{
    background-color: {cont_inact_css} !important;
    color: #e6e8ee !important;
}}
popover > contents, menu, .menu, tooltip, dialog {{
    background-color: {pop_css} !important;
    color: #f2f4f8 !important;
}}
"""
for gver in ("gtk-3.0", "gtk-4.0"):
    gdir = os.path.join(home, ".config", gver)
    os.makedirs(gdir, exist_ok=True)
    with open(os.path.join(gdir, "gtk.css"), "w") as f:
        f.write(gtk_css)

# В быстром режиме --opacity завершаем здесь (без перегенерации 1500 SVG папок)
if opacity_only:
    sys.exit(0)

# Убираем старые временные темы HySett-M3-A/B
for tname in ("HySett-M3-A", "HySett-M3-B"):
    for base_root in (os.path.join(home, ".local/share/themes"), os.path.join(home, ".themes")):
        shutil.rmtree(os.path.join(base_root, tname), ignore_errors=True)

# 4. Рамки окон Hyprland
if border_sync_on:
    pri_bare = pri_hex.lstrip("#")
    inact_bare = inact_border_hex.lstrip("#")
    act_rgba = "rgba(" + pri_bare + "ee)"
    inact_rgba = "rgba(" + inact_bare + "cc)"
    lua_border = "hl.config({ general = { col = { active_border = \"" + act_rgba + "\", inactive_border = \"" + inact_rgba + "\" } } })"
    subprocess.run(["hyprctl", "eval", lua_border], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.exists(look_lua_path):
        try:
            l_txt = open(look_lua_path, errors="ignore").read()
            l_txt = re.sub(r"active_border\s*=\s*\"[^\"]*\"", "active_border = \"" + act_rgba + "\"", l_txt)
            l_txt = re.sub(r"inactive_border\s*=\s*\"[^\"]*\"", "inactive_border = \"" + inact_rgba + "\"", l_txt)
            with open(look_lua_path, "w") as lf:
                lf.write(l_txt)
        except Exception:
            pass

# 5. Виджеты рабочего стола
widgets_m3_sync = conf.get("widgets_m3_sync", "1") in ("1", "true")
clock_m3_sync = conf.get("clock_m3_sync", conf.get("widgets_m3_sync", "1")) in ("1", "true")
c_rgb = pri if (not is_pure_black and clock_m3_sync) else (255, 255, 255)
w_hex = pri_hex if (not is_pure_black and widgets_m3_sync) else "#ffffff"

clock_conf_path = os.path.join(home, ".config/hypr/scripts/clock_style.conf")
clock_kv = {}
if os.path.exists(clock_conf_path):
    for line in open(clock_conf_path, errors="ignore"):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            clock_kv[k.strip()] = v.strip()
clock_kv["color_r"] = str(int(c_rgb[0]))
clock_kv["color_g"] = str(int(c_rgb[1]))
clock_kv["color_b"] = str(int(c_rgb[2]))
with open(clock_conf_path, "w") as f:
    for k, v in clock_kv.items():
        f.write(f"{k}={v}\n")

sysinfo_conf_path = os.path.join(home, ".config/hypr/scripts/sysinfo_style.conf")
sysinfo_kv = {}
if os.path.exists(sysinfo_conf_path):
    for line in open(sysinfo_conf_path, errors="ignore"):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            sysinfo_kv[k.strip()] = v.strip()
sysinfo_kv["text_color"] = w_hex
sysinfo_kv["graph_color"] = w_hex
with open(sysinfo_conf_path, "w") as f:
    for k, v in sysinfo_kv.items():
        f.write(f"{k}={v}\n")

# 6. Firefox
ctrl_r = int(float(conf.get("m3_control_radius", "12"))) if is_rounded else 0
card_r = int(float(conf.get("m3_card_radius", "16"))) if is_rounded else 0

ff_chrome_css = f"""/* HySett Material Design 3 Clean Firefox UI */
:root, #main-window, #navigator-toolbox, #TabsToolbar, #nav-bar, #PersonalToolbar, #sidebar-box, #tabbrowser-tabpanels, panel, menupopup {{
    --toolbar-bgcolor: {cont_hex} !important;
    --toolbar-color: #eef0f5 !important;
    --lwt-accent-color: {surf_hex} !important;
    --lwt-accent-color-inactive: {surf_hex} !important;
    --lwt-text-color: #eef0f5 !important;
    --lwt-toolbar-field-background-color: {surf_hex} !important;
    --lwt-toolbar-field-color: #eef0f5 !important;
    --lwt-toolbar-field-focus: {surf_hex} !important;
    --lwt-toolbar-field-border-color: transparent !important;
    --lwt-selected-tab-background-color: {high_hex} !important;
    --tab-selected-bgcolor: {high_hex} !important;
    --tab-selected-textcolor: {pri_hex} !important;
    --tab-border-radius: {ctrl_r}px !important;
    --tabpanel-background-color: {surf_hex} !important;
    --urlbar-box-bgcolor: {surf_hex} !important;
    --urlbar-box-focus-bgcolor: {surf_hex} !important;
    --urlbar-box-hover-bgcolor: {high_hex} !important;
    --toolbar-field-background-color: {surf_hex} !important;
    --toolbar-field-focus-background-color: {surf_hex} !important;
    --toolbar-field-color: #eef0f5 !important;
    --toolbar-field-focus-color: #ffffff !important;
    --toolbar-field-border-color: transparent !important;
    --focus-outline-color: {pri_hex} !important;
    --arrowpanel-background: {cont_hex} !important;
    --arrowpanel-color: #eef0f5 !important;
    --arrowpanel-border-color: {high_hex} !important;
    --arrowpanel-border-radius: {card_r}px !important;
    --panel-background: {cont_hex} !important;
    --panel-color: #eef0f5 !important;
    --panel-border-color: {high_hex} !important;
    --sidebar-background-color: {surf_hex} !important;
    --sidebar-text-color: #eef0f5 !important;
    --sidebar-border-color: {high_hex} !important;
    --toolbarbutton-border-radius: {ctrl_r}px !important;
    --toolbarbutton-hover-background: {high_hex} !important;
    --toolbarbutton-active-background: {pri_hex}33 !important;
    --toolbarbutton-icon-fill: #eef0f5 !important;
    --toolbarbutton-icon-fill-attention: {pri_hex} !important;
}}
#main-window, #navigator-toolbox, #TabsToolbar, #titlebar, #TabsToolbar-customization-target,
#main-window:-moz-window-inactive, #navigator-toolbox:-moz-window-inactive {{
    background: {surf_hex} !important;
    background-color: {surf_hex} !important;
    background-image: none !important;
    color: #eef0f5 !important;
    border: none !important;
    box-shadow: none !important;
}}
#nav-bar, #PersonalToolbar, #PlacesToolbar, .browser-toolbar:not(#TabsToolbar), findbar,
#nav-bar:-moz-window-inactive, #PersonalToolbar:-moz-window-inactive {{
    background: {cont_hex} !important;
    background-color: {cont_hex} !important;
    background-image: none !important;
    color: #eef0f5 !important;
    border: none !important;
    box-shadow: none !important;
}}
#PersonalToolbar toolbarbutton.bookmark-item, #PlacesToolbarItems > .bookmark-item {{
    color: #eef0f5 !important;
    border-radius: {ctrl_r}px !important;
    background: transparent !important;
    border: none !important;
}}
#PersonalToolbar toolbarbutton.bookmark-item:hover {{
    background-color: {high_hex} !important;
    color: {pri_hex} !important;
}}
.tabbrowser-tab, .tab-stack {{
    background: transparent !important;
    border: none !important;
    outline: none !important;
}}
.tabbrowser-tab::after, .tabbrowser-tab::before {{
    display: none !important;
    border: none !important;
}}
.tab-background {{
    border-radius: {ctrl_r}px !important;
    margin-block: 4px !important;
    border: none !important;
    outline: none !important;
    box-shadow: none !important;
}}
.tabbrowser-tab:hover > .tab-stack > .tab-background:not([selected]) {{
    background-color: {cont_hex} !important;
}}
.tab-background:is([selected], [multiselected]), .tab-background[selected="true"] {{
    background: {high_hex} !important;
    background-color: {high_hex} !important;
    background-image: none !important;
    border: 1px solid {pri_hex}55 !important;
    box-shadow: none !important;
}}
.tabbrowser-tab:not([selected]) .tab-label {{
    color: #b8bece !important;
}}
.tabbrowser-tab[selected] .tab-label {{
    color: {pri_hex} !important;
    font-weight: bold !important;
}}
#urlbar, #searchbar, #urlbar-container, #search-container {{
    background: transparent !important;
    background-color: transparent !important;
    border: none !important;
    outline: none !important;
    box-shadow: none !important;
}}
#urlbar-background, #urlbar > .urlbar-background, .searchbar-textbox {{
    background: {surf_hex} !important;
    background-color: {surf_hex} !important;
    background-image: none !important;
    border: 1px solid {high_hex} !important;
    border-radius: {max(ctrl_r, 14) if is_rounded else 0}px !important;
    box-shadow: none !important;
    outline: none !important;
}}
#urlbar[focused="true"] > #urlbar-background {{
    border-color: {pri_hex} !important;
    box-shadow: none !important;
}}
#urlbar[breakout][breakout-extend] > #urlbar-background {{
    border-radius: {card_r}px !important;
    background-color: {cont_hex} !important;
    border-color: {pri_hex} !important;
}}
.urlbarView, .urlbarView-body-outer, .urlbarView-body-inner, #PopupAutoComplete, .autocomplete-richlistbox {{
    background: transparent !important;
    color: #eef0f5 !important;
    border: none !important;
}}
.urlbarView-row {{
    border-radius: {ctrl_r}px !important;
}}
.urlbarView-row[selected], .urlbarView-row:hover {{
    background-color: {high_hex} !important;
    color: {pri_hex} !important;
}}
menupopup, panel, .panel-subview-body, .menupopup-arrowscrollbox {{
    background: {cont_hex} !important;
    background-color: {cont_hex} !important;
    color: #eef0f5 !important;
    border-radius: {card_r}px !important;
    border: 1px solid {high_hex} !important;
}}
menuitem, menu {{
    border-radius: {max(0, ctrl_r - 4)}px !important;
}}
menuitem:hover, menu:hover, menuitem[_moz-menuactive="true"], menu[_moz-menuactive="true"] {{
    background-color: {high_hex} !important;
    color: {pri_hex} !important;
}}
#sidebar-box, #sidebar-header, #sidebar {{
    background-color: {surf_hex} !important;
    color: #eef0f5 !important;
    border: none !important;
}}
#statuspanel-label {{
    background-color: {cont_hex} !important;
    color: {pri_hex} !important;
    border: 1px solid {high_hex} !important;
    border-radius: {max(0, ctrl_r - 4)}px !important;
}}
#tabbrowser-tabpanels, browser[type="content"] {{
    background-color: {surf_hex} !important;
}}
"""

ff_content_css = f"""/* HySett Material Design 3 Clean NewTab Theme */
@-moz-document url-prefix("about:newtab"), url-prefix("about:home"), url-prefix("about:blank"), url-prefix("about:privatebrowsing") {{
    :root, html, body, #root, .outer-wrapper {{
        --newtab-background-color: {surf_hex} !important;
        --newtab-background-color-secondary: {cont_hex} !important;
        --newtab-primary-action-background: {pri_hex} !important;
        --newtab-text-primary-color: #eef0f5 !important;
        background: {surf_hex} !important;
        background-color: {surf_hex} !important;
        color: #eef0f5 !important;
    }}
    .search-wrapper, .search-inner-wrapper {{
        background: transparent !important;
        border: none !important;
        box-shadow: none !important;
    }}
    .search-wrapper .search-handoff-button, .search-wrapper input {{
        background-color: {cont_hex} !important;
        color: #eef0f5 !important;
        border: 1px solid {high_hex} !important;
        border-radius: {24 if is_rounded else 0}px !important;
        box-shadow: none !important;
    }}
    .top-site-outer .tile, .card-outer {{
        background-color: {cont_hex} !important;
        border-radius: {card_r}px !important;
        box-shadow: none !important;
    }}
}}
"""

req_prefs = {
    "toolkit.legacyUserProfileCustomizations.stylesheets": "true",
    "layout.css.moz-document.content.enabled": "true",
    "toolkit.startup.recent_crashes": "0",
    "toolkit.startup.max_resumed_crashes": "-1",
    "browser.sessionstore.resume_from_crash": "false",
    "widget.non-native-theme.enabled": "true",
    "ui.systemUsesDarkTheme": "1",
    "browser.theme.content-theme": "0",
    "browser.theme.toolbar-theme": "0",
    "browser.display.background_color": "\"" + surf_hex + "\"",
    "extensions.activeThemeID": "\"default-theme@mozilla.org\"",
}

ff_profiles = glob.glob(os.path.expanduser("~/.mozilla/firefox/*")) + glob.glob(os.path.expanduser("~/.config/mozilla/firefox/*"))
for prof in ff_profiles:
    if os.path.isdir(prof) and ("default" in prof or os.path.exists(os.path.join(prof, "prefs.js"))):
        cdir = os.path.join(prof, "chrome")
        os.makedirs(cdir, exist_ok=True)
        with open(os.path.join(cdir, "userChrome.css"), "w") as f:
            f.write(ff_chrome_css)
        with open(os.path.join(cdir, "userContent.css"), "w") as f:
            f.write(ff_content_css)
        for pfile in ("user.js", "prefs.js"):
            p_path = os.path.join(prof, pfile)
            if pfile == "prefs.js" and not os.path.exists(p_path):
                continue
            lines = open(p_path, errors="ignore").read().splitlines() if os.path.exists(p_path) else []
            filtered = [ln for ln in lines if not any("\"" + k + "\"" in ln for k in req_prefs)]
            for k, v in req_prefs.items():
                filtered.append("user_pref(\"" + k + "\", " + v + ");")
            with open(p_path, "w") as f:
                f.write("\n".join(filtered) + "\n")

open(os.path.join(home, ".cache/ff_theme_dirty"), "w").write(pri_hex)

# 7. KDE / Qt (kdeglobals — чтобы Qt и диалоги AyuGram всегда совпадали с темой)
kde_path = os.path.join(home, ".config/kdeglobals")
kfile_tail = ""
if os.path.exists(kde_path):
    raw_kde = open(kde_path, errors="ignore").read()
    m_kfd = re.search(r"(\[KFileDialog Settings\][\s\S]*)", raw_kde)
    if m_kfd:
        kfile_tail = "\n" + m_kfd.group(1).strip() + "\n"

kde_content = f"""[ColorEffects:Disabled]
Color={surf_hex}

[Colors:Button]
BackgroundAlternate={high_hex}
BackgroundNormal={cont_hex}
DecorationFocus={pri_hex}
DecorationHover={pri_hex}
ForegroundActive={pri_hex}
ForegroundInactive=#9ea4b0
ForegroundLink={pri_hex}
ForegroundNormal=#eef0f5

[Colors:Selection]
BackgroundAlternate={pri_hex}
BackgroundNormal={pri_hex}
DecorationFocus={pri_hex}
DecorationHover={pri_hex}
ForegroundActive={on_pri_hex}
ForegroundNormal={on_pri_hex}

[Colors:View]
BackgroundAlternate={cont_hex}
BackgroundNormal={surf_hex}
DecorationFocus={pri_hex}
DecorationHover={pri_hex}
ForegroundActive={pri_hex}
ForegroundNormal=#eef0f5

[Colors:Window]
BackgroundAlternate={cont_hex}
BackgroundNormal={surf_hex}
DecorationFocus={pri_hex}
DecorationHover={pri_hex}
ForegroundActive={pri_hex}
ForegroundNormal=#eef0f5

[General]
ColorScheme=HySettM3
Name=HySettM3
shadeSortColumn=true
{kfile_tail}"""
with open(kde_path, "w") as kf:
    kf.write(kde_content)

# 8. Пакет темы для AyuGram (полная 927-строчная база night.tdesktop-theme + HSL-перекраска + colors.tdesktop-theme)
def make_solid_png(r, g, b, w=64, h=64):
    raw = b"".join(b"\x00" + bytes([max(0,min(255,int(r))), max(0,min(255,int(g))), max(0,min(255,int(b)))]) * w for _ in range(h))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

base_night_path = os.path.join(home, "hysett/scripts/ayugram_night_base.tdesktop-theme")
base_txt = open(base_night_path, encoding="utf-8", errors="ignore").read() if os.path.exists(base_night_path) else ""
pri_h, pri_l, pri_s = colorsys.rgb_to_hls(ayu_pri_rgb[0]/255.0, ayu_pri_rgb[1]/255.0, ayu_pri_rgb[2]/255.0)

def remap_tdesktop_color(m):
    hex_str = m.group(1)
    alpha_part = hex_str[6:] if len(hex_str) == 8 else ""
    r, g, b = int(hex_str[0:2], 16), int(hex_str[2:4], 16), int(hex_str[4:6], 16)
    h, l, s = colorsys.rgb_to_hls(r/255.0, g/255.0, b/255.0)
    is_tg_blue = (0.49 <= h <= 0.68)

    if l <= 0.28 and (is_tg_blue or s < 0.20):
        if is_pure_black:
            if l <= 0.145:
                nr, ng, nb = (0, 0, 0)
            elif l <= 0.205:
                v = int(6 + (l - 0.145) / 0.06 * 8)
                nr, ng, nb = (v, v, v)
            else:
                v = int(14 + (l - 0.205) / 0.075 * 10)
                nr, ng, nb = (v, v, v)
        else:
            if l <= 0.145:
                nr, ng, nb = ayu_surf_rgb
            elif l <= 0.205:
                nr, ng, nb = blend(ayu_surf_rgb, ayu_cont_rgb, (l - 0.145) / 0.06)
            else:
                target = ayu_out_rgb if s > 0.30 else ayu_high_rgb
                nr, ng, nb = blend(ayu_cont_rgb, target, (l - 0.205) / 0.075)
        return rgb_to_hex(nr, ng, nb) + alpha_part

    if is_tg_blue and s >= 0.26:
        if is_pure_black:
            if l < 0.36:
                v = int(18 + (l / 0.36) * 20)
                nr, ng, nb = (v, v, v)
            else:
                v = int(190 + min(1.0, (l - 0.36) / 0.40) * 65)
                nr, ng, nb = (v, v, v)
        else:
            if l < 0.36:
                nr, ng, nb = blend(ayu_high_rgb, ayu_pri_rgb, 0.32)
            else:
                nl = max(0.38, min(0.84, pri_l + (l - 0.56) * 0.45))
                rr, gg, bb = colorsys.hls_to_rgb(pri_h, nl, max(0.32, pri_s))
                nr, ng, nb = (rr*255.0, gg*255.0, bb*255.0)
        return rgb_to_hex(nr, ng, nb) + alpha_part

    if is_tg_blue and 0.06 <= s < 0.26 and l > 0.28:
        if is_pure_black:
            v = int(l * 255.0)
            nr, ng, nb = (v, v, v)
        else:
            rr, gg, bb = colorsys.hls_to_rgb(pri_h, l, min(0.16, s * 0.8))
            nr, ng, nb = (rr*255.0, gg*255.0, bb*255.0)
        return rgb_to_hex(nr, ng, nb) + alpha_part

    return "#" + hex_str

remapped_base = re.sub(r"#([0-9a-fA-F]{6}(?:[0-9a-fA-F]{2})?)", remap_tdesktop_color, base_txt)
ayu_msg_in = "#080808" if is_pure_black else ayu_cont_hex
ayu_overrides = f"""
// HySett Overrides
windowBg: {ayu_surf_hex};
windowFg: #f0f2f6;
windowBgOver: {ayu_high_hex};
windowBgRipple: {ayu_high_hex};
windowBgActive: {ayu_pri_hex};
windowFgActive: {ayu_on_pri_hex};
windowActiveTextFg: {ayu_pri_hex};
activeButtonBg: {ayu_pri_hex};
activeButtonBgOver: {ayu_pri_hex};
activeButtonFg: {ayu_on_pri_hex};
activeButtonFgOver: {ayu_on_pri_hex};
dialogsBg: {ayu_surf_hex};
dialogsPinnedBg: {ayu_surf_hex};
dialogsBgOver: {ayu_high_hex};
dialogsBgActive: {ayu_high_hex};
dialogsNameFgActive: {ayu_pri_hex};
dialogsUnreadBg: {ayu_pri_hex};
dialogsUnreadFg: {ayu_on_pri_hex};
dialogsUnreadBgActive: {ayu_pri_hex};
dialogsUnreadFgActive: {ayu_on_pri_hex};
dialogsVerifiedIconBg: {ayu_pri_hex};
dialogsVerifiedIconFg: {ayu_on_pri_hex};
mainMenuBg: {ayu_surf_hex};
mainMenuCoverBg: {ayu_surf_hex};
sideBarBg: {ayu_surf_hex};
sideBarBgActive: {ayu_high_hex};
sideBarIconFgActive: {ayu_pri_hex};
sideBarTextFgActive: {ayu_pri_hex};
sideBarBadgeBg: {ayu_pri_hex};
sideBarBadgeFg: {ayu_on_pri_hex};
topBarBg: {ayu_surf_hex};
titleBg: {ayu_surf_hex};
titleBgActive: {ayu_surf_hex};
historyComposeAreaBg: {ayu_surf_hex};
historyPinnedBg: {ayu_surf_hex};
historyReplyBg: {ayu_surf_hex};
emojiPanBg: {ayu_surf_hex};
emojiPanCategories: {ayu_surf_hex};
emojiPanHeaderBg: {ayu_surf_hex}ee;
boxBg: {ayu_surf_hex};
boxSearchBg: {ayu_surf_hex};
menuBg: {ayu_surf_hex};
menuBgOver: {ayu_high_hex};
msgInBg: {ayu_msg_in};
msgOutBg: {ayu_out_hex};
trayCounterBg: {ayu_pri_hex};
trayCounterFg: {ayu_on_pri_hex};
"""

ayu_palette = remapped_base + "\n" + ayu_overrides
theme_hash = hashlib.md5(ayu_palette.encode("utf-8")).hexdigest()[:8]
for old_f in glob.glob(os.path.join(home, ".cache/hysett_ayugram_*.tdesktop-theme")):
    try:
        os.remove(old_f)
    except Exception:
        pass

ayu_unique_path = os.path.join(home, f".cache/hysett_ayugram_{theme_hash}.tdesktop-theme")
ayu_theme_path = os.path.join(home, ".cache/hysett_ayugram.tdesktop-theme")
png_bytes = make_solid_png(*ayu_surf_rgb)
for out_p in (ayu_unique_path, ayu_theme_path):
    with zipfile.ZipFile(out_p, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("colors.tdesktop-theme", ayu_palette)
        zf.writestr("background.png", png_bytes)

with open(os.path.join(home, ".cache/hysett_ayugram_latest.txt"), "w") as lf:
    lf.write(ayu_unique_path + "\n")

if ayugram_only:
    sys.exit(0)

# 9. Папки Papirus (однопроходная замена re.sub — фикс наполовину невидимых папок!)
papirus_src = "/usr/share/icons/Papirus/64x64/places"
if os.path.isdir(papirus_src):
    color_map = {
        "#5294e2": folder_front_hex,
        "#4877b1": folder_back_hex,
        "#e4e4e4": folder_paper_hex,
        "#1d344f": folder_glyph_hex,
    }
    svg_pat = re.compile(r"#(?:5294e2|4877b1|e4e4e4|1d344f)", re.IGNORECASE)
    def repl_fn(m):
        return color_map[m.group(0).lower()]

    for ivar in ("HySett-Papirus-A", "HySett-Papirus-B"):
        idir = os.path.join(home, ".local/share/icons", ivar)
        p64 = os.path.join(idir, "64x64/places")
        os.makedirs(p64, exist_ok=True)
        for sz in ("48x48", "32x32", "24x24", "22x22", "16x16"):
            sz_dir = os.path.join(idir, sz)
            os.makedirs(sz_dir, exist_ok=True)
            sz_places = os.path.join(sz_dir, "places")
            if not os.path.islink(sz_places):
                if os.path.isdir(sz_places):
                    shutil.rmtree(sz_places, ignore_errors=True)
                os.symlink("../64x64/places", sz_places)
        for svg_file in glob.glob(os.path.join(papirus_src, "*.svg")):
            bname = os.path.basename(svg_file)
            if not (bname.startswith("folder") or bname.startswith("user-")):
                continue
            if any(x in bname for x in ("-blue-", "-red-", "-green-", "-yellow-", "-grey", "-orange-", "-violet-", "-cyan-")):
                continue
            try:
                raw_svg = open(svg_file, errors="ignore").read()
                recolored = svg_pat.sub(repl_fn, raw_svg)
                with open(os.path.join(p64, bname), "w") as out_f:
                    out_f.write(recolored)
            except Exception:
                pass
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", idir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

try:
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", "Adwaita-dark"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.isdir(papirus_src):
        cur_ico = subprocess.check_output(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], stderr=subprocess.DEVNULL).decode().strip().strip(chr(39))
        next_ico = "HySett-Papirus-B" if cur_ico == "HySett-Papirus-A" else "HySett-Papirus-A"
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", next_ico], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
except Exception:
    pass

try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore"))
    naut_wins = [c for c in clients if "nautilus" in str(c.get("class", "")).lower() and int(c.get("workspace", {}).get("id", 0)) > 0]
    if not naut_wins:
        subprocess.Popen("pkill -9 -x nautilus 2>/dev/null; sleep 0.08; nautilus --gapplication-service >/dev/null 2>&1 &", shell=True)
except Exception:
    pass
