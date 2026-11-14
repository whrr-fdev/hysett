#!/usr/bin/env python3
import sys, os, json, time, tarfile, shutil, subprocess, datetime, urllib.request

HOME = os.path.expanduser("~")
HYSETT_DIR = os.path.expanduser("~/hysett")
CONF_FILE = os.path.expanduser("~/.config/hypr/scripts/control_center.conf")
PROG_FILE = "/tmp/hysett_sys_progress.json"

def write_prog(busy, pct, text):
    try:
        tmp = PROG_FILE + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump({"busy": bool(busy), "percent": int(pct), "text": str(text), "ts": time.time()}, f, ensure_ascii=False)
        os.replace(tmp, PROG_FILE)
    except Exception:
        pass

def get_backups_dir():
    d = os.path.join(HYSETT_DIR, "backups", "archives")
    if os.path.exists(CONF_FILE):
        try:
            for ln in open(CONF_FILE, "r", encoding="utf-8", errors="ignore"):
                if ln.strip().startswith("backups_dir="):
                    v = ln.strip().split("=", 1)[1].strip()
                    if v:
                        d = os.path.expanduser(v)
        except Exception:
            pass
    os.makedirs(d, exist_ok=True)
    return d

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
    lines = [
        "#!/usr/bin/env bash",
        "# Автоматически сгенерированный скрипт установки пакетов HySett",
        "set -e",
        'echo "==> Обновление базы пакетов и установка официальных пакетов (pacman)..."',
        "sudo pacman -Syu --needed --noconfirm \\",
    ]
    for i, p in enumerate(native):
        end = " \\" if i < len(native) - 1 else ""
        lines.append(f"  {p}{end}")
    if aur:
        lines.extend([
            "",
            'if command -v paru >/dev/null 2>&1; then',
            '    AUR_HELPER="paru"',
            'elif command -v yay >/dev/null 2>&1; then',
            '    AUR_HELPER="yay"',
            'else',
            '    echo "==> Установка paru для сборки AUR-пакетов..."',
            '    sudo pacman -S --needed --noconfirm base-devel git',
            '    git clone https://aur.archlinux.org/paru-bin.git /tmp/paru-bin && (cd /tmp/paru-bin && makepkg -si --noconfirm)',
            '    AUR_HELPER="paru"',
            'fi',
            'echo "==> Установка пакетов из AUR ($AUR_HELPER)..."',
            '$AUR_HELPER -S --needed --noconfirm \\',
        ])
        for i, p in enumerate(aur):
            end = " \\" if i < len(aur) - 1 else ""
            lines.append(f"  {p}{end}")
    lines.append('\necho "==> Все пакеты успешно установлены! ✓"')
    return "\n".join(lines) + "\n"

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
                archives.append({
                    "name": fn,
                    "path": fp,
                    "size": f"{sz_mb:.1f} MB",
                    "date": mt
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
        "local_version": local_ver
    }, ensure_ascii=False))

def cmd_gen_pkg_script():
    write_prog(True, 25, "Сбор списка установленных пакетов pacman и AUR...")
    native, aur = get_pkg_lists()
    bdir = get_backups_dir()
    script_txt = build_install_script_text(native, aur)
    out1 = os.path.join(bdir, "install_my_packages.sh")
    out2 = os.path.join(HOME, "install_my_packages.sh")
    for p in (out1, out2):
        with open(p, "w", encoding="utf-8") as f:
            f.write(script_txt)
        os.chmod(p, 0o755)
    write_prog(False, 100, f"Скрипт создан: ~/install_my_packages.sh (Pacman: {len(native)}, AUR: {len(aur)}) ✓")
    cmd_info()

