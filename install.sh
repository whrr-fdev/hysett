#!/usr/bin/env bash
set -e

HYSETT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Установка зависимостей HySett..."
sudo pacman -S --needed --noconfirm \
  cmake ninja gcc qt6-base qt6-declarative qt6-shadertools qt6-svg \
  layer-shell-qt python cliphist wl-clipboard mpv mpvpaper awww \
  sing-box bluez-utils pipewire-pulse brightnessctl

mkdir -p ~/.config/hypr/scripts ~/Pictures/Wallpapers ~/Music/YandexMusic "$HYSETT_DIR/backups/archives" "$HYSETT_DIR/bin"

echo "==> Привязка автономных скриптов HySett..."
for f in "$HYSETT_DIR/scripts/"*; do
  bn="$(basename "$f")"
  if [ ! -e "$HOME/.config/hypr/scripts/$bn" ]; then
    ln -sf "$f" "$HOME/.config/hypr/scripts/$bn"
  fi
done

if [ ! -f "$HOME/.config/hypr/scripts/control_center.conf" ]; then
  echo "first_run_completed=0" > "$HOME/.config/hypr/scripts/control_center.conf"
elif ! grep -q "^first_run_completed=" "$HOME/.config/hypr/scripts/control_center.conf"; then
  echo "first_run_completed=0" >> "$HOME/.config/hypr/scripts/control_center.conf"
fi

echo "==> Сборка HySett..."
cmake -B "$HYSETT_DIR/build" -S "$HYSETT_DIR"
cmake --build "$HYSETT_DIR/build" -j"$(nproc)"

echo "==> Запуск фонового демона HySett и открытие Мастера первого запуска..."
pkill -x hysett || true
nohup "$HYSETT_DIR/build/hysett" --daemon >/dev/null 2>&1 &
sleep 0.8
"$HYSETT_DIR/build/hysett" &
echo "==> HySett успешно установлен! ✓"
