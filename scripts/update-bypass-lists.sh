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
)

mkdir -p "$REPOS_DIR"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

UPDATED_COUNT=0
ERROR_COUNT=0

log "=== Запуск обновления списков ==="

for repo_url in "${GIT_REPOS[@]}"; do
    repo_name=$(basename "$repo_url" .git)
    target_dir="$REPOS_DIR/$repo_name"

    if [[ -d "$target_dir/.git" ]]; then
        if git -C "$target_dir" pull --ff-only --quiet; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    else
        if git clone --depth 1 --quiet "$repo_url" "$target_dir"; then
            ((UPDATED_COUNT++))
        else
            ((ERROR_COUNT++))
        fi
    fi
done

log "=== Завершено: успешно $UPDATED_COUNT, ошибок $ERROR_COUNT ==="