def cmd_create_backup():
    write_prog(True, 10, "Подготовка списков пакетов и конфигураций...")
    native, aur = get_pkg_lists()
    bdir = get_backups_dir()
    ts = datetime.datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    archive_name = f"hysett_system_backup_{ts}.tar.gz"
    archive_path = os.path.join(bdir, archive_name)

    stage_dir = "/tmp/hysett_backup_stage"
    shutil.rmtree(stage_dir, ignore_errors=True)
    os.makedirs(stage_dir, exist_ok=True)

    with open(os.path.join(stage_dir, "pkglist_native.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(native) + "\n")
    with open(os.path.join(stage_dir, "pkglist_aur.txt"), "w", encoding="utf-8") as f:
        f.write("\n".join(aur) + "\n")
    inst_sh = os.path.join(stage_dir, "install_packages.sh")
    with open(inst_sh, "w", encoding="utf-8") as f:
        f.write(build_install_script_text(native, aur))
    os.chmod(inst_sh, 0o755)

    restore_sh = os.path.join(stage_dir, "restore_backup.sh")
    with open(restore_sh, "w", encoding="utf-8") as f:
        f.write("""#!/usr/bin/env bash
set -e
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Восстановление конфигураций Hyprland и HySett..."
mkdir -p ~/.config
[ -d "$DIR/config/hypr" ] && cp -rf "$DIR/config/hypr" ~/.config/
[ -d "$DIR/config/kitty" ] && cp -rf "$DIR/config/kitty" ~/.config/
[ -d "$DIR/config/btop" ] && cp -rf "$DIR/config/btop" ~/.config/
[ -d "$DIR/hysett_data/scripts" ] && mkdir -p ~/hysett && cp -rf "$DIR/hysett_data/scripts" ~/hysett/
if [ "$1" = "--with-packages" ]; then
    bash "$DIR/install_packages.sh"
fi
echo "==> Восстановление успешно завершено! ✓"
""")
    os.chmod(restore_sh, 0o755)

    write_prog(True, 35, "Копирование конфигураций ~/.config/hypr, kitty, btop...")
    cfg_stage = os.path.join(stage_dir, "config")
    os.makedirs(cfg_stage, exist_ok=True)
    for cname in ("hypr", "kitty", "btop", "gtk-3.0", "gtk-4.0"):
        src_c = os.path.join(HOME, ".config", cname)
        if os.path.exists(src_c):
            shutil.copytree(src_c, os.path.join(cfg_stage, cname), symlinks=False, ignore=shutil.ignore_patterns("*.sock", "*.lock", "vpn_state.json", "singbox_vpn.json", "*.bak*"), dirs_exist_ok=True)

    write_prog(True, 65, "Копирование скриптов и профилей HySett...")
    hs_stage = os.path.join(stage_dir, "hysett_data")
    os.makedirs(hs_stage, exist_ok=True)
    if os.path.exists(os.path.join(HYSETT_DIR, "scripts")):
        shutil.copytree(os.path.join(HYSETT_DIR, "scripts"), os.path.join(hs_stage, "scripts"), symlinks=False, ignore=shutil.ignore_patterns("vpn_state.json", "singbox_vpn.json", "*.bak*"), dirs_exist_ok=True)

    write_prog(True, 85, f"Сжатие архива {archive_name}...")
    with tarfile.open(archive_path, "w:gz") as tar:
        for item in os.listdir(stage_dir):
            tar.add(os.path.join(stage_dir, item), arcname=item)

    shutil.rmtree(stage_dir, ignore_errors=True)
    write_prog(False, 100, f"Архив бэкапа создан: {archive_name} ✓")
    cmd_info()

def cmd_restore_backup(archive_path, with_pkgs=False):
    archive_path = os.path.expanduser(archive_path.strip())
    if not os.path.exists(archive_path):
        write_prog(False, 0, f"Файл архива не найден: {archive_path}")
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

    write_prog(True, 60, "Восстановление конфигурационных файлов...")
    root_dir = ext_dir
    sub = os.listdir(ext_dir)
    if len(sub) == 1 and os.path.isdir(os.path.join(ext_dir, sub[0])):
        root_dir = os.path.join(ext_dir, sub[0])

    cfg_src = os.path.join(root_dir, "config")
    if os.path.exists(cfg_src):
        for item in os.listdir(cfg_src):
            s = os.path.join(cfg_src, item)
            d = os.path.join(HOME, ".config", item)
            if os.path.isdir(s):
                shutil.copytree(s, d, dirs_exist_ok=True)

    hs_src = os.path.join(root_dir, "hysett_data", "scripts")
    if os.path.exists(hs_src):
        shutil.copytree(hs_src, os.path.join(HYSETT_DIR, "scripts"), dirs_exist_ok=True)

    pkg_sh = os.path.join(root_dir, "install_packages.sh")
    if with_pkgs and os.path.exists(pkg_sh):
        write_prog(True, 85, "Запуск терминала установки пакетов из бэкапа...")
        tmp_run = "/tmp/hysett_restore_pkgs.sh"
        shutil.copy2(pkg_sh, tmp_run)
        os.chmod(tmp_run, 0o755)
        subprocess.Popen(["kitty", "--title", "HySett Package Restore", "-e", "bash", "-c", f"{tmp_run}; echo ''; read -p 'Нажмите Enter для закрытия...'"])

    shutil.rmtree(ext_dir, ignore_errors=True)
    subprocess.Popen(["hyprctl", "reload"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    write_prog(False, 100, "Бэкап успешно восстановлен ✓" + (" (установка пакетов запущена в Kitty)" if with_pkgs else ""))
    cmd_info()

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
    remote_hash = ""
    changelog = ""
    has_update = False

    # 1. Проверяем последний Release на GitHub
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

    # 2. Проверяем последний коммит ветки main
    try:
        req = urllib.request.Request("https://api.github.com/repos/whrr-fdev/hysett/commits/main", headers={"User-Agent": "HySett-Updater"})
        with urllib.request.urlopen(req, timeout=8) as r:
            cm = json.loads(r.read().decode("utf-8", errors="ignore"))
        sha = cm.get("sha", "")
        msg = cm.get("commit", {}).get("message", "").strip()
        date_iso = cm.get("commit", {}).get("committer", {}).get("date", "")
        remote_hash = sha
        if not remote_ver:
            remote_ver = f"{sha[:7]} ({date_iso[:10]})"
        if not changelog:
            changelog = msg
        if sha and local_hash and sha != local_hash:
            # Проверим, не является ли remote_hash предком local_hash
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
    subprocess.run(["git", "-C", HYSETT_DIR, " stash", "--include-untracked"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
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
        cmd_create_backup()
    elif cmd == "restore_backup":
        arch = sys.argv[2] if len(sys.argv) > 2 else ""
        wp = (sys.argv[3] == "1") if len(sys.argv) > 3 else False
        cmd_restore_backup(arch, wp)
    elif cmd == "delete_backup":
        arch = sys.argv[2] if len(sys.argv) > 2 else ""
        if arch and os.path.exists(arch):
            try:
                os.remove(arch)
            except Exception:
                pass
        cmd_info()
    elif cmd == "check_updates":
        cmd_check_updates()
    elif cmd == "install_update":
        cmd_install_update()
