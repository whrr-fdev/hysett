#!/usr/bin/env bash
set -uo pipefail
renice -n 15 $$ >/dev/null 2>&1 || true

BASE_DIR="$HOME/hysett/bypass-lists"
REPOS_DIR="$BASE_DIR/repos"
LOG_FILE="$BASE_DIR/update.log"
PROG_FILE="/tmp/hysett_vpn_progress.json"

# Если остался старый пустой клон AvenCores — удаляем его, чтобы клонировать живое зеркало aneek0
if [[ -d "$REPOS_DIR/goida-vpn-configs/.git" ]]; then
    remote_url=$(git -C "$REPOS_DIR/goida-vpn-configs" config --get remote.origin.url 2>/dev/null || true)
    if [[ "$remote_url" == *"AvenCores"* ]]; then
        rm -rf "$REPOS_DIR/goida-vpn-configs"
    fi
fi

GIT_REPOS=(
    "https://github.com/bol-van/zapret.git"
    "https://github.com/ITDogInfo/allow-domains.git"
    "https://github.com/1andrevich/Re-filter-lists.git"
    "https://github.com/igareck/vpn-configs-for-russia.git"
    "https://github.com/wlunlocker/vpn-configs.git"
    "https://github.com/zieng2/wl.git"
    "https://github.com/kort0881/vpn-vless-configs-russia.git"
    "https://github.com/aneek0/goida-vpn-configs.git"
    "https://github.com/Hidashimora/free-vpn-anti-rkn.git"
    "https://github.com/26info/vless-proxy-list.git"
    "https://github.com/solovyov-jenya2004/all_subs.git"
    "https://github.com/VOID-Anonymity/V.O.I.D-VPN_Bypass.git"
)

mkdir -p "$REPOS_DIR"

write_prog() {
    local pct="$1"
    local txt="$2"
    printf '{"percent": %d, "text": "%s"}\n' "$pct" "$txt" > "$PROG_FILE.tmp" && mv -f "$PROG_FILE.tmp" "$PROG_FILE"
}

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

UPDATED_COUNT=0
ERROR_COUNT=0
TOTAL_REPOS=${#GIT_REPOS[@]}
IDX=0

log "=== Запуск обновления списков и репозиториев БС/ЧС ==="
write_prog 5 "Синхронизация репозиториев (0/$TOTAL_REPOS)..."

for repo_url in "${GIT_REPOS[@]}"; do
    ((IDX++))
    repo_name=$(basename "$repo_url" .git)
    target_dir="$REPOS_DIR/$repo_name"
    pct=$((5 + IDX * 55 / TOTAL_REPOS))
    write_prog "$pct" "Репозиторий $IDX/$TOTAL_REPOS: $repo_name..."

    if [[ -d "$target_dir/.git" ]]; then
        if timeout 15 nice -n 15 git -C "$target_dir" pull --ff-only --quiet 2>/dev/null; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    else
        if timeout 25 nice -n 15 git clone --depth 1 --quiet "$repo_url" "$target_dir" 2>/dev/null; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    fi
done

write_prog 68 "Распаковка всех ключей БС и ЧС..."

nice -n 15 python3 - << 'PYEOF'
import os, base64, re

repos_dir = os.path.expanduser("~/hysett/bypass-lists/repos")
target_repos = [
    "wl", "all_subs", "V.O.I.D-VPN_Bypass", "goida-vpn-configs",
    "vpn-vless-configs-russia", "free-vpn-anti-rkn", "vless-proxy-list"
]
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
            if fn == "hysett_wl.txt" or fn.endswith((".png", ".jpg", ".gif", ".md", ".py", ".sh", ".json", ".exe", ".apk", ".zip")):
                continue
            fpath = os.path.join(root, fn)
            try:
                if os.path.getsize(fpath) > 10 * 1024 * 1024:
                    continue
                with open(fpath, "r", encoding="utf-8", errors="ignore") as rf:
                    raw = rf.read(2 * 1024 * 1024).strip()
            except Exception:
                continue
            if not raw:
                continue
            chunks = [raw]
            if "://" not in raw[:200] and 32 < len(raw) < 1048576:
                try:
                    b64_clean = "".join(raw.split())
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
                        if len(found) >= 3000:
                            break
            if len(found) >= 3000:
                break
    if found:
        out_file = os.path.join(rpath, "hysett_wl.txt")
        with open(out_file, "w", encoding="utf-8") as f:
            f.write("\n".join(found) + "\n")
PYEOF

log "=== Завершено: успешно $UPDATED_COUNT, ошибок $ERROR_COUNT ==="
