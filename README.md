# 󰣇 HySett — Hyprland Material You Shell, Control Center & Live Atmosphere

**HySett** — единая автономная графическая оболочка рабочего стола для композитора **Hyprland** (C++20, Qt6 Quick/QML, LayerShellQt и кастомные шейдеры GLSL 440). Заменяет `waybar`, `mako` и `rofi`, объединяя панель задач, демон уведомлений, выпадающий центр управления, системный TUN VPN-клиент (`sing-box`), метеостанцию, системный монитор (`btop`), музыкальный плеер MPRIS2, менеджер обоев и погодный оверлей рабочего стола.

---

## ✨ Ключевые возможности

### 1. Встроенная панель задач (TopBar / Vertical Bar)
- Работает нативно через `Wayland LayerShellQt` с резервированием области экрана (`hysett-strut`) и нулевой задержкой через UNIX-сокеты Hyprland.
- **4 позиции на экране** (*Сверху, Снизу, Слева, Справа*) и **2 режима ширины** (*На всю ширину* / *Компактный островок по центру*). В вертикальном режиме часы идут в 2 строки (`ЧЧ / ММ`), а заголовок окна поворачивается на 90°.
- **Интерактивный Drag & Drop конструктор**: перетаскивание и скрытие любых модулей мышью, настройка отступов, разделителей и ширины заголовка окна (*динамическая* или *фиксированная 60..400px*).
- **Модули панели**: Логотип CachyOS (Поиск), Рабочие столы (*номера 1..5* или *овальные точки*), Погода, Музыкальный плеер (MPRIS2 с перемоткой колесиком), Заголовок активного окна, Индикатор записи экрана (`gpu-screen-recorder`), Монитор ресурсов (`CPU / Temp / RAM`), Системный трей (`StatusNotifierItem` + индикатор VPN), Bluetooth, Wi-Fi, Буфер обмена, Громкость, Язык, Часы и Питание.

### 2. Жидкое слияние краев (GLSL SDF & Liquid Glass)
- **`merged_shell.frag`**: выезжающее окно настроек, меню питания, календарь, буфер обмена и стек уведомлений плавно сливаются со стороной панели задач через полиномиальный гладкий минимум (`smin` SDF) с общей неоновой границей и свечением курсора.
- **Кастомные шейдеры**: объемные 3D-мениски карточек (`liquid_panel.frag`), оптическое преломление контролов (`liquid_glass.frag`), гидродинамический след курсора и волны клика (`cursor_fx.frag`, `click_fx.frag`), переходы между вкладками (*Воронка / Портал / Телепорт* в `vortex_suck.frag`) и процедурное небо погоды (`weather_sky.frag`).

### 3. Material Design 3 Expressive и синхронизация цветов с обоями
- Автоматическое извлечение палитры из текущих статичных и видео-обоев (`awww` / `mpvpaper`) с тональной иерархией поверхностей (`m3Surface`, `m3SurfaceContainer`, `m3SurfaceContainerHigh`) и мгновенным откатом к классическому черному монохрому при выключении тумблера.
- Сквозное перекрашивание системных приложений (`sync_m3_windows.py`): рамки окон Hyprland, живая перезагрузка терминалов `kitty` (`SIGUSR1`), `Firefox` (`userChrome.css` / `userContent.css`), `Google Chrome`, `Nautilus` (GTK3/GTK4 + иконки папок Papirus), `btop`, `AyuGram` и виджетов рабочего стола.
- Тонкие волнистые ползунки (`StyledSlider.qml`) с синусоидальным колебанием и связанные сегментные кнопки (`SegmentedButton.qml`).

### 4. Встроенный системный VPN-клиент (`sing-box` TUN + Split-DNS + Белые списки)
- Работает напрямую через ядро `sing-box` в режиме системного туннеля `singbox_tun0` (`gVisor`, ~15 МБ ОЗУ) без запуска тяжелых GUI и без запроса пароля Polkit.
- Поддержка подписок, ручных `vless://` серверов и **режима белых списков** из локальных репозиториев (`bypass-lists`), размытие ссылок для скриншотов и раздельное туннелирование (`RU Direct` — российские домены и сервисы идут напрямую без потери скорости).

### 5. Демон уведомлений и 25 встроенных экранов
- Нативный DBus-сервис `org.freedesktop.Notifications` со стеком уведомлений у края панели и историей.
- Встроенные инструменты: *Приветствие с живым поиском по настройкам, Глобальный поиск файлов (`fd`/`find`), Погода (прогноз на 28 дней + 3D-шейдер неба), Монитор ресурсов и процессов (Solaris-mode `/proc` + 4 графика 60 FPS), Музыка, VPN, Календарь, Буфер обмена (`cliphist`), Питание, Язык, Окна, Анимации, Курсор, Мониторы, Устройства и Звук, Wi-Fi, Bluetooth, Панель задач, Уведомления, Автозапуск, Бинды, Правила окон, Приложения, Шейдеры экрана, Обои, Виджеты, Живая Атмосфера и Настройки темы*.

---

## 🚀 Флаги запуска и горячие клавиши

