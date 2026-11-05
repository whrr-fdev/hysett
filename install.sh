#!/usr/bin/env bash
set -e

PROJ_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Установка HySett (Hyprland Control Center) и всех компонентов ==="

# 1. Установка всех необходимых пакетов и утилит, для которых есть настройки в центре
PKGS=(
    base-devel cmake ninja
    qt6-base qt6-declarative qt6-shadertools qt6-wayland qt6-svg
    hyprland waybar mako hyprlock hyprpicker
    swww mpvpaper
    grim slurp wl-clipboard cliphist
    brightnessctl playerctl wireplumber pavucontrol
    networkmanager nm-connection-editor
    bluez bluez-utils blueman
    btop fastfetch kitty foot fd
    papirus-icon-theme ttf-jetbrains-mono-nerd noto-fonts
    polkit-kde-agent
)

if command -v pacman >/dev/null 2>&1; then
    echo "--> Проверка и установка системных пакетов..."
    sudo pacman -S --needed --noconfirm "${PKGS[@]}" || true
fi

if command -v paru >/dev/null 2>&1; then
    paru -S --needed --noconfirm peaclock awww-bin gpu-screen-recorder 2>/dev/null || true
elif command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm peaclock awww-bin gpu-screen-recorder 2>/dev/null || true
fi

# 2. Копирование всех конфигов, виджетов, шейдеров и переключателя тем в ~/.config
echo "--> Установка конфигураций Hyprland, Waybar, Mako, виджетов и шейдеров..."
mkdir -p ~/.config/hypr/scripts ~/.config/hypr/shaders ~/.config/waybar ~/.config/mako ~/.local/share/applications ~/Pictures/Screens ~/Videos/Records

if [ -d "$PROJ_DIR/dotfiles/hypr" ]; then
    cp -rf "$PROJ_DIR/dotfiles/hypr/"* ~/.config/hypr/ 2>/dev/null || true
    chmod +x ~/.config/hypr/scripts/*.sh ~/.config/hypr/scripts/*.py ~/.config/hypr/scripts/kb_overlay ~/.config/hypr/scripts/clock_overlay 2>/dev/null || true
fi

if [ -d "$PROJ_DIR/dotfiles/waybar" ]; then
    cp -rf "$PROJ_DIR/dotfiles/waybar/"* ~/.config/waybar/ 2>/dev/null || true
fi

if [ -d "$PROJ_DIR/dotfiles/mako" ]; then
    cp -rf "$PROJ_DIR/dotfiles/mako/"* ~/.config/mako/ 2>/dev/null || true
fi

# Адаптируем пути под текущего пользователя ($HOME), если ставится на другом ПК
find ~/.config/hypr ~/.config/waybar -type f \( -name "*.lua" -o -name "*.conf" -o -name "*.sh" -o -name "*.json*" \) \
    -exec sed -i "s|/home/whrr|$HOME|g; s|$HOME/hysett|$PROJ_DIR|g" {} + 2>/dev/null || true

# 3. Сборка проекта HySett
echo "--> Сборка HySett..."
cmake -B "$PROJ_DIR/build" -S "$PROJ_DIR"
cmake --build "$PROJ_DIR/build" -j"$(nproc)"

# 4. Создание .desktop файла
cat << DESKEOF > ~/.local/share/applications/hysett.desktop
[Desktop Entry]
Type=Application
Name=Hyprland Control Center (HySett)
GenericName=Центр управления Hyprland
Comment=Настройки Hyprland, обои, виджеты и глобальный поиск
Exec=$PROJ_DIR/build/hysett
Icon=preferences-system
Terminal=false
Categories=Settings;System;DesktopSettings;
Keywords=hyprland;settings;control;wallpaper;hysett;настройки;обои;
DESKEOF

# 5. Перезапуск фонового демона
pkill -x hysett || true
sleep 0.2
nohup "$PROJ_DIR/build/hysett" --daemon >/dev/null 2>&1 &
echo "=== Установка успешно завершена! Запускаю HySett... ==="
"$PROJ_DIR/build/hysett" &
