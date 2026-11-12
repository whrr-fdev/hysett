#!/usr/bin/env bash
set -uo pipefail

BASE_DIR="$HOME/hysett/bypass-lists"
REPOS_DIR="$BASE_DIR/repos"
LOG_FILE="$BASE_DIR/update.log"

GIT_REPOS=(
    "https://github.com/bol-van/zapret.git"
    "https://github.com/ITDogInfo/allow-domains.git"
    "https://github.com/1andrevich/Re-filter-lists.git"
    "https://github.com/igareck/vpn-configs-for-russia.git"
    "https://github.com/wlunlocker/vpn-configs.git"
    "https://github.com/zieng2/wl.git"
    "https://github.com/solovyov-jenya2004/all_subs.git"
    "https://github.com/VOID-Anonymity/V.O.I.D-VPN_Bypass.git"
    "https://github.com/AvenCores/goida-vpn-configs.git"
)

mkdir -p "$REPOS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

UPDATED_COUNT=0
ERROR_COUNT=0

log "=== Запуск обновления списков и репозиториев БС ==="

for repo_url in "${GIT_REPOS[@]}"; do
    repo_name=$(basename "$repo_url" .git)
    target_dir="$REPOS_DIR/$repo_name"

    if [[ -d "$target_dir/.git" ]]; then
        if timeout 25 git -C "$target_dir" pull --ff-only --quiet 2>/dev/null; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    else
        if timeout 35 git clone --depth 1 --quiet "$repo_url" "$target_dir" 2>/dev/null; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    fi
done

# Нормализация и распаковка (в т.ч. base64) всех vless/trojan/hy2 ключей из новых репозиториев
python3 - << 'PYEOF'
import os, base64, re

repos_dir = os.path.expanduser("~/hysett/bypass-lists/repos")
target_repos = ["wl", "all_subs", "V.O.I.D-VPN_Bypass", "goida-vpn-configs"]
uri_re = re.compile(r"(?:vless|trojan|hy2|hysteria2)://[^\s\"'<>]+", re.IGNORECASE)

for rname in target_repos:
    rpath = os.path.join(repos_dir, rname)
    if not os.path.isdir(rpath):
        continue
    found = []
    seen = set()
    for root, dirs, files in os.walk(rpath):
        if ".git" in dirs:
            dirs.remove(".git")
        for fn in sorted(files):
            if fn == "hysett_wl.txt" or fn.endswith((".png", ".jpg", ".gif", ".md", ".py", ".sh", ".json")):
                continue
            fpath = os.path.join(root, fn)
            try:
                if os.path.getsize(fpath) > 15 * 1024 * 1024:
                    continue
                raw = open(fpath, "r", encoding="utf-8", errors="ignore").read().strip()
            except Exception:
                continue
            if not raw:
                continue
            chunks = [raw]
            if "://" not in raw[:200] and len(raw) > 32:
                try:
                    b64_clean = re.sub(r"\s+", "", raw)
                    pad = len(b64_clean) % 4
                    if pad:
                        b64_clean += "=" * (4 - pad)
                    dec = base64.urlsafe_b64decode(b64_clean).decode("utf-8", errors="ignore")
                    if "://" in dec:
                        chunks.append(dec)
                except Exception:
                    pass
            for ch in chunks:
                for m in uri_re.findall(ch):
                    u = m.strip()
                    if u not in seen:
                        seen.add(u)
                        found.append(u)
                        if len(found) >= 1500:
                            break
            if len(found) >= 1500:
                break
    if found:
        out_file = os.path.join(rpath, "hysett_wl.txt")
        with open(out_file, "w", encoding="utf-8") as f:
            f.write("\n".join(found) + "\n")
PYEOF

log "=== Завершено: успешно $UPDATED_COUNT, ошибок $ERROR_COUNT ==="
