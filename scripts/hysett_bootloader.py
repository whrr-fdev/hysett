#!/usr/bin/env python3
import sys, os, re, json, shutil, subprocess

def run_out(cmd, timeout=5):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, timeout=timeout).decode("utf-8", errors="ignore")
    except Exception:
        return ""

def run_root(args):
    if os.geteuid() == 0:
        return subprocess.run(args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    return subprocess.run(["pkexec", sys.executable, os.path.abspath(__file__)] + args, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)

def detect_bootloader():
    # 1. Проверяем systemd-boot
    for esp in ("/boot", "/efi", "/boot/efi"):
        if os.path.exists(os.path.join(esp, "loader/loader.conf")):
            return "systemd-boot", esp
    b_out = run_out(["bootctl", "is-installed"]).strip()
    if b_out == "yes":
        return "systemd-boot", "/boot"
    # 2. Проверяем Limine
    for lp in ("/boot/limine.conf", "/boot/limine/limine.conf", "/boot/EFI/limine/limine.conf", "/efi/EFI/limine/limine.conf"):
        if os.path.exists(lp):
            return "limine", lp
    # 3. Проверяем GRUB
    if os.path.exists("/etc/default/grub") and os.path.exists("/boot/grub/grub.cfg"):
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
    return entries, efi_timeout

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
                etype = item.get("type", "")
                if etype == "auto-reboot-to-firmware-setup":
                    continue
                eid = item.get("id", "")
                title = item.get("showTitle") or item.get("title") or eid
                ver = item.get("version") or ""
                is_def = bool(item.get("isDefault", False))
                is_sel = bool(item.get("isSelected", False))
                entries.append({
                    "id": eid,
                    "title": title,
                    "version": ver,
                    "is_default": is_def,
                    "is_booted": is_sel
                })
        except Exception:
            pass

    if not entries:
        entries_dir = os.path.join(esp, "loader/entries")
        if os.path.isdir(entries_dir):
            for fn in sorted(os.listdir(entries_dir)):
                if not fn.endswith(".conf"):
                    continue
                fp = os.path.join(entries_dir, fn)
                title = fn[:-5]
                ver = ""
                try:
                    for ln in open(fp, "r", encoding="utf-8", errors="ignore"):
                        ln = ln.strip()
                        if ln.startswith("title "):
                            title = ln[6:].strip()
                        elif ln.startswith("version "):
                            ver = ln[8:].strip()
                except Exception:
                    pass
                entries.append({
                    "id": fn,
                    "title": title,
                    "version": ver,
                    "is_default": (default_pattern == fn or default_pattern == fn[:-5]),
                    "is_booted": False
                })

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
                is_def = (default_val == str(idx) or default_val == title)
                entries.append({
                    "id": title,
                    "index": idx,
                    "title": title,
                    "version": f"Запись #{idx + 1}",
                    "is_default": is_def,
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

def build_status(msg=""):
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
    fw_out = run_out(["bootctl", "set-reboot-to-firmware"]).strip().lower()
    st["fw_next"] = (fw_out == "yes" or fw_out == "true")
    st["status"] = msg or f"Активный загрузчик: {st['type']} ({st['config_path']})"
    return st

def root_apply_settings(timeout_sec, saved_def, editor_on):
    btype, bpath = detect_bootloader()
    t_val = max(0, min(60, int(timeout_sec)))
    if btype == "systemd-boot":
        loader_conf = os.path.join(bpath, "loader/loader.conf")
        lines = []
        if os.path.exists(loader_conf):
            lines = open(loader_conf, "r", encoding="utf-8", errors="ignore").read().splitlines()
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
                if saved_def:
                    out_lines.append("default @saved")
                else:
                    out_lines.append(ln)
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
        loader_conf = os.path.join(bpath, "loader/loader.conf")
        if os.path.exists(loader_conf):
            lines = open(loader_conf, "r", encoding="utf-8", errors="ignore").read().splitlines()
            out_lines = []
            found = False
            for ln in lines:
                if ln.split("#")[0].strip().lower().startswith("default"):
                    out_lines.append(f"default {entry_id}")
                    found = True
                else:
                    out_lines.append(ln)
            if not found:
                out_lines.append(f"default {entry_id}")
            with open(loader_conf, "w", encoding="utf-8") as f:
                f.write("\n".join(out_lines) + "\n")
    elif btype == "grub":
        subprocess.run(["grub-set-default", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        gfile = "/etc/default/grub"
        if os.path.exists(gfile):
            txt = open(gfile, "r", encoding="utf-8", errors="ignore").read()
            if re.search(r"^GRUB_DEFAULT=", txt, re.M):
                txt = re.sub(r"^GRUB_DEFAULT=.*$", f'GRUB_DEFAULT="{entry_id}"', txt, flags=re.M)
            else:
                txt += f'\nGRUB_DEFAULT="{entry_id}"\n'
            with open(gfile, "w", encoding="utf-8") as f:
                f.write(txt)
            subprocess.run(["grub-mkconfig", "-o", "/boot/grub/grub.cfg"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "limine":
        txt = open(bpath, "r", encoding="utf-8", errors="ignore").read()
        if re.search(r"^default_entry:\s*.*$", txt, re.M | re.I):
            txt = re.sub(r"^default_entry:\s*.*$", f"default_entry: {entry_id}", txt, flags=re.M | re.I)
        else:
            txt = f"default_entry: {entry_id}\n" + txt
        with open(bpath, "w", encoding="utf-8") as f:
            f.write(txt)

def root_boot_oneshot(entry_id, do_reboot):
    btype, _ = detect_bootloader()
    if btype == "systemd-boot":
        subprocess.run(["bootctl", "set-oneshot", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "grub":
        subprocess.run(["grub-reboot", entry_id], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if do_reboot:
        subprocess.Popen(["systemctl", "reboot"])

def root_efi_set_first(boot_num):
    entries, _ = parse_efibootmgr()
    nums = [x["num"] for x in entries if x["num"] != boot_num.upper()]
    new_order = ",".join([boot_num.upper()] + nums)
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

def root_reboot_bootmenu():
    btype, bpath = detect_bootloader()
    if btype == "systemd-boot":
        subprocess.run(["bootctl", "set-timeout-oneshot", "30"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "grub":
        subprocess.run(["grub-editenv", "/boot/grub/grubenv", "set", "menu_show_once=1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        subprocess.run(["grub-editenv", "/boot/grub/grubenv", "set", " recordfail=1"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    elif btype == "limine" and os.path.exists(bpath):
        root_apply_settings(15, False, True)
    else:
        subprocess.run(["efibootmgr", "-t", "10"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.Popen(["systemctl", "reboot"])

if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "status"
    if cmd == "_root_apply":
        root_apply_settings(sys.argv[2], sys.argv[3] == "1", sys.argv[4] == "1")
    elif cmd == "_root_default":
        root_set_default(sys.argv[2])
    elif cmd == "_root_oneshot":
        root_boot_oneshot(sys.argv[2], sys.argv[3] == "1")
    elif cmd == "_root_efi_first":
        root_efi_set_first(sys.argv[2])
    elif cmd == "_root_efi_next":
        root_efi_boot_next(sys.argv[2], sys.argv[3] == "1")
    elif cmd == "apply":
        run_root(["_root_apply", sys.argv[2], sys.argv[3], sys.argv[4]])
        print(json.dumps(build_status("Настройки загрузчика сохранены ✓"), ensure_ascii=False))
    elif cmd == "set_default":
        eid = sys.argv[2] if len(sys.argv) > 2 else ""
        run_root(["_root_default", eid])
        print(json.dumps(build_status(f"Запись по умолчанию изменена: {eid} ✓"), ensure_ascii=False))
    elif cmd == "oneshot":
        eid = sys.argv[2] if len(sys.argv) > 2 else ""
        reb = sys.argv[3] if len(sys.argv) > 3 else "0"
        run_root(["_root_oneshot", eid, reb])
        print(json.dumps(build_status(f"Следующая загрузка: {eid} ✓"), ensure_ascii=False))
    elif cmd == "efi_first":
        bnum = sys.argv[2] if len(sys.argv) > 2 else ""
        run_root(["_root_efi_first", bnum])
        print(json.dumps(build_status(f"Приоритет UEFI изменен: Boot{bnum} на 1-м месте ✓"), ensure_ascii=False))
    elif cmd == "efi_next":
        bnum = sys.argv[2] if len(sys.argv) > 2 else ""
        reb = sys.argv[3] if len(sys.argv) > 3 else "0"
        run_root(["_root_efi_next", bnum, reb])
        print(json.dumps(build_status(f"Следующая загрузка UEFI: Boot{bnum} ✓"), ensure_ascii=False))
    elif cmd == "_root_fw_next":
        root_set_fw_next(sys.argv[2] == "1")
    elif cmd == "_root_reboot_bios":
        root_reboot_bios()
    elif cmd == "_root_reboot_bootmenu":
        root_reboot_bootmenu()
    elif cmd == "set_fw_next":
        en = sys.argv[2] if len(sys.argv) > 2 else "1"
        run_root(["_root_fw_next", en])
        print(json.dumps(build_status("Вход в BIOS при следующей перезагрузке включен ✓" if en == "1" else "Вход в BIOS при следующей перезагрузке отменен"), ensure_ascii=False))
    elif cmd == "reboot_bios":
        run_root(["_root_reboot_bios"])
        print(json.dumps(build_status("Перезагрузка в BIOS / UEFI..."), ensure_ascii=False))
    elif cmd == "reboot_bootmenu":
        run_root(["_root_reboot_bootmenu"])
        print(json.dumps(build_status("Перезагрузка в Boot-меню..."), ensure_ascii=False))
    else:
        print(json.dumps(build_status(), ensure_ascii=False))
