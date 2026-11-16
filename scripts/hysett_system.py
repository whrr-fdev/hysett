#!/usr/bin/env python3
import sys, os, json, time, tarfile, shutil, subprocess, datetime, urllib.request

HOME = os.path.expanduser("~")
HYSETT_DIR = os.path.expanduser("~/hysett")
CONF_FILE = os.path.expanduser("~/.config/hypr/scripts/control_center.conf")
PROG_FILE = "/tmp/hysett_sys_progress.json"

HYPR_CORE_PKGS = [
    "hyprland", "xdg-desktop-portal-hyprland", "qt6-base", "qt6-declarative",
    "qt6-QuickControls2", "qt6-shadertools", "qt6-wayland", "layer-shell-qt",
    "kitty", "fish", "btop", "sing-box", "mpv", "wl-clipboard", "cliphist",
    "polkit-kde-agent", "networkmanager", "bluez", "bluez-utils", "pipewire",
    "wireplumber", "pipewire-pulse", "scrcpy", "android-tools", "qrencode", "udisks2"
]

def write_prog(busy, pct, text):
    try:
        tmp = PROG_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"busy": bool(busy), "percent": int(pct), "text": str(text), "ts": time.time()}, f, ensure_ascii=False)
        os.replace(tmp, PROG_FILE)
    except Exception:
        pass

def get_conf_val(key, default_val):
    if os.path.exists(CONF_FILE):
        try:
            for ln in open(CONF_FILE, "r", encoding="utf-8", errors="ignore"):
                if ln.strip().startswith(key + "="):
                    v = ln.strip().split("=", 1)[1].strip()
                    if v:
                        return os.path.expanduser(v)
        except Exception:
            pass
    return os.path.expanduser(default_val)

def get_backups_dir():
    d = get_conf_val("backups_dir", os.path.join(HYSETT_DIR, "backups", "archives"))
    os.makedirs(d, exist_ok=True)
    return d

def get_wallpapers_dir():
    return get_conf_val("wallpapers_dir", "~/Pictures/Wallpapers")

def get_music_dir():
    return get_conf_val("music_dir", "~/Music/YandexMusic")

