#!/usr/bin/env python3
import os, io, glob, json, subprocess, zipfile, struct, zlib

home = os.path.expanduser("~")
cc_path = os.path.join(home, ".config/hypr/scripts/control_center.conf")
st_path = os.path.join(home, ".config/hypr/scripts/theme_state.conf")

is_rounded = True
if os.path.exists(st_path):
    is_rounded = open(st_path).read().strip() != "square"

conf = {}
if os.path.exists(cc_path):
    for line in open(cc_path, errors="ignore"):
        if "=" in line:
            k, v = line.strip().split("=", 1)
            conf[k.strip()] = v.strip()

def hex_to_rgb(h):
    h = h.lstrip("#")
    if len(h) != 6:
        return (168, 199, 250)
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))

def rgb_to_hex(r, g, b):
    return f"#{max(0,min(255,int(r))):02x}{max(0,min(255,int(g))):02x}{max(0,min(255,int(b))):02x}"

def blend(c1, c2, t):
    return (c1[0]*(1-t)+c2[0]*t, c1[1]*(1-t)+c2[1]*t, c1[2]*(1-t)+c2[2]*t)

tint = float(conf.get("m3_surface_tint", "0.22"))
pri_raw = conf.get("accent_color", "#a8c7fa")
is_monochrome = (not is_rounded) or (pri_raw.lower() == "#ffffff" and tint < 0.02)

if not is_monochrome:
    pri = hex_to_rgb(pri_raw)
    sec = hex_to_rgb(conf.get("m3_secondary_color", "#bec6dc"))
    ter = hex_to_rgb(conf.get("m3_tertiary_color", "#debcdf"))
    win_bg = hex_to_rgb(conf.get("window_bg_color", "#0b0d12"))
    card_bg = hex_to_rgb(conf.get("card_bg_color", "#141720"))

    dark_win = (win_bg[0] * 0.60, win_bg[1] * 0.60, win_bg[2] * 0.60)
    dark_card = (card_bg[0] * 0.65, card_bg[1] * 0.65, card_bg[2] * 0.65)

    surf_rgb = blend(dark_win, pri, min(0.14, tint * 0.22 + 0.03))
    cont_rgb = blend(dark_card, pri, min(0.18, tint * 0.28 + 0.05))
    high_rgb = blend(dark_card, pri, min(0.25, tint * 0.36 + 0.08))
    folder_back_rgb = blend((pri[0]*0.62, pri[1]*0.62, pri[2]*0.62), sec, 0.25)

    ayu_surf_rgb = blend((4, 5, 6), pri, 0.04)
    ayu_cont_rgb = blend((8, 10, 12), pri, 0.07)
    ayu_high_rgb = blend((13, 16, 20), pri, 0.11)
    ayu_pri_rgb = (pri[0] * 0.44, pri[1] * 0.44, pri[2] * 0.44)
else:
    pri = (235, 235, 235)
    sec = (160, 160, 168)
    ter = (190, 190, 198)
    surf_rgb = (10, 11, 14)
    cont_rgb = (18, 20, 25)
    high_rgb = (26, 29, 36)
    folder_back_rgb = (120, 125, 135)
    ayu_surf_rgb = (8, 9, 12)
    ayu_cont_rgb = (14, 16, 20)
    ayu_high_rgb = (22, 24, 30)
    ayu_pri_rgb = (110, 115, 125)

pri_hex = rgb_to_hex(*pri)
sec_hex = rgb_to_hex(*sec)
ter_hex = rgb_to_hex(*ter)
surf_hex = rgb_to_hex(*surf_rgb)
cont_hex = rgb_to_hex(*cont_rgb)
high_hex = rgb_to_hex(*high_rgb)
folder_back_hex = rgb_to_hex(*folder_back_rgb)
ayu_surf_hex = rgb_to_hex(*ayu_surf_rgb)
ayu_cont_hex = rgb_to_hex(*ayu_cont_rgb)
ayu_high_hex = rgb_to_hex(*ayu_high_rgb)
ayu_pri_hex = rgb_to_hex(*ayu_pri_rgb)

