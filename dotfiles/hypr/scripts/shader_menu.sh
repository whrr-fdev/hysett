#!/bin/bash
# Экстренное выключение любого активного шейдера экрана
hyprctl eval "hl.config({ debug = { damage_tracking = 2 }, decoration = { screen_shader = '[[EMPTY]]' } })"
notify-send -t 1200 "Шейдеры" "Шейдер экрана отключен"