def get_pkg_lists():
    native, aur = [], []
    try:
        out_n = subprocess.check_output(["pacman", "-Qqen"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        native = [x.strip() for x in out_n.splitlines() if x.strip()]
    except Exception:
        pass
    try:
        out_m = subprocess.check_output(["pacman", "-Qqem"], stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore")
        aur = [x.strip() for x in out_m.splitlines() if x.strip()]
    except Exception:
        pass
    return native, aur

def build_install_script_text(native, aur):
    merged_native = list(dict.fromkeys(HYPR_CORE_PKGS + native))
    lines = [
        "#!/usr/bin/env bash",
        "# Автономный скрипт развертывания Hyprland, окружения HySett и всех пакетов системы",
        "set -e",
        'echo "==> [1/3] Установка базового окружения Hyprland и официальных пакетов (pacman)..."',
        "sudo pacman -Syu --needed --noconfirm \\",
    ]
    for i, p in enumerate(merged_native):
        end = " \\" if i < len(merged_native) - 1 else ""
        lines.append(f"  {p}{end}")
    if aur:
        lines.extend([
            "",
            'if command -v paru >/dev/null 2>&1; then',
            '    AUR_HELPER="paru"',
            'elif command -v yay >/dev/null 2>&1; then',
            '    AUR_HELPER="yay"',
            'else',
            '    echo "==> [2/3] Установка paru для докачки пакетов из AUR..."',
            '    sudo pacman -S --needed --noconfirm base-devel git',
            '    rm -rf /tmp/paru-bin',
            '    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && (cd /tmp/paru-bin && makepkg -si --noconfirm)',
            '    AUR_HELPER="paru"',
            'fi',
            'echo "==> [3/3] Докачка всех пакетов из AUR ($AUR_HELPER)..."',
            '$AUR_HELPER -S --needed --noconfirm \\',
        ])
        for i, p in enumerate(aur):
            end = " \\" if i < len(aur) - 1 else ""
            lines.append(f"  {p}{end}")
    lines.append('\necho "==> Hyprland и все пакеты системы успешно установлены! ✓"')
    return "\n".join(lines) + "\n"

def detect_archive_kind(fn):
    low = fn.lower()
    if "_data_" in low or "data_backup" in low:
        return "data", "ЛИЧНЫЕ ДАННЫЕ"
    if "_settings_" in low or "settings_backup" in low:
        return "settings", "НАСТРОЙКИ + ПАКЕТЫ"
    return "full", "ПОЛНЫЙ (ВСЁ ВМЕСТЕ)"


def get_git_credentials():
    cred_path = os.path.expanduser("~/.git-credentials")
    if os.path.exists(cred_path):
        try:
            with open(cred_path, "r", encoding="utf-8", errors="ignore") as f:
                for ln in f:
                    ln = ln.strip()
                    if "@github.com" in ln and ln.startswith("https://"):
                        body = ln.split("https://", 1)[1].split("@github.com", 1)[0]
                        if ":" in body:
                            u, t = body.split(":", 1)
                            return u, t
        except Exception:
            pass
    return "", ""

def normalize_repo_slug(raw_repo, default_user):
    r = (raw_repo or "").strip()
    r = r.replace("https://github.com/", "").replace("http://github.com/", "").replace("git@github.com:", "")
    if r.endswith(".git"):
        r = r[:-4]
    r = r.strip("/")
    if not r:
        return ""
    if "/" not in r and default_user:
        return f"{default_user}/{r}"
    return r

def cmd_git_login(username, token):
    username = (username or "").strip()
    token = (token or "").strip()
    if not token:
        write_prog(False, 0, "Введите токен GitHub (Personal Access Token)")
        cmd_info()
        return

    write_prog(True, 30, "Проверка токена через GitHub API...")
    try:
        req = urllib.request.Request(
            "https://api.github.com/user",
            headers={"Authorization": f"token {token}", "User-Agent": "HySett-Git-Auth"}
        )
        with urllib.request.urlopen(req, timeout=10) as resp:
            udata = json.loads(resp.read().decode("utf-8", errors="ignore"))
            api_login = udata.get("login", "")
            if api_login:
                username = api_login
    except Exception as e:
        write_prog(False, 0, f"Ошибка авторизации GitHub: неверный токен ({e})")
        cmd_info()
        return

    if not username:
        write_prog(False, 0, "Не удалось определить логин GitHub")
        cmd_info()
        return

    cred_path = os.path.expanduser("~/.git-credentials")
    lines = []
    if os.path.exists(cred_path):
        with open(cred_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = [l.strip() for l in f if l.strip() and "@github.com" not in l]
    lines.append(f"https://{username}:{token}@github.com")
    with open(cred_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
    os.chmod(cred_path, 0o600)

    subprocess.run(["git", "config", "--global", "credential.helper", "store"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "config", "--global", "user.name", username], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "config", "--global", "user.email", f"{username}@users.noreply.github.com"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    write_prog(False, 100, f"Успешный вход в GitHub: {username} ✓")
    cmd_info()

def ensure_github_repo_exists(slug, token, is_private=True):
    if "/" not in slug or not token:
        return
    owner, repo_name = slug.split("/", 1)
    headers = {
        "Authorization": f"token {token}",
        "Accept": "application/vnd.github+json",
        "User-Agent": "HySett-Git-Sync"
    }
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{slug}", headers=headers)
        urllib.request.urlopen(req, timeout=8)
        return
    except Exception:
        pass
    try:
        payload = json.dumps({
            "name": repo_name,
            "description": "Hyprland & HySett system configurations backup",
            "private": bool(is_private),
            "auto_init": False
        }).encode("utf-8")
        req = urllib.request.Request("https://api.github.com/user/repos", data=payload, headers={**headers, "Content-Type": "application/json"}, method="POST")
        urllib.request.urlopen(req, timeout=12)
    except Exception:
        pass

def cmd_git_push_configs(raw_repo, is_private=True):
    g_user, g_tok = get_git_credentials()
    slug = normalize_repo_slug(raw_repo, g_user)
    if not slug or "/" not in slug:
        write_prog(False, 0, "Укажите репозиторий (например: username/dotfiles или имя репозитория)")
        cmd_info()
        return

    write_prog(True, 15, f"Подготовка репозитория {slug} на GitHub...")
    if g_tok:
        ensure_github_repo_exists(slug, g_tok, is_private)

    export_dir = "/tmp/hysett_git_export"
    shutil.rmtree(export_dir, ignore_errors=True)
    os.makedirs(export_dir, exist_ok=True)

    write_prog(True, 40, "Сбор всех конфигов Hyprland, Kitty, Fish, Btop, курсоров и списков пакетов...")
    native, aur = get_pkg_lists()
    stage_settings_part(export_dir, native, aur)

    readme_p = os.path.join(export_dir, "README.md")
    with open(readme_p, "w", encoding="utf-8") as rf:
        rf.write(f"# Dotfiles & HySett Backup ({slug})\n\nАвтоматический слепок конфигураций Hyprland, Kitty, Fish, Btop, GTK, курсоров и пакетов (`pacman`: {len(native)}, `AUR`: {len(aur)}).\n\n## Развертывание на новом ПК в 1 команду\n```bash\ngit clone https://github.com/{slug}.git ~/dotfiles && bash ~/dotfiles/bootstrap_new_pc.sh\n```\n")

    write_prog(True, 75, f"Выгрузка (git push) конфигураций в https://github.com/{slug}...")
    remote_url = f"https://{g_user}:{g_tok}@github.com/{slug}.git" if (g_user and g_tok) else f"https://github.com/{slug}.git"

    subprocess.run(["git", "init", "-b", "main"], cwd=export_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "add", "-A"], cwd=export_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    ts = datetime.datetime.now().strftime("%d.%m.%Y %H:%M")
    subprocess.run(["git", "commit", "-m", f"backup: sync HySett & Hyprland configs ({ts})"], cwd=export_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "remote", "add", "origin", remote_url], cwd=export_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    r = subprocess.run(["git", "push", "-f", "origin", "HEAD:refs/heads/main"], cwd=export_dir, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)

    shutil.rmtree(export_dir, ignore_errors=True)
    if r.returncode == 0:
        write_prog(False, 100, f"Все конфиги успешно выгружены в GitHub: {slug} ✓")
    else:
        err = r.stderr.decode("utf-8", errors="ignore").strip().splitlines()[-1] if r.stderr else "проверьте доступ"
        write_prog(False, 0, f"Ошибка git push в {slug}: {err}")
    cmd_info()

def cmd_git_pull_configs(raw_repo, with_pkgs=False):
    g_user, g_tok = get_git_credentials()
    slug = normalize_repo_slug(raw_repo, g_user)
    if not slug or "/" not in slug:
        write_prog(False, 0, "Укажите репозиторий для клонирования (например: username/dotfiles)")
        cmd_info()
        return

    write_prog(True, 25, f"Клонирование конфигураций из https://github.com/{slug}...")
    clone_dir = "/tmp/hysett_git_import"
    shutil.rmtree(clone_dir, ignore_errors=True)
    remote_url = f"https://{g_user}:{g_tok}@github.com/{slug}.git" if (g_user and g_tok) else f"https://github.com/{slug}.git"

    r = subprocess.run(["git", "clone", "--depth=1", remote_url, clone_dir], stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=60)
    if r.returncode != 0:
        shutil.rmtree(clone_dir, ignore_errors=True)
        write_prog(False, 0, f"Не удалось склонировать {slug}. Проверьте имя репозитория и доступ.")
        cmd_info()
        return

    write_prog(True, 65, "Применение конфигураций из Git-репозитория...")
    if os.path.exists(os.path.join(clone_dir, "config")):
        restore_settings_from_root(clone_dir)
    else:
        for cname in ("hypr", "kitty", "fish", "btop", "gtk-3.0", "gtk-4.0"):
            s = os.path.join(clone_dir, cname)
            if os.path.isdir(s):
                shutil.copytree(s, os.path.join(HOME, ".config", cname), dirs_exist_ok=True)

    pkg_sh = os.path.join(clone_dir, "install_packages.sh")
    if with_pkgs and os.path.exists(pkg_sh):
        write_prog(True, 90, "Запуск установки Hyprland и пакетов из репозитория...")
        launch_pkg_installer_in_terminal(pkg_sh)

    shutil.rmtree(clone_dir, ignore_errors=True)
    subprocess.Popen(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    write_prog(False, 100, f"Конфиги из репозитория {slug} успешно восстановлены ✓")
    cmd_info()

def cmd_info():
    native, aur = get_pkg_lists()
    bdir = get_backups_dir()
    archives = []
    if os.path.exists(bdir):
        for fn in sorted(os.listdir(bdir), reverse=True):
            if fn.endswith((".tar.gz", ".tgz", ".tar.zst")):
                fp = os.path.join(bdir, fn)
                sz_mb = os.path.getsize(fp) / (1024.0 * 1024.0)
                mt = datetime.datetime.fromtimestamp(os.path.getmtime(fp)).strftime("%d.%m.%Y %H:%M")
                kind_code, kind_label = detect_archive_kind(fn)
                archives.append({
                    "name": fn,
                    "path": fp,
                    "size": f"{sz_mb:.1f} MB",
                    "date": mt,
                    "kind": kind_code,
                    "badge": kind_label
                })
    local_ver = "main"
    try:
        h = subprocess.check_output(["git", "-C", HYSETT_DIR, "rev-parse", "--short", "HEAD"], stderr=subprocess.DEVNULL).decode().strip()
        dt = subprocess.check_output(["git", "-C", HYSETT_DIR, "log", "-1", "--format=%cd", "--date=format:%d.%m.%Y %H:%M"], stderr=subprocess.DEVNULL).decode().strip()
        local_ver = f"{h} ({dt})"
    except Exception:
        pass
    print(json.dumps({
        "native_count": len(native),
        "aur_count": len(aur),
        "backups_dir": bdir,
        "archives": archives,
        "local_version": local_ver,
        "git_user": get_git_credentials()[0]
    }, ensure_ascii=False))

def cmd_gen_pkg_script():
    write_prog(True, 25, "Сбор списка установленных пакетов pacman, AUR и зависимостей Hyprland...")
    native, aur = get_pkg_lists()
    bdir = get_backups_dir()
    script_txt = build_install_script_text(native, aur)
    out1 = os.path.join(bdir, "install_my_packages.sh")
    out2 = os.path.join(HOME, "install_my_packages.sh")
    for p in (out1, out2):
        with open(p, "w", encoding="utf-8") as f:
            f.write(script_txt)
        os.chmod(p, 0o755)
    write_prog(False, 100, f"Скрипт готов: ~/install_my_packages.sh (Pacman: {len(native)}, AUR: {len(aur)}) ✓")
    cmd_info()

def stage_settings_part(stage_dir, native, aur):
    with open(os.path.join(stage_dir, "pkglist_native.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(native) + "\n")
    with open(os.path.join(stage_dir, "pkglist_aur.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(aur) + "\n")
    inst_sh = os.path.join(stage_dir, "install_packages.sh")
    with open(inst_sh, "w", encoding="utf-8") as f:
        f.write(build_install_script_text(native, aur))
    os.chmod(inst_sh, 0o755)

    bootstrap_sh = os.path.join(stage_dir, "bootstrap_new_pc.sh")
    with open(bootstrap_sh, "w", encoding="utf-8") as f:
        f.write("""#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> [1/4] Установка Hyprland и всех пакетов системы..."
bash "$DIR/install_packages.sh"
echo "==> [2/4] Восстановление конфигураций Hyprland, Kitty, Fish, Btop, GTK и курсоров..."
mkdir -p ~/.config ~/.local/share
[ -d "$DIR/config" ] && cp -rf "$DIR/config/"* ~/.config/
[ -d "$DIR/local_share/icons" ] && cp -rf "$DIR/local_share/icons" ~/.local/share/
echo "==> [3/4] Установка и сборка HySett..."
if [ ! -d ~/hysett/.git ]; then
    git clone https://github.com/whrr-fdev/hysett.git ~/hysett || true
fi
[ -d "$DIR/hysett_data/scripts" ] && mkdir -p ~/hysett && cp -rf "$DIR/hysett_data/scripts" ~/hysett/
[ -d "$DIR/hysett_data/widgets" ] && mkdir -p ~/hysett && cp -rf "$DIR/hysett_data/widgets" ~/hysett/
if [ -d ~/hysett ]; then
    cmake -B ~/hysett/build -S ~/hysett
    cmake --build ~/hysett/build -j$(nproc)
fi
echo "==> [4/4] Готово! Перезапустите сессию в Hyprland ✓"
""")
    os.chmod(bootstrap_sh, 0o755)

    cfg_stage = os.path.join(stage_dir, "config")
    os.makedirs(cfg_stage, exist_ok=True)
    for cname in ("hypr", "kitty", "fish", "btop", "gtk-3.0", "gtk-4.0"):
        src_c = os.path.join(HOME, ".config", cname)
        if os.path.exists(src_c):
            shutil.copytree(
                src_c,
                os.path.join(cfg_stage, cname),
                symlinks=False,
                ignore_dangling_symlinks=True,
                ignore=shutil.ignore_patterns("*.sock", "*.lock", "singbox_vpn.json", "*.bak*"),
                dirs_exist_ok=True
            )

    icons_src = os.path.join(HOME, ".local", "share", "icons")
    if os.path.exists(icons_src):
        loc_stage = os.path.join(stage_dir, "local_share", "icons")
        os.makedirs(loc_stage, exist_ok=True)
        shutil.copytree(icons_src, loc_stage, symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    hs_stage = os.path.join(stage_dir, "hysett_data")
    os.makedirs(hs_stage, exist_ok=True)
    for sub in ("scripts", "widgets"):
        s_dir = os.path.join(HYSETT_DIR, sub)
        if os.path.exists(s_dir):
            shutil.copytree(
                s_dir,
                os.path.join(hs_stage, sub),
                symlinks=False,
                ignore_dangling_symlinks=True,
                ignore=shutil.ignore_patterns("singbox_vpn.json", "*.bak*"),
                dirs_exist_ok=True
            )

def stage_data_part(stage_dir):
    data_stage = os.path.join(stage_dir, "user_data")
    os.makedirs(data_stage, exist_ok=True)

    # 1. Музыка и плейлисты Яндекс.Музыки
    mus_dir = get_music_dir()
    if os.path.exists(mus_dir):
        shutil.copytree(mus_dir, os.path.join(data_stage, "music"), symlinks=False, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    # 2. Обои
    wall_dir = get_wallpapers_dir()
    if os.path.exists(wall_dir):
        shutil.copytree(wall_dir, os.path.join(data_stage, "wallpapers"), symlinks=False, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    # 3. Токены, подписки VPN, облачные ссылки, пресеты
    secrets_dir = os.path.join(data_stage, "secrets")
    os.makedirs(secrets_dir, exist_ok=True)
    secret_files = [
        (os.path.join(HOME, ".config", "hysett_vpn_sub.txt"), "hysett_vpn_sub.txt"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "vpn_wl_subs.txt"), "vpn_wl_subs.txt"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "vpn_custom_domains.json"), "vpn_custom_domains.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "vpn_state.json"), "vpn_state.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "ym_token.txt"), "ym_token.txt"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "ym_excluded_playlists.json"), "ym_excluded_playlists.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "web_share_cloud.json"), "web_share_cloud.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "stashed_files.json"), "stashed_files.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "presets.json"), "presets.json"),
        (os.path.join(HOME, ".config", "hypr", "scripts", "last_wallpaper.conf"), "last_wallpaper.conf"),
    ]
    for src_f, dst_name in secret_files:
        if os.path.exists(src_f) and os.path.isfile(src_f):
            shutil.copy2(src_f, os.path.join(secrets_dir, dst_name))

    # 4. Файлы, принятые с телефона
    ph_dir = os.path.expanduser("~/Downloads/PhoneTransfer")
    if os.path.exists(ph_dir):
        shutil.copytree(ph_dir, os.path.join(data_stage, "phone_transfer"), symlinks=False, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    # 5. Пользовательские шрифты
    fonts_dir = os.path.expanduser("~/.local/share/fonts")
    if os.path.exists(fonts_dir):
        shutil.copytree(fonts_dir, os.path.join(data_stage, "fonts"), symlinks=False, ignore_dangling_symlinks=True, dirs_exist_ok=True)

def cmd_create_backup(mode="full"):
    mode = (mode or "full").strip().lower()
    if mode not in ("settings", "data", "full"):
        mode = "full"

    native, aur = get_pkg_lists()
    bdir = get_backups_dir()
    ts = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")

    if mode == "settings":
        archive_name = f"hysett_settings_backup_{ts}.tar.gz"
        title_msg = "Архив настроек, Hyprland и пакетов"
    elif mode == "data":
        archive_name = f"hysett_data_backup_{ts}.tar.gz"
        title_msg = "Архив личных данных (Музыка, Обои, VPN)"
    else:
        archive_name = f"hysett_full_backup_{ts}.tar.gz"
        title_msg = "Полный архив системы (Настройки + Данные + Пакеты)"

    archive_path = os.path.join(bdir, archive_name)
    stage_dir = "/tmp/hysett_backup_stage"
    shutil.rmtree(stage_dir, ignore_errors=True)
    os.makedirs(stage_dir, exist_ok=True)

    with open(os.path.join(stage_dir, "backup_meta.json"), "w", encoding="utf-8") as mf:
        json.dump({"mode": mode, "timestamp": ts, "native_count": len(native), "aur_count": len(aur)}, mf, ensure_ascii=False)

    if mode in ("settings", "full"):
        write_prog(True, 25, "Упаковка настроек Hyprland, Kitty, Fish, курсоров и списков пакетов...")
        stage_settings_part(stage_dir, native, aur)

    if mode in ("data", "full"):
        write_prog(True, 55, "Упаковка личных данных (Музыка, Обои, подписки VPN, шрифты)...")
        stage_data_part(stage_dir)

    write_prog(True, 85, f"Сжатие архива {archive_name}...")
    with tarfile.open(archive_path, "w:gz") as tar:
        for item in os.listdir(stage_dir):
            tar.add(os.path.join(stage_dir, item), arcname=item)

    shutil.rmtree(stage_dir, ignore_errors=True)
    write_prog(False, 100, f"{title_msg} создан: {archive_name} ✓")
    cmd_info()

def launch_pkg_installer_in_terminal(script_path):
    tmp_run = "/tmp/hysett_restore_pkgs.sh"
    shutil.copy2(script_path, tmp_run)
    os.chmod(tmp_run, 0o755)
    for term_cmd in [
        ["kitty", "--title", "HySett • Установка Hyprland и пакетов", "-e", "bash", "-c", f"{tmp_run}; echo ''; read -p 'Готово! Нажмите Enter для закрытия...'"],
        ["foot", "bash", "-c", f"{tmp_run}; read -p 'Enter...'"],
        ["alacritty", "-e", "bash", "-c", f"{tmp_run}; read -p 'Enter...'"],
        ["xterm", "-e", "bash", "-c", f"{tmp_run}; read -p 'Enter...'"]
    ]:
        if shutil.which(term_cmd[0]):
            subprocess.Popen(term_cmd, start_new_session=True)
            return True
    return False

def restore_settings_from_root(root_dir):
    cfg_src = os.path.join(root_dir, "config")
    if os.path.exists(cfg_src):
        for item in os.listdir(cfg_src):
            s = os.path.join(cfg_src, item)
            d = os.path.join(HOME, ".config", item)
            if os.path.isdir(s):
                shutil.copytree(s, d, dirs_exist_ok=True)

    icons_src = os.path.join(root_dir, "local_share", "icons")
    if os.path.exists(icons_src):
        dst_icons = os.path.join(HOME, ".local", "share", "icons")
        os.makedirs(dst_icons, exist_ok=True)
        shutil.copytree(icons_src, dst_icons, symlinks=True, ignore_dangling_symlinks=True, dirs_exist_ok=True)

    hs_data = os.path.join(root_dir, "hysett_data")
    if os.path.exists(hs_data):
        for sub in ("scripts", "widgets"):
            s = os.path.join(hs_data, sub)
            if os.path.exists(s):
                shutil.copytree(s, os.path.join(HYSETT_DIR, sub), dirs_exist_ok=True)

def restore_data_from_root(root_dir):
    data_src = os.path.join(root_dir, "user_data")
    if not os.path.exists(data_src):
        return False

    mus_src = os.path.join(data_src, "music")
    if os.path.exists(mus_src):
        dst_mus = get_music_dir()
        os.makedirs(dst_mus, exist_ok=True)
        shutil.copytree(mus_src, dst_mus, dirs_exist_ok=True)

    wall_src = os.path.join(data_src, "wallpapers")
    if os.path.exists(wall_src):
        dst_wall = get_wallpapers_dir()
        os.makedirs(dst_wall, exist_ok=True)
        shutil.copytree(wall_src, dst_wall, dirs_exist_ok=True)

    sec_src = os.path.join(data_src, "secrets")
    if os.path.exists(sec_src):
        os.makedirs(os.path.join(HOME, ".config", "hypr", "scripts"), exist_ok=True)
        for fn in os.listdir(sec_src):
            s_file = os.path.join(sec_src, fn)
            if fn == "hysett_vpn_sub.txt":
                d_file = os.path.join(HOME, ".config", "hysett_vpn_sub.txt")
                shutil.copy2(s_file, d_file)
                os.chmod(d_file, 0o600)
            else:
                d_file = os.path.join(HOME, ".config", "hypr", "scripts", fn)
                shutil.copy2(s_file, d_file)

    ph_src = os.path.join(data_src, "phone_transfer")
    if os.path.exists(ph_src):
        dst_ph = os.path.expanduser("~/Downloads/PhoneTransfer")
        os.makedirs(dst_ph, exist_ok=True)
        shutil.copytree(ph_src, dst_ph, dirs_exist_ok=True)

    fonts_src = os.path.join(data_src, "fonts")
    if os.path.exists(fonts_src):
        dst_fonts = os.path.expanduser("~/.local/share/fonts")
        os.makedirs(dst_fonts, exist_ok=True)
        shutil.copytree(fonts_src, dst_fonts, dirs_exist_ok=True)
        subprocess.Popen(["fc-cache", "-f"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    return True

def find_latest_archive_by_kind(wanted_kind):
    bdir = get_backups_dir()
    if not os.path.exists(bdir):
        return ""
    files = sorted([f for f in os.listdir(bdir) if f.endswith((".tar.gz", ".tgz", ".tar.zst"))], reverse=True)
    for fn in files:
        k, _ = detect_archive_kind(fn)
        if k == wanted_kind or k == "full":
            return os.path.join(bdir, fn)
    return os.path.join(bdir, files[0]) if files else ""

def cmd_restore_backup(archive_path, mode="settings_pkgs"):
    mode = (mode or "settings_pkgs").strip()
    if mode == "1":
        mode = "settings_pkgs"
    elif mode == "0":
        mode = "settings_only"

    archive_path = os.path.expanduser((archive_path or "").strip())
    if not archive_path:
        if mode == "data":
            archive_path = find_latest_archive_by_kind("data")
        elif mode in ("settings_pkgs", "settings_only"):
            archive_path = find_latest_archive_by_kind("settings")
        else:
            archive_path = find_latest_archive_by_kind("full")

    if not archive_path or not os.path.exists(archive_path):
        write_prog(False, 0, "Архив бэкапа не найден. Сначала создайте или выберите архив.")
        cmd_info()
        return

    write_prog(True, 20, f"Распаковка архива {os.path.basename(archive_path)}...")
    ext_dir = "/tmp/hysett_restore_stage"
    shutil.rmtree(ext_dir, ignore_errors=True)
    os.makedirs(ext_dir, exist_ok=True)
    try:
        with tarfile.open(archive_path, "r:*") as tar:
            tar.extractall(ext_dir)
    except Exception as e:
        shutil.rmtree(ext_dir, ignore_errors=True)
        write_prog(False, 0, f"Ошибка распаковки архива: {e}")
        cmd_info()
        return

    root_dir = ext_dir
    sub = os.listdir(ext_dir)
    if len(sub) == 1 and os.path.isdir(os.path.join(ext_dir, sub[0])):
        root_dir = os.path.join(ext_dir, sub[0])

    restored_parts = []
    if mode in ("settings_only", "settings_pkgs", "full_all"):
        write_prog(True, 50, "Восстановление настроек Hyprland, терминала, курсоров и скриптов...")
        restore_settings_from_root(root_dir)
        restored_parts.append("Настройки")

    if mode in ("data", "full_all"):
        write_prog(True, 70, "Восстановление личных данных (Музыка, Обои, подписки VPN)...")
        if restore_data_from_root(root_dir):
            restored_parts.append("Личные данные")

    pkg_sh = os.path.join(root_dir, "install_packages.sh")
    if mode in ("settings_pkgs", "full_all") and os.path.exists(pkg_sh):
        write_prog(True, 90, "Запуск установки Hyprland и докачки всех пакетов (pacman + AUR)...")
        launch_pkg_installer_in_terminal(pkg_sh)
        restored_parts.append("Установка Hyprland + Пакетов")

    shutil.rmtree(ext_dir, ignore_errors=True)
    subprocess.Popen(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    summary = ", ".join(restored_parts) if restored_parts else "Архив"
    write_prog(False, 100, f"Восстановлено: {summary} ✓")
    cmd_info()

def cmd_install_all_pkgs():
    write_prog(True, 30, "Подготовка скрипта установки Hyprland и всех пакетов...")
    bdir = get_backups_dir()
    script_p = os.path.join(bdir, "install_my_packages.sh")
    if not os.path.exists(script_p):
        native, aur = get_pkg_lists()
        script_txt = build_install_script_text(native, aur)
        with open(script_p, "w", encoding="utf-8") as f:
            f.write(script_txt)
        os.chmod(script_p, 0o755)
    launch_pkg_installer_in_terminal(script_p)
    write_prog(False, 100, "Запущена установка Hyprland и всех пакетов (pacman + AUR) в терминале ✓")
    cmd_info()

def cmd_pick_archive():
    bdir = get_backups_dir()
    for cmd in (
        ["zenity", "--file-selection", "--title=Выберите архив бэкапа", f"--filename={bdir}/", "--file-filter=Архивы бэкапа | *.tar.gz *.tgz *.tar.zst"],
        ["kdialog", "--getopenfilename", bdir, "*.tar.gz *.tgz *.tar.zst|Архивы бэкапа"]
    ):
        if shutil.which(cmd[0]):
            try:
                out = subprocess.check_output(cmd, stderr=subprocess.DEVNULL).decode("utf-8", errors="ignore").strip()
                if out:
                    print(out)
                return
            except Exception:
                return
    try:
        import tkinter as tk
        from tkinter import filedialog
        root = tk.Tk()
        root.withdraw()
        res = filedialog.askopenfilename(initialdir=bdir, title="Выберите архив бэкапа")
        if res:
            print(res)
    except Exception:
        pass

def cmd_check_updates():
    write_prog(True, 20, "Проверка обновлений в репозитории whrr-fdev/hysett...")
    local_hash = ""
    local_ver = "main"
    try:
        local_hash = subprocess.check_output(["git", "-C", HYSETT_DIR, "rev-parse", "HEAD"], stderr=subprocess.DEVNULL).decode().strip()
        dt = subprocess.check_output(["git", "-C", HYSETT_DIR, "log", "-1", "--format=%cd", "--date=format:%d.%m.%Y %H:%M"], stderr=subprocess.DEVNULL).decode().strip()
        local_ver = f"{local_hash[:7]} ({dt})"
    except Exception:
        pass

    remote_ver = ""
    changelog = ""
    has_update = False

    try:
        req = urllib.request.Request("https://api.github.com/repos/whrr-fdev/hysett/releases/latest", headers={"User-Agent": "HySett-Updater"})
        with urllib.request.urlopen(req, timeout=8) as r:
            rel = json.loads(r.read().decode("utf-8", errors="ignore"))
        tag = rel.get("tag_name", "")
        name = rel.get("name") or tag
        body = (rel.get("body") or "").strip()
        if tag:
            remote_ver = f"Релиз {name}"
            changelog = body
    except Exception:
        pass

    try:
        req = urllib.request.Request("https://api.github.com/repos/whrr-fdev/hysett/commits/main", headers={"User-Agent": "HySett-Updater"})
        with urllib.request.urlopen(req, timeout=8) as r:
            cm = json.loads(r.read().decode("utf-8", errors="ignore"))
        sha = cm.get("sha", "")
        msg = cm.get("commit", {}).get("message", "").strip()
        date_iso = cm.get("commit", {}).get("committer", {}).get("date", "")
        if not remote_ver:
            remote_ver = f"{sha[:7]} ({date_iso[:10]})"
        if not changelog:
            changelog = msg
        if sha and local_hash and sha != local_hash:
            is_anc = subprocess.run(["git", "-C", HYSETT_DIR, "merge-base", "--is-ancestor", sha, local_hash], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode == 0
            has_update = not is_anc
    except Exception as e:
        if not remote_ver:
            remote_ver = "Не удалось подключиться к GitHub"
            changelog = str(e)

    status_msg = "Доступно новое обновление на GitHub!" if has_update else "У вас установлена актуальная версия HySett ✓"
    write_prog(False, 100, status_msg)
    print(json.dumps({
        "update_available": has_update,
        "local_version": local_ver,
        "remote_version": remote_ver or local_ver,
        "changelog": changelog or "Нет описания изменений",
        "status": status_msg
    }, ensure_ascii=False))

def cmd_install_update():
    write_prog(True, 10, "Получение свежих изменений с GitHub (whrr-fdev/hysett)...")
    res_fetch = subprocess.run(["git", "-C", HYSETT_DIR, "fetch", "origin", "main"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res_fetch.returncode != 0:
        write_prog(False, 0, "Ошибка git fetch: проверьте подключение к интернету")
        return

    write_prog(True, 35, "Обновление исходного кода до последней версии...")
    subprocess.run(["git", "-C", HYSETT_DIR, "stash", "--include-untracked"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.run(["git", "-C", HYSETT_DIR, "pull", "--rebase", "origin", "main"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    write_prog(True, 60, "Компиляция новой версии HySett (cmake --build)...")
    subprocess.run(["cmake", "-B", os.path.join(HYSETT_DIR, "build"), "-S", HYSETT_DIR], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    res_build = subprocess.run(["cmake", "--build", os.path.join(HYSETT_DIR, "build"), f"-j{os.cpu_count() or 4}"], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if res_build.returncode != 0:
        write_prog(False, 0, "Ошибка сборки обновления")
        return

    write_prog(False, 100, "Обновление установлено ✓ Перезапуск HySett...")
    subprocess.Popen(["bash", "-c", f"sleep 0.6 && pkill -x hysett || true; nohup {HYSETT_DIR}/build/hysett --daemon >/dev/null 2>&1 &"])

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "info"
    if cmd == "info":
        cmd_info()
    elif cmd == "gen_pkg_script":
        cmd_gen_pkg_script()
    elif cmd == "create_backup":
        m = sys.argv[2] if len(sys.argv) > 2 else "full"
        cmd_create_backup(m)
    elif cmd == "restore_backup":
        arch = sys.argv[2] if len(sys.argv) > 2 else ""
        m = sys.argv[3] if len(sys.argv) > 3 else "settings_pkgs"
        cmd_restore_backup(arch, m)
    elif cmd == "install_all_pkgs":
        cmd_install_all_pkgs()
    elif cmd == "pick_archive":
        cmd_pick_archive()
    elif cmd == "delete_backup":
        arch = sys.argv[2] if len(sys.argv) > 2 else ""
        if arch and os.path.exists(arch):
            try:
                os.remove(arch)
            except Exception:
                pass
        cmd_info()
    elif cmd == "git_login":
        u = sys.argv[2] if len(sys.argv) > 2 else ""
        t = sys.argv[3] if len(sys.argv) > 3 else ""
        cmd_git_login(u, t)
    elif cmd == "git_push_configs":
        rep = sys.argv[2] if len(sys.argv) > 2 else ""
        priv = (sys.argv[3] == "1") if len(sys.argv) > 3 else True
        cmd_git_push_configs(rep, priv)
    elif cmd == "git_pull_configs":
        rep = sys.argv[2] if len(sys.argv) > 2 else ""
        wp = (sys.argv[3] == "1") if len(sys.argv) > 3 else False
        cmd_git_pull_configs(rep, wp)
    elif cmd == "check_updates":
        cmd_check_updates()
    elif cmd == "install_update":
        cmd_install_update()