| Команда / Флаг | Описание | Хоткей в `hyprland.lua` |
| :--- | :--- | :--- |
| `hysett --daemon` | Фоновый режим (запускает панель задач, демон уведомлений и IPC-сокет) | Автозапуск при старте Hyprland |
| `hysett` | Открыть / закрыть слайдер центра управления | `SUPER + Escape` |
| `hysett --wallpaper` | Полноэкранный режим выбора обоев с `0%` блюра | `SUPER + W` |
| `hysett --apps` | Лаунчер приложений с автофокусом поиска | `SUPER + D` |
| `hysett --search` | Глобальный поиск файлов и программ | Клик по логотипу CachyOS на панели |
| `hysett --clipboard` | Выпадающее окно истории буфера обмена (`cliphist`) | `SUPER + B` |
| `hysett --power` | Выпадающее меню питания с управлением стрелками | `SUPER + M` |
| `hysett --atmosphere-overlay` | Глобальный сквозной погодный оверлей (Дождь / Снег / Листья) | Автозапуск / из вкладки Атмосфера |

---

## 📁 Архитектура проекта

| Путь | Назначение |
| :--- | :--- |
| `CMakeLists.txt` | Конфигурация сборки C++20 / Qt6 (`Core`, `Gui`, `Qml`, `Quick`, `QuickControls2`, `ShaderTools`, `Concurrent`, `DBus`, `LayerShellQt`) и компиляция шейдеров в `.qsb`. |
| `src/main.cpp` | Точка входа, обработка CLI-флагов, инициализация LayerShell-окон и распорки `hysett-strut`. |
| `src/AppInstance.{h,cpp}` | Single-instance локальный UNIX-сокет для мгновенного вызова окон. |
| `src/AppConfig.{h,cpp}` | Конфигурация `control_center.conf`, генератор палитры Material You из обоев, словарь переводов `RU / EN`. |
| `src/ThemeEngine.{h,cpp}` | Управление скруглениями (`theme_toggle.sh`), динамическим блюром и параметрами Liquid Glass. |
| `src/WaybarManager.{h,cpp}` | Движок панели задач, сокет Hyprland, монитор `/proc`, DBus SNI-трей, MPRIS2-плеер, погода, `cliphist` и управление VPN. |
| `src/MakoManager.{h,cpp}` | DBus-демон уведомлений `org.freedesktop.Notifications`, стек попапов и генерация конфига. |
| `src/AtmosphereManager.{h,cpp}` | Физический движок погоды (капли, запотевание, сугробы, 3D-листья). |
| `src/LookManager.{h,cpp}` | Настройки внешнего вида окон Hyprland (`look.lua`) и стек отката `Undo`. |
| `src/AnimsManager.{h,cpp}` | Настройки анимаций и кривых Безье (`anims.lua`). |
| `src/CursorManager.{h,cpp}` | Тема, размер курсора и настройки лупы (`cursor.lua`). |
| `src/MonitorsManager.{h,cpp}` | Разрешение, герцовка, масштаб, VRR, DPMS (`monitors.lua`). |
| `src/DevicesManager.{h,cpp}` | Клавиатура, звук, мышь и тачпад (`devices.lua`). |
| `src/NetworkManager.{h,cpp}` | Сканирование и подключение к Wi-Fi через `nmcli`. |
| `src/BluetoothManager.{h,cpp}` | Управление Bluetooth через `bluetoothctl`. |
| `src/AutostartManager.{h,cpp}` | Управление автозапуском в `hyprland.lua`. |
| `src/BindsManager.{h,cpp}` | Редактор горячих клавиш Hyprland. |
| `src/RulesManager.{h,cpp}` | Редактор правил окон (`window_rule`). |
| `src/AppsManager.{h,cpp}` | Парсер `.desktop` приложений и асинхронный поиск файлов (`fd` / `find`). |
| `src/WallpapersManager.{h,cpp}` | Галерея обоев, кэш миниатюр, управление `awww` и `mpvpaper`. |
| `src/WidgetsManager.{h,cpp}` | Оверлей клавиш (`kb_overlay`), часы (`clock_overlay`) и системный оверлей (`sysinfo_overlay`). |
| `src/ShadersManager.{h,cpp}` | Переключение экранных шейдеров Hyprland. |
| `src/IconImageProvider.{h,cpp}` | Провайдер системных иконок и тонирование иконок трея (`IconPixmap`). |
| `src/HyprIpc.{h,cpp}` | Диспатчер команд Hyprland и глубокая очистка памяти (`malloc_trim`). |
| `scripts/update-bypass-lists.sh` | Скрипт синхронизации Git-репозиториев со списками обхода и бесплатными `vless://` конфигами. |
| `qml/Main.qml` | Главное окно: панель задач, стек уведомлений, морфинг-слайдер и контроллер вкладок. |
| `qml/components/*` | Компоненты Material You (`Sidebar`, `NavButton`, `GlassPanel`, `StyledSlider`, `StyledSwitch`, `SegmentedButton` и др.). |
| `qml/views/*` | Экраны настроек и встроенных утилит (`VpnView`, `WeatherView`, `SysMonView`, `MusicView`, `WallpapersView` и др.). |
| `qml/shaders/*.frag` | Шейдеры GLSL 440 (`merged_shell.frag`, `weather_sky.frag`, `liquid_panel.frag`, `vortex_suck.frag` и др.). |

---

## 🛠 Сборка и запуск

    cd ~/hysett
    cmake -B build -S .
    cmake --build build -j$(nproc)
    pkill -x hysett || true
    ./build/hysett --daemon &