# 1. Рамки окон Hyprland
subprocess.run(["hyprctl", "keyword", "general:col.active_border", f"rgba({pri_hex.lstrip('#')}ee)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
subprocess.run(["hyprctl", "keyword", "general:col.inactive_border", f"rgba({high_hex.lstrip('#')}aa)"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

# 2. Виджеты рабочего стола: clock_overlay и sysinfo_overlay
widgets_m3_sync = conf.get("widgets_m3_sync", "1") in ("1", "true")
clock_m3_sync = conf.get("clock_m3_sync", conf.get("widgets_m3_sync", "1")) in ("1", "true")
c_rgb = pri if (not is_monochrome and clock_m3_sync) else (255, 255, 255)
w_hex = pri_hex if (not is_monochrome and widgets_m3_sync) else "#ffffff"

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

# 3. Терминал Kitty и монитор Btop
kitty_dir = os.path.join(home, ".config/kitty")
os.makedirs(kitty_dir, exist_ok=True)
with open(os.path.join(kitty_dir, "hysett-m3.conf"), "w") as f:
    f.write(f"""background {surf_hex}
foreground #e6e8ee
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
""")
subprocess.run("kill -USR1 $(pgrep -x kitty) 2>/dev/null || true", shell=True)

btop_themes_dir = os.path.join(home, ".config/btop/themes")
os.makedirs(btop_themes_dir, exist_ok=True)
with open(os.path.join(btop_themes_dir, "hysett-m3.theme"), "w") as f:
    f.write(f"""theme[main_bg]="{surf_hex}"
theme[main_fg]="#e6e8ee"
theme[title]="#ffffff"
theme[hi_fg]="{pri_hex}"
theme[selected_bg]="{cont_hex}"
theme[selected_fg]="{pri_hex}"
theme[inactive_fg]="#6c7280"
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

# 4. GTK 3 / GTK 4 / libadwaita + динамические темы HySett-M3-A / HySett-M3-B (для живого обновления Firefox и GTK без закрытия окон)
gtk_css = f"""@define-color accent_color {pri_hex};
@define-color accent_bg_color {pri_hex};
@define-color accent_fg_color #0b0d12;
@define-color window_bg_color {surf_hex};
@define-color window_fg_color #e6e8ee;
@define-color window_backdrop_color {surf_hex};
@define-color view_bg_color {surf_hex};
@define-color view_fg_color #e6e8ee;
@define-color view_backdrop_color {surf_hex};
@define-color headerbar_bg_color {cont_hex};
@define-color headerbar_fg_color #e6e8ee;
@define-color headerbar_backdrop_color {cont_hex};
@define-color headerbar_border_color {high_hex};
@define-color card_bg_color {cont_hex};
@define-color card_fg_color #e6e8ee;
@define-color card_backdrop_color {cont_hex};
@define-color sidebar_bg_color {cont_hex};
@define-color sidebar_fg_color #e6e8ee;
@define-color sidebar_backdrop_color {cont_hex};
@define-color sidebar_border_color {high_hex};
@define-color secondary_sidebar_bg_color {cont_hex};
@define-color secondary_sidebar_fg_color #e6e8ee;
@define-color secondary_sidebar_backdrop_color {cont_hex};
@define-color secondary_sidebar_border_color {high_hex};
@define-color popover_bg_color {cont_hex};
@define-color popover_fg_color #e6e8ee;
@define-color dialog_bg_color {cont_hex};
@define-color dialog_fg_color #e6e8ee;
@define-color theme_bg_color {cont_hex};
@define-color theme_fg_color #e6e8ee;
@define-color theme_base_color {surf_hex};
@define-color theme_text_color #e6e8ee;
@define-color theme_selected_bg_color {pri_hex};
@define-color theme_selected_fg_color #0b0d12;
@define-color insensitive_bg_color {surf_hex};
@define-color theme_unfocused_bg_color {cont_hex};
@define-color theme_unfocused_base_color {surf_hex};
@define-color theme_unfocused_selected_bg_color {pri_hex};
@define-color borders {high_hex};

:root {{
    --accent-color: {pri_hex};
    --accent-bg-color: {pri_hex};
    --accent-fg-color: #0b0d12;
    --window-bg-color: {surf_hex};
    --window-fg-color: #e6e8ee;
    --view-bg-color: {surf_hex};
    --view-fg-color: #e6e8ee;
    --headerbar-bg-color: {cont_hex};
    --headerbar-fg-color: #e6e8ee;
    --headerbar-backdrop-color: {cont_hex};
    --headerbar-border-color: {high_hex};
    --sidebar-bg-color: {cont_hex};
    --sidebar-fg-color: #e6e8ee;
    --sidebar-backdrop-color: {cont_hex};
    --sidebar-border-color: {high_hex};
    --secondary-sidebar-bg-color: {cont_hex};
    --secondary-sidebar-fg-color: #e6e8ee;
    --secondary-sidebar-backdrop-color: {cont_hex};
    --secondary-sidebar-border-color: {high_hex};
    --card-bg-color: {cont_hex};
    --card-fg-color: #e6e8ee;
    --popover-bg-color: {cont_hex};
    --popover-fg-color: #e6e8ee;
    --dialog-bg-color: {cont_hex};
    --dialog-fg-color: #e6e8ee;
}}

window, .background, window:backdrop, .background:backdrop {{
    background-color: {surf_hex} !important;
    color: #e6e8ee !important;
}}
headerbar, .titlebar, headerbar:backdrop, .titlebar:backdrop, .top-bar, .top-bar:backdrop {{
    background-color: {cont_hex} !important;
    background-image: none !important;
    color: #e6e8ee !important;
}}
.sidebar, .navigation-sidebar, .sidebar-pane, placessidebar,
navigation-split-view > .sidebar-pane, overlay-split-view > .sidebar-pane,
.sidebar-pane > scrolledwindow, .sidebar-pane > box, listview.navigation-sidebar,
.sidebar:backdrop, .navigation-sidebar:backdrop, .sidebar-pane:backdrop, placessidebar:backdrop {{
    background: {cont_hex} !important;
    background-color: {cont_hex} !important;
    background-image: none !important;
    color: #e6e8ee !important;
}}
.navigation-sidebar > row:selected, listview.navigation-sidebar > row:selected {{
    background-color: {high_hex} !important;
    color: {pri_hex} !important;
}}
"""

for gver in ("gtk-3.0", "gtk-4.0"):
    gdir = os.path.join(home, ".config", gver)
    os.makedirs(gdir, exist_ok=True)
    with open(os.path.join(gdir, "gtk.css"), "w") as f:
        f.write(gtk_css)

gtk3_theme_css = '@import url("resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained-dark.css");\n' + gtk_css
for tname in ("HySett-M3-A", "HySett-M3-B"):
    for base_root in (os.path.join(home, ".local/share/themes"), os.path.join(home, ".themes")):
        t3 = os.path.join(base_root, tname, "gtk-3.0")
        t4 = os.path.join(base_root, tname, "gtk-4.0")
        os.makedirs(t3, exist_ok=True)
        os.makedirs(t4, exist_ok=True)
        with open(os.path.join(t3, "gtk.css"), "w") as f:
            f.write(gtk3_theme_css)
        with open(os.path.join(t3, "gtk-dark.css"), "w") as f:
            f.write(gtk3_theme_css)
        with open(os.path.join(t4, "gtk.css"), "w") as f:
            f.write(gtk_css)
        with open(os.path.join(t4, "gtk-dark.css"), "w") as f:
            f.write(gtk_css)

# 5. Полное окрашивание Firefox (с поддержкой живых системных токенов AccentColor / -moz-dialog / -moz-field)
ctrl_r = int(float(conf.get("m3_control_radius", "12"))) if is_rounded else 0
card_r = int(float(conf.get("m3_card_radius", "16"))) if is_rounded else 0

ff_chrome_css = f"""/* HySett Material Design 3 Live Dynamic Firefox UI */
:root, #main-window, #navigator-toolbox, #TabsToolbar, #nav-bar, #PersonalToolbar, #sidebar-box, #tabbrowser-tabpanels, panel, menupopup {{
    --hs-pri: AccentColor;
    --hs-surf: -moz-field;
    --hs-cont: -moz-dialog;
    --hs-high: color-mix(in srgb, -moz-dialog 76%, AccentColor 24%);
    --toolbar-bgcolor: var(--hs-cont) !important;
    --toolbar-color: #e6e8ee !important;
    --lwt-accent-color: var(--hs-surf) !important;
    --lwt-accent-color-inactive: var(--hs-surf) !important;
    --lwt-text-color: #e6e8ee !important;
    --lwt-toolbar-field-background-color: var(--hs-surf) !important;
    --lwt-toolbar-field-color: #e6e8ee !important;
    --lwt-toolbar-field-focus: var(--hs-surf) !important;
    --lwt-toolbar-field-border-color: transparent !important;
    --lwt-selected-tab-background-color: var(--hs-high) !important;
    --tab-selected-bgcolor: var(--hs-high) !important;
    --tab-selected-textcolor: var(--hs-pri) !important;
    --tab-border-radius: {ctrl_r}px !important;
    --tabpanel-background-color: var(--hs-surf) !important;
    --urlbar-box-bgcolor: var(--hs-surf) !important;
    --urlbar-box-focus-bgcolor: var(--hs-surf) !important;
    --urlbar-box-hover-bgcolor: var(--hs-high) !important;
    --toolbar-field-background-color: var(--hs-surf) !important;
    --toolbar-field-focus-background-color: var(--hs-surf) !important;
    --toolbar-field-color: #e6e8ee !important;
    --toolbar-field-focus-color: #ffffff !important;
    --toolbar-field-border-color: transparent !important;
    --focus-outline-color: var(--hs-pri) !important;
    --arrowpanel-background: var(--hs-cont) !important;
    --arrowpanel-color: #e6e8ee !important;
    --arrowpanel-border-color: var(--hs-high) !important;
    --arrowpanel-border-radius: {card_r}px !important;
    --panel-background: var(--hs-cont) !important;
    --panel-color: #e6e8ee !important;
    --panel-border-color: var(--hs-high) !important;
    --sidebar-background-color: var(--hs-surf) !important;
    --sidebar-text-color: #e6e8ee !important;
    --sidebar-border-color: var(--hs-high) !important;
    --toolbarbutton-border-radius: {ctrl_r}px !important;
    --toolbarbutton-hover-background: var(--hs-high) !important;
    --toolbarbutton-active-background: color-mix(in srgb, AccentColor 25%, transparent) !important;
    --toolbarbutton-icon-fill: #e6e8ee !important;
    --toolbarbutton-icon-fill-attention: var(--hs-pri) !important;
}}
#main-window, #navigator-toolbox, #TabsToolbar, #titlebar, #TabsToolbar-customization-target,
#main-window:-moz-window-inactive, #navigator-toolbox:-moz-window-inactive {{
    background: var(--hs-surf) !important;
    background-color: var(--hs-surf) !important;
    background-image: none !important;
    color: #e6e8ee !important;
    border: none !important;
    box-shadow: none !important;
}}
#nav-bar, #PersonalToolbar, #PlacesToolbar, .browser-toolbar:not(#TabsToolbar), findbar,
#nav-bar:-moz-window-inactive, #PersonalToolbar:-moz-window-inactive {{
    background: var(--hs-cont) !important;
    background-color: var(--hs-cont) !important;
    background-image: none !important;
    color: #e6e8ee !important;
    border: none !important;
    box-shadow: none !important;
}}
#PersonalToolbar toolbarbutton.bookmark-item, #PlacesToolbarItems > .bookmark-item {{
    color: #e6e8ee !important;
    border-radius: {ctrl_r}px !important;
    background: transparent !important;
    border: none !important;
}}
#PersonalToolbar toolbarbutton.bookmark-item:hover {{
    background-color: var(--hs-high) !important;
    color: var(--hs-pri) !important;
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
    background-color: var(--hs-cont) !important;
}}
.tab-background:is([selected], [multiselected]), .tab-background[selected="true"] {{
    background: var(--hs-high) !important;
    background-color: var(--hs-high) !important;
    background-image: none !important;
    border: 1px solid color-mix(in srgb, AccentColor 38%, transparent) !important;
    box-shadow: none !important;
}}
.tabbrowser-tab:not([selected]) .tab-label {{
    color: #b8bece !important;
}}
.tabbrowser-tab[selected] .tab-label {{
    color: var(--hs-pri) !important;
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
    background: var(--hs-surf) !important;
    background-color: var(--hs-surf) !important;
    background-image: none !important;
    border: 1px solid var(--hs-high) !important;
    border-radius: {max(ctrl_r, 14) if is_rounded else 0}px !important;
    box-shadow: none !important;
    outline: none !important;
}}
#urlbar[focused="true"] > #urlbar-background {{
    border-color: var(--hs-pri) !important;
    box-shadow: none !important;
}}
#urlbar[breakout][breakout-extend] > #urlbar-background {{
    border-radius: {card_r}px !important;
    background-color: var(--hs-cont) !important;
    border-color: var(--hs-pri) !important;
}}
.urlbarView, .urlbarView-body-outer, .urlbarView-body-inner, #PopupAutoComplete, .autocomplete-richlistbox {{
    background: transparent !important;
    color: #e6e8ee !important;
    border: none !important;
}}
.urlbarView-row {{
    border-radius: {ctrl_r}px !important;
}}
.urlbarView-row[selected], .urlbarView-row:hover {{
    background-color: var(--hs-high) !important;
    color: var(--hs-pri) !important;
}}
menupopup, panel, .panel-subview-body, .menupopup-arrowscrollbox {{
    background: var(--hs-cont) !important;
    background-color: var(--hs-cont) !important;
    color: #e6e8ee !important;
    border-radius: {card_r}px !important;
    border: 1px solid var(--hs-high) !important;
}}
menuitem, menu {{
    border-radius: {max(0, ctrl_r - 4)}px !important;
}}
menuitem:hover, menu:hover, menuitem[_moz-menuactive="true"], menu[_moz-menuactive="true"] {{
    background-color: var(--hs-high) !important;
    color: var(--hs-pri) !important;
}}
#sidebar-box, #sidebar-header, #sidebar {{
    background-color: var(--hs-surf) !important;
    color: #e6e8ee !important;
    border: none !important;
}}
#statuspanel-label {{
    background-color: var(--hs-cont) !important;
    color: var(--hs-pri) !important;
    border: 1px solid var(--hs-high) !important;
    border-radius: {max(0, ctrl_r - 4)}px !important;
}}
#tabbrowser-tabpanels, browser[type="content"] {{
    background-color: var(--hs-surf) !important;
}}
"""

ff_content_css = f"""/* HySett Material Design 3 Live NewTab Theme */
@-moz-document url-prefix("about:newtab"), url-prefix("about:home"), url-prefix("about:blank"), url-prefix("about:privatebrowsing") {{
    :root, html, body, #root, .outer-wrapper {{
        --hs-pri: AccentColor;
        --hs-surf: -moz-field;
        --hs-cont: -moz-dialog;
        --hs-high: color-mix(in srgb, -moz-dialog 76%, AccentColor 24%);
        --newtab-background-color: var(--hs-surf) !important;
        --newtab-background-color-secondary: var(--hs-cont) !important;
        --newtab-primary-action-background: var(--hs-pri) !important;
        --newtab-text-primary-color: #e6e8ee !important;
        background: var(--hs-surf) !important;
        background-color: var(--hs-surf) !important;
        color: #e6e8ee !important;
    }}
    .search-wrapper, .search-inner-wrapper {{
        background: transparent !important;
        border: none !important;
        box-shadow: none !important;
    }}
    .search-wrapper .search-handoff-button, .search-wrapper input {{
        background-color: var(--hs-cont) !important;
        color: #e6e8ee !important;
        border: 1px solid var(--hs-high) !important;
        border-radius: {24 if is_rounded else 0}px !important;
        box-shadow: none !important;
    }}
    .top-site-outer .tile, .card-outer {{
        background-color: var(--hs-cont) !important;
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
    "browser.display.background_color": f'"{surf_hex}"',
    "extensions.activeThemeID": '"default-theme@mozilla.org"',
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
            filtered = [ln for ln in lines if not any(f'"{k}"' in ln for k in req_prefs)]
            for k, v in req_prefs.items():
                filtered.append(f'user_pref("{k}", {v});')
            with open(p_path, "w") as f:
                f.write("\n".join(filtered) + "\n")

open(os.path.join(home, ".cache/ff_theme_dirty"), "w").write(pri_hex)

# 5b. Google Chrome / Chromium
chrome_seed = (0xFF << 24) | (int(pri[0]) << 16) | (int(pri[1]) << 8) | int(pri[2])
if chrome_seed >= 0x80000000:
    chrome_seed -= 0x100000000
for cprof in glob.glob(os.path.join(home, ".config/google-chrome/*/Preferences")) + glob.glob(os.path.join(home, ".config/chromium/*/Preferences")):
    try:
        cdata = json.loads(open(cprof, errors="ignore").read())
        cdata.setdefault("browser", {}).setdefault("theme", {})["color_scheme2"] = 2
        cdata["browser"]["theme"]["user_color2"] = chrome_seed
        cdata["browser"]["theme"]["color_variant2"] = 1
        cdata.setdefault("extensions", {}).setdefault("theme", {})["id"] = ""
        cdata["extensions"]["theme"]["use_system"] = False
        with open(cprof, "w") as cf:
            json.dump(cdata, cf)
    except Exception:
        pass

# 6. Папки Papirus и живое переключение GTK-темы (HySett-M3-A <-> HySett-M3-B)
papirus_src = "/usr/share/icons/Papirus/64x64/places"
if os.path.isdir(papirus_src):
    for ivar in ("HySett-Papirus-A", "HySett-Papirus-B"):
        idir = os.path.join(home, ".local/share/icons", ivar)
        p64 = os.path.join(idir, "64x64/places")
        os.makedirs(p64, exist_ok=True)
        for svg_file in glob.glob(os.path.join(papirus_src, "*.svg")):
            bname = os.path.basename(svg_file)
            if not (bname.startswith("folder") or bname.startswith("user-")):
                continue
            if any(x in bname for x in ("-blue-", "-red", "-green", "-yellow", "-grey", "-orange", "-violet", "-cyan")):
                continue
            try:
                raw_svg = open(svg_file, errors="ignore").read()
                recolored = (raw_svg
                             .replace("#5294e2", pri_hex)
                             .replace("#4877b1", folder_back_hex)
                             .replace("#1d344f", surf_hex)
                             .replace("#e4e4e4", surf_hex)
                             .replace("#ffffff", surf_hex))
                with open(os.path.join(p64, bname), "w") as out_f:
                    out_f.write(recolored)
            except Exception:
                pass
        subprocess.run(["gtk-update-icon-cache", "-f", "-t", idir], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

try:
    cur_gtk = subprocess.check_output(["gsettings", "get", "org.gnome.desktop.interface", "gtk-theme"], stderr=subprocess.DEVNULL).decode().strip().strip("'")
    next_gtk = "HySett-M3-B" if cur_gtk == "HySett-M3-A" else "HySett-M3-A"
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", next_gtk], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", "prefer-dark"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if os.path.isdir(papirus_src):
        cur_ico = subprocess.check_output(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"], stderr=subprocess.DEVNULL).decode().strip().strip("'")
        next_ico = "HySett-Papirus-B" if cur_ico == "HySett-Papirus-A" else "HySett-Papirus-A"
        subprocess.run(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", next_ico], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
except Exception:
    pass

# 7. Обновление фонового демона Nautilus только если окно проводника закрыто
try:
    clients = json.loads(subprocess.check_output(["hyprctl", "clients", "-j"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore"))
    naut_wins = [c for c in clients if "nautilus" in str(c.get("class", "")).lower() and int(c.get("workspace", {}).get("id", 0)) > 0]
    if not naut_wins:
        subprocess.Popen("pkill -9 -x nautilus 2>/dev/null; sleep 0.08; nautilus --gapplication-service >/dev/null 2>&1 &", shell=True)
except Exception:
    pass

# 8. Живой пакет темы для AyuGram
def make_solid_png(r, g, b, w=64, h=64):
    raw = b"".join(b"\x00" + bytes([int(r), int(g), int(b)]) * w for _ in range(h))
    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xffffffff)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(raw)) + chunk(b"IEND", b"")

ayu_palette = f"""windowBg: {ayu_surf_hex};
windowFg: #e6e8ee;
windowBgOver: {ayu_cont_hex};
windowBgRipple: {ayu_high_hex};
windowFgOver: #ffffff;
windowSubTextFg: #8b919e;
windowSubTextFgOver: #b8bece;
windowBoldFg: #ffffff;
windowBoldFgOver: #ffffff;
windowBgActive: {ayu_pri_hex};
windowFgActive: #07090c;
windowActiveTextFg: {ayu_pri_hex};
dialogsBg: {ayu_surf_hex};
dialogsNameFg: #e6e8ee;
dialogsTextFg: #8b919e;
dialogsDateFg: #6c7280;
dialogsBgOver: {ayu_cont_hex};
dialogsBgActive: {ayu_high_hex};
dialogsNameFgActive: {ayu_pri_hex};
dialogsTextFgActive: #e6e8ee;
dialogsUnreadBg: {ayu_pri_hex};
dialogsUnreadFg: #07090c;
historyComposeAreaBg: {ayu_cont_hex};
historyComposeAreaFg: #e6e8ee;
msgInBg: {ayu_cont_hex};
msgInBgSelected: {ayu_high_hex};
msgOutBg: {ayu_high_hex};
msgOutBgSelected: {ayu_pri_hex}44;
activeButtonBg: {ayu_pri_hex};
activeButtonBgOver: {ayu_pri_hex};
activeButtonFg: #07090c;
lightButtonBg: {ayu_cont_hex};
lightButtonBgOver: {ayu_high_hex};
lightButtonFg: {ayu_pri_hex};
titleBg: {ayu_surf_hex};
titleBgActive: {ayu_cont_hex};
titleFg: #8b919e;
titleFgActive: #ffffff;
trayCounterBg: {ayu_pri_hex};
trayCounterFg: #07090c;
"""

zip_buf = io.BytesIO()
with zipfile.ZipFile(zip_buf, "w", zipfile.ZIP_DEFLATED) as zf:
    zf.writestr("colors.tdesktop-palette", ayu_palette)
    zf.writestr("colors.tdesktop-theme", ayu_palette)
    zf.writestr("background.png", make_solid_png(*ayu_surf_rgb))
zip_bytes = zip_buf.getvalue()

for tpath in (
    os.path.join(home, "hysett_ayugram.tdesktop-theme"),
    os.path.join(home, ".cache/hysett_ayugram.tdesktop-theme"),
):
    try:
        with open(tpath, "wb") as f:
            f.write(zip_bytes)
            f.flush()
    except Exception:
        pass

ayu_tdata = os.path.join(home, ".local/share/AyuGramDesktop/tdata")
if os.path.isdir(ayu_tdata):
    edit_pal = os.path.join(ayu_tdata, "editing-theme.tdesktop-palette")
    if os.path.exists(edit_pal):
        try:
            with open(edit_pal, "w", encoding="utf-8") as f:
                f.write(ayu_palette)
                f.flush()
        except Exception:
            pass
