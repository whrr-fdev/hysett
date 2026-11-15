#!/usr/bin/env python3
import sys, os, re, json, shutil, subprocess

def run_out(cmd, timeout=5):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=timeout).decode("utf-8", errors="ignore")
    except Exception:
        return ""

def run_root(args, sudo_pwd=""):
    if os.geteuid() == 0:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    cmd = ["sudo", "-S", "-p", "", sys.executable, os.path.abspath(__file__)] + args
    return subprocess.run(cmd, input=(sudo_pwd + "\n"), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def detect_bootloader():
    for esp in ("/boot", "/efi", "/boot/efi"):
        if os.path.exists(os.path.join(esp, "loader/loader.conf")):
            return "systemd-boot", esp
    if run_out(["bootctl", "is-installed"]).strip() == "yes":
        return "systemd-boot", "/boot"
    for lp in ("/boot/limine.conf", "/boot/limine/limine.conf", "/boot/EFI/limine/limine.conf", "/efi/EFI/limine/limine.conf"):
        if os.path.exists(lp):
            return "limine", lp
    if os.path.exists("/etc/default/grub"):
        return "grub", "/etc/default/grub"
    return "efibootmgr", ""

def parse_efibootmgr():
    out = run_out(["efibootmgr"])
    entries = []
    boot_order = []
    boot_current = ""
    boot_next = ""
    efi_timeout = 0
    for line in out.splitlines():
        line = line.strip()
        if line.startswith("BootCurrent:"):
            boot_current = line.split(":", 1)[1].strip()
        elif line.startswith("BootNext:"):
            boot_next = line.split(":", 1)[1].strip()
        elif line.startswith("Timeout:"):
            m = re.search(r"(\d+)", line)
            if m:
                efi_timeout = int(m.group(1))
        elif line.startswith("BootOrder:"):
            boot_order = [x.strip() for x in line.split(":", 1)[1].split(",") if x.strip()]
        else:
            m = re.match(r"^Boot([0-9A-Fa-f]{4})(\*?)\s+(.+?)(?:\t|\s{2,}|HD\(|PciRoot\(|File\(|VenHw\(|$)", line)
            if m:
                num, active, title = m.group(1).upper(), (m.group(2) == "*"), m.group(3).strip()
                entries.append({
                    "num": num,
                    "active": active,
                    "title": title,
                    "is_first": (len(boot_order) > 0 and boot_order[0].upper() == num),
                    "is_current": (boot_current.upper() == num),
                    "is_next": (boot_next.upper() == num)
                })
    if boot_order:
        order_map = {k.upper(): i for i, k in enumerate(boot_order)}
        entries.sort(key=lambda x: order_map.get(x["num"], 999))
    for i, e in enumerate(entries):
        e["is_first"] = (i == 0)
    return entries, efi_timeout

def detect_bootable_usb(efi_entries):
    # 1. Ищем USB в efibootmgr (кроме пустой заглушки USB HDD/FDD)
    for e in efi_entries:
        t = e["title"].lower()
        if t in ("usb hdd", "usb fdd", "hard drive", "cd/dvd drive", "network"):
            continue
        if any(k in t for k in ("usb", "ventoy", "flash", "sandisk", "kingston", "transcend", "adata", "samsung flash", "cruzer")):
            return {"type": "efi", "num": e["num"], "name": e["title"], "disk": "", "part": 1}

    # 2. Ищем подключенные USB-флешки через lsblk
    raw = run_out(["lsblk", "-J", "-o", "NAME,PKNAME,RM,TRAN,FSTYPE,LABEL,MODEL,PATH"])
    if raw.strip().startswith("{"):
        try:
            data = json.loads(raw)
            def walk_devs(devs, parent_tran="", parent_model="", parent_path=""):
                found = []
                for d in devs:
                    tran = (d.get("tran") or parent_tran or "").lower()
                    model = (d.get("model") or parent_model or "").strip()
                    path = d.get("path") or ("/dev/" + d.get("name", ""))
                    fstype = (d.get("fstype") or "").lower()
                    label = (d.get("label") or "").strip()
                    is_usb = (tran == "usb")
                    ch = d.get("children", [])
                    if is_usb and not ch and fstype in ("vfat", "fat32", "exfat", "iso9660", "ntfs"):
                        pnum_m = re.search(r"(\d+)$", path)
                        pnum = int(pnum_m.group(1)) if pnum_m else 1
                        disk_path = parent_path or re.sub(r"\d+$", "", path)
                        disp = f"{model} ({label})" if (model and label) else (model or label or os.path.basename(path))
                        found.append({"type": "blk", "num": "", "name": disp, "disk": disk_path, "part": pnum})
                    if ch:
                        found.extend(walk_devs(ch, tran, model, path))
                return found
            usb_parts = walk_devs(data.get("blockdevices", []))
            if usb_parts:
                return usb_parts[0]
        except Exception:
            pass
    return None

def get_systemd_boot_state(esp):
    loader_conf = os.path.join(esp, "loader/loader.conf")
    timeout = 5
    default_pattern = ""
    editor = True
    if os.path.exists(loader_conf):
        try:
            for ln in open(loader_conf, "r", encoding="utf-8", errors="ignore"):
                ln = ln.split("#")[0].strip()
                if not ln:
                    continue
                parts = ln.split(None, 1)
                if len(parts) == 2:
                    k, v = parts[0].lower(), parts[1].strip()
                    if k == "timeout":
                        timeout = 0 if v in ("0", "menu-hidden", "menu-force") else int(re.sub(r"\D", "", v) or "5")
                    elif k == "default":
                        default_pattern = v
                    elif k == "editor":
                        editor = v.lower() in ("yes", "1", "true")
        except Exception:
            pass

    entries = []
    raw_json = run_out(["bootctl", "list", "--json=short"])
    if raw_json.strip().startswith("["):
        try:
            arr = json.loads(raw_json)
            for item in arr:
                if item.get("type", "") == "auto-reboot-to-firmware-setup":
                    continue
                eid = item.get("id", "")
                title = item.get("showTitle") or item.get("title") or eid
                ver = item.get("version") or ""
                entries.append({
                    "id": eid,
                    "title": title,
                    "version": ver,
                    "is_default": bool(item.get("isDefault", False)),
                    "is_booted": bool(item.get("isSelected", False))
                })
        except Exception:
            pass
    return {
        "type": "systemd-boot",
        "config_path": loader_conf,
        "timeout": timeout,
        "saved_default": (default_pattern == "@saved"),
        "editor": editor,
        "entries": entries
    }

def get_grub_state():
    timeout = 5
    default_val = "0"
    saved_def = False
    if os.path.exists("/etc/default/grub"):
        try:
            for ln in open("/etc/default/grub", "r", encoding="utf-8", errors="ignore"):
                ln = ln.strip()
                if ln.startswith("GRUB_TIMEOUT="):
                    v = ln.split("=", 1)[1].strip().strip('"').strip("'")
                    timeout = max(0, int(re.sub(r"[^\d]", "", v) or "5"))
                elif ln.startswith("GRUB_DEFAULT="):
                    default_val = ln.split("=", 1)[1].strip().strip('"').strip("'")
                elif ln.startswith("GRUB_SAVEDEFAULT="):
                    v = ln.split("=", 1)[1].strip().strip('"').strip("'").lower()
                    saved_def = (v == "true" or v == "1")
        except Exception:
            pass

    entries = []
    if os.path.exists("/boot/grub/grub.cfg"):
        try:
            cfg = open("/boot/grub/grub.cfg", "r", encoding="utf-8", errors="ignore").read()
            idx = 0
            for m in re.finditer(r"menuentry\s+['\"]([^'\"]+)['\"]", cfg):
                title = m.group(1).strip()
                entries.append({
                    "id": title,
                    "index": idx,
                    "title": title,
                    "version": f"Запись #{idx + 1}",
                    "is_default": (default_val == str(idx) or default_val == title),
                    "is_booted": False
                })
                idx += 1
        except Exception:
            pass
    return {
        "type": "grub",
        "config_path": "/etc/default/grub",
        "timeout": timeout,
        "saved_default": saved_def,
        "editor": True,
        "entries": entries
    }

def get_limine_state(conf_path):
    timeout = 5
    def_entry = 1
    entries = []
    if os.path.exists(conf_path):
        try:
            idx = 1
            for ln in open(conf_path, "r", encoding="utf-8", errors="ignore"):
                s = ln.strip()
                if s.lower().startswith("timeout:"):
                    v = s.split(":", 1)[1].strip()
                    timeout = 0 if v == "no" else int(re.sub(r"\D", "", v) or "5")
                elif s.lower().startswith("default_entry:"):
                    def_entry = int(re.sub(r"\D", "", s.split(":", 1)[1]) or "1")
                elif s.startswith("/") and not s.startswith("//"):
                    title = s.lstrip("/").strip()
                    entries.append({
                        "id": str(idx),
                        "title": title,
                        "version": f"Пункт #{idx}",
                        "is_default": (idx == def_entry),
                        "is_booted": False
                    })
                    idx += 1
        except Exception:
            pass
    return {
        "type": "limine",
        "config_path": conf_path,
        "timeout": timeout,
        "saved_default": False,
        "editor": True,
        "entries": entries
    }

def build_status(msg="", auth_err=False):
    btype, bpath = detect_bootloader()
    if btype == "systemd-boot":
        st = get_systemd_boot_state(bpath)
    elif btype == "grub":
        st = get_grub_state()
    elif btype == "limine":
        st = get_limine_state(bpath)
    else:
        st = {
            "type": "efibootmgr",
            "config_path": "UEFI NVRAM",
            "timeout": 0,
            "saved_default": False,
            "editor": True,
            "entries": []
        }
    efi_list, efi_to = parse_efibootmgr()
    st["efi_entries"] = efi_list
    if st["type"] == "efibootmgr":
        st["timeout"] = efi_to
    usb_info = detect_bootable_usb(efi_list)
    st["usb_name"] = usb_info["name"] if usb_info else ""
    fw_out = run_out(["bootctl", "set-reboot-to-firmware"]).strip().lower()
    st["fw_next"] = (fw_out == "yes" or fw_out == "true")
    st["auth_error"] = auth_err
    st["status"] = msg or f"Активный загрузчик: {st['type']} ({st['config_path']})"
    return st

def root_apply_settings(timeout_sec, saved_def, editor_on):
    btype, bpath = detect_bootloader()
    t_val = max(0, min(60, int(timeout_sec)))
    if btype == "systemd-boot":
        loader_conf = os.path.join(bpath, "loader/loader.conf")
        lines = open(loader_conf, "r", encoding="utf-8", errors="ignore").read().splitlines() if os.path.exists(loader_conf) else []
        out_lines = []
        has_to, has_ed, has_def = False, False, False
        for ln in lines:
            clean = ln.split("#")[0].strip().lower()
            if clean.startswith("timeout ") or clean.startswith("timeout\t"):
                out_lines.append(f"timeout {t_val}")
                has_to = True
            elif clean.startswith("editor ") or clean.startswith("editor\t"):
                out_lines.append(f"editor {'yes' if editor_on else 'no'}")
                has_ed = True
            elif clean.startswith("default ") or clean.startswith("default\t"):
                out_lines.append("default @saved" if saved_def else ln)
                has_def = True
            else:
                out_lines.append(ln)
        if not has_to:
            out_lines.append(f"timeout {t_val}")
        if not has_ed:
            out_lines.append(f"editor {'yes' if editor_on else 'no'}")
        if saved_def and not has_def:
            out_lines.append("default @saved")
        with open(loader_conf, "w", encoding="utf-8") as f:
            f.write("\n".join(out_lines) + "\n")
        subprocess.run(["bootctl", "set-timeout", str(t_val)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        if saved_def:
            subprocess.run(["bootctl", "set-default", "@saved"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "grub":
        gfile = "/etc/default/grub"
        txt = open(gfile, "r", encoding="utf-8", errors="ignore").read() if os.path.exists(gfile) else ""
        if re.search(r"^GRUB_TIMEOUT=", txt, re.M):
            txt = re.sub(r"^GRUB_TIMEOUT=.*$", f"GRUB_TIMEOUT={t_val}", txt, flags=re.M)
        else:
            txt += f"\nGRUB_TIMEOUT={t_val}\n"
        if saved_def:
            if re.search(r"^GRUB_SAVEDEFAULT=", txt, re.M):
                txt = re.sub(r"^GRUB_SAVEDEFAULT=.*$", "GRUB_SAVEDEFAULT=true", txt, flags=re.M)
            else:
                txt += "\nGRUB_SAVEDEFAULT=true\n"
            txt = re.sub(r"^GRUB_DEFAULT=.*$", "GRUB_DEFAULT=saved", txt, flags=re.M)
        else:
            txt = re.sub(r"^GRUB_SAVEDEFAULT=.*$", "GRUB_SAVEDEFAULT=false", txt, flags=re.M)
        with open(gfile, "w", encoding="utf-8") as f:
            f.write(txt)
        subprocess.run(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "limine":
        txt = open(bpath, "r", encoding="utf-8", errors="ignore").read()
        if re.search(r"^timeout:\s*.*$", txt, re.M | re.I):
            txt = re.sub(r"^timeout:\s*.*$", f"timeout: {t_val}", txt, flags=re.M | re.I)
        else:
            txt = f"timeout: {t_val}\n" + txt
        with open(bpath, "w", encoding="utf-8") as f:
            f.write(txt)
    else:
        subprocess.run(["efibootmgr", "-t", str(t_val)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def root_set_default(entry_id):
    btype, bpath = detect_bootloader()
    if btype == "systemd-boot":
        subprocess.run(["bootctl", "set-default", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "grub":
        subprocess.run(["grub-set-default", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        gfile = "/etc/default/grub"
        if os.path.exists(gfile):
            txt = open(gfile, "r", encoding="utf-8", errors="ignore").read()
            txt = re.sub(r"^GRUB_DEFAULT=.*$", f'GRUB_DEFAULT="{entry_id}"', txt, flags=re.M)
            with open(gfile, "w", encoding="utf-8") as f:
                f.write(txt)
            subprocess.run(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def root_boot_oneshot(entry_id, do_reboot):
    btype, _ = detect_bootloader()
    if btype == "systemd-boot":
        subprocess.run(["bootctl", "set-oneshot", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "grub":
        subprocess.run(["grub-reboot", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if do_reboot:
        subprocess.Popen(["systemctl", "reboot"])

def root_efi_reorder(comma_nums):
    req_nums = [x.strip().upper() for x in comma_nums.split(",") if x.strip()]
    entries, _ = parse_efibootmgr()
    all_nums = [x["num"] for x in entries]
    tail = [n for n in all_nums if n not in req_nums]
    new_order = ",".join(req_nums + tail)
    subprocess.run(["efibootmgr", "-o", new_order], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def root_efi_boot_next(boot_num, do_reboot):
    subprocess.run(["efibootmgr", "-n", boot_num.upper()], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if do_reboot:
        subprocess.Popen(["systemctl", "reboot"])

def root_set_fw_next(enable):
    subprocess.run(["bootctl", "set-reboot-to-firmware", "true" if enable else "false"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def root_reboot_bios():
    subprocess.run(["bootctl", "set-reboot-to-firmware", "true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.Popen(["systemctl", "reboot", "--firmware-setup"])

def root_boot_usb():
    efi_list, _ = parse_efibootmgr()
    usb = detect_bootable_usb(efi_list)
    if not usb:
        sys.exit(2)
    if usb["type"] == "efi" and usb.get("num"):
        subprocess.run(["efibootmgr", "-n", usb["num"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["systemctl", "reboot"])
    elif usb["type"] == "blk" and usb.get("disk"):
        subprocess.run([
            "efibootmgr", "-c", "-d", usb["disk"], "-p", str(usb["part"]),
            "-L", f"USB: {usb['name']}", "-l", "\\EFI\\BOOT\\BOOTX64.EFI"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        efi_after, _ = parse_efibootmgr()
        if efi_after:
            subprocess.run(["efibootmgr", "-n", efi_after[0]["num"]], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.Popen(["systemctl", "reboot"])

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "_root_apply":
        root_apply_settings(sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1")
    elif cmd == "_root_default":
        root_set_default(sys.argv[2])
    elif cmd == "_root_oneshot":
        root_boot_oneshot(sys.argv[2], sys.argv[3] == "1")
    elif cmd == "_root_efi_reorder":
        root_efi_reorder(sys.argv[2])
    elif cmd == "_root_efi_next":
        root_efi_boot_next(sys.argv[2], sys.argv[3] == "1")
    elif cmd == "_root_fw_next":
        root_set_fw_next(sys.argv[2] == "1")
    elif cmd == "_root_reboot_bios":
        root_reboot_bios()
    elif cmd == "_root_boot_usb":
        root_boot_usb()
    elif cmd in ("apply", "set_default", "oneshot", "efi_reorder", "efi_next", "set_fw_next", "reboot_bios", "boot_usb"):
        pwd = sys.stdin.read().strip() if not sys.stdin.isatty() else ""
        map_cmd = {
            "apply": ["_root_apply", sys.argv[2] if len(sys.argv) > 2 else "5", sys.argv[3] if len(sys.argv) > 3 else "0", sys.argv[4] if len(sys.argv) > 4 else "1"],
            "set_default": ["_root_default", sys.argv[2] if len(sys.argv) > 2 else ""],
            "oneshot": ["_root_oneshot", sys.argv[2] if len(sys.argv) > 2 else "", sys.argv[3] if len(sys.argv) > 3 else "0"],
            "efi_reorder": ["_root_efi_reorder", sys.argv[2] if len(sys.argv) > 2 else ""],
            "efi_next": ["_root_efi_next", sys.argv[2] if len(sys.argv) > 2 else "", sys.argv[3] if len(sys.argv) > 3 else "0"],
            "set_fw_next": ["_root_fw_next", sys.argv[2] if len(sys.argv) > 2 else "1"],
            "reboot_bios": ["_root_reboot_bios"],
            "boot_usb": ["_root_boot_usb"]
        }
        res = run_root(map_cmd[cmd], pwd)
        if res.returncode == 2:
            print(json.dumps(build_status("Загрузочная USB-флешка не обнаружена. Вставьте флешку и нажмите «Обновить».", False), ensure_ascii=False))
        elif res.returncode != 0:
            print(json.dumps(build_status("Неверный пароль администратора", True), ensure_ascii=False))
        else:
            ok_msgs = {
                "apply": "Настройки загрузчика сохранены ✓",
                "set_default": "Запись по умолчанию обновлена ✓",
                "oneshot": "Выбрана запись для следующей загрузки ✓",
                "efi_reorder": "Новый порядок загрузки BIOS / UEFI сохранен ✓",
                "efi_next": "Перезагрузка в выбранную систему...",
                "set_fw_next": "Параметр входа в BIOS обновлен ✓",
                "reboot_bios": "Перезагрузка в BIOS / UEFI...",
                "boot_usb": "Перезагрузка с загрузочной USB-флешки..."
            }
            print(json.dumps(build_status(ok_msgs.get(cmd, "Готово ✓"), False), ensure_ascii=False))
    else:
        print(json.dumps(build_status(), ensure_ascii=False))
