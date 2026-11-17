#!/usr/bin/env bash
set -e

HYSETT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "==> Установка зависимостей HySett..."
sudo pacman -S --needed --noconfirm \
  cmake ninja gcc qt6-base qt6-declarative qt6-shadertools qt6-svg \
  layer-shell-qt python cliphist wl-clipboard mpv mpvpaper awww \
  sing-box bluez-utils pipewire-pulse brightnessctl

mkdir -p ~/.config/hypr/scripts ~/Pictures/Wallpapers ~/Music/YandexMusic "$HYSETT_DIR/backups/archives" "$HYSETT_DIR/bin"

echo "==> Проверка группы input для Бесконечного Холста..."
if ! groups "$USER" | grep -qw input; then
  sudo usermod -aG input "$USER" || true
fi

echo "==> Привязка автономных скриптов и файлов Бесконечного Холста..."
for f in "$HYSETT_DIR/scripts/"*; do
  bn="$(basename "$f")"
  if [ ! -e "$HOME/.config/hypr/scripts/$bn" ]; then
    ln -sf "$f" "$HOME/.config/hypr/scripts/$bn"
  fi
done

if [ -f "$HYSETT_DIR/scripts/infinite_canvas.lua" ] && [ ! -f "$HOME/.config/hypr/infinite_canvas.lua" ]; then
  cp -f "$HYSETT_DIR/scripts/infinite_canvas.lua" "$HOME/.config/hypr/infinite_canvas.lua"
fi

if [ ! -f "$HOME/.config/hypr/canvas.json" ]; then
  cat << 'JSONEOF' > "$HOME/.config/hypr/canvas.json"
{
  "speed": 3.2,
  "accel": 1.6,
  "min_gap": 12,
  "key_step": 110,
  "init_scale": 0.78,
  "all_workspaces": true,
  "edge_push_enabled": true,
  "inverted": false
}
JSONEOF
fi

if [ -f "$HOME/.config/hypr/hyprland.lua" ] && ! grep -q "infinite_canvas.lua" "$HOME/.config/hypr/hyprland.lua"; then
  cat << 'LUAEOF' >> "$HOME/.config/hypr/hyprland.lua"

-- Бесконечный холст (Infinite Desktop / Canvas Mode)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/infinite_canvas.lua")
hl.bind(mainMod .. " + S", function() if _G.Canvas then _G.Canvas.toggle() end end)
LUAEOF
fi

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
