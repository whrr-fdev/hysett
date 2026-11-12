#include <QTimer>
#include "AppConfig.h"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QRegularExpression>
#include <QStringList>
#include <QMap>
#include <algorithm>
#include <cmath>
#include <QImage>
#include <QFileInfo>
#include <QProcess>

AppConfig::AppConfig(QObject *parent) : QObject(parent) {
    initTranslations();
    load();

    m_wallExtractTimer = new QTimer(this);
    m_wallExtractTimer->setSingleShot(true);
    m_wallExtractTimer->setInterval(400);
    connect(m_wallExtractTimer, &QTimer::timeout, this, [this]() {
        if (m_m3DynamicWallpaperColors) extractPaletteFromWallpaper();
    });

    m_wallWatcher = new QFileSystemWatcher(this);
    QString home = QDir::homePath();
    for (const QString &p : {
        home + "/.cache",
        home + "/.cache/wallpaper-current",
        home + "/.cache/last_wallpaper.txt",
        home + "/.config/hypr/scripts/last_wallpaper.conf"
    }) {
        if (QFileInfo::exists(p)) m_wallWatcher->addPath(p);
    }
    auto triggerWallExtract = [this, home]() {
        for (const QString &p : {
            home + "/.cache/wallpaper-current",
            home + "/.cache/last_wallpaper.txt",
            home + "/.config/hypr/scripts/last_wallpaper.conf"
        }) {
            if (QFileInfo::exists(p) && !m_wallWatcher->files().contains(p))
                m_wallWatcher->addPath(p);
        }
        if (m_m3DynamicWallpaperColors && m_wallExtractTimer) m_wallExtractTimer->start();
    };
    connect(m_wallWatcher, &QFileSystemWatcher::directoryChanged, this, triggerWallExtract);
    connect(m_wallWatcher, &QFileSystemWatcher::fileChanged, this, triggerWallExtract);

    if (m_m3DynamicWallpaperColors) {
        extractPaletteFromWallpaper();
    }
}

QString AppConfig::configFilePath() const {
    return QDir::homePath() + "/.config/hypr/scripts/control_center.conf";
}

void AppConfig::initTranslations() {
    m_enDict = {
        // Боковое меню и карточки приветствия
        // Кнопки, переключатели и остальные вкладки
        {"Поиск по настройкам", "Search settings"},
        {"󰂚  Mako", "󰂚  Mako"},
        {"Уведомления, таймаут, цвета", "Notifications, timeout, colors"},
        {"Уведомления (Mako)", "Notifications (Mako)"},
        {"󰂚  Тест уведомления", "󰂚  Test Notification"},
        {"󰎟  Очистить все", "󰎟  Dismiss All"},
        {"Расположение и геометрия", "Position & Geometry"},
        {"Позиция на экране:", "Screen anchor:"},
        {"Ширина уведомления:", "Notification width:"},
        {"Макс. высота:", "Max height:"},
        {"Внешний отступ (Margin):", "Outer margin:"},
        {"Внутренний отступ (Padding):", "Inner padding:"},
        {"Оформление, рамка и цвета", "Appearance, Border & Colors"},
        {"Прозрачность фона Mako:", "Mako background opacity:"},
        {"Скругление углов:", "Corner radius:"},
        {"Цвет фона уведомлений:", "Notification background color:"},
        {"Цвет текста:", "Text color:"},
        {"Цвет обычной рамки:", "Normal border color:"},
        {"Цвет рамки важных (Critical):", "Critical urgency border color:"},
        {"󰂚  Тест обычного", "󰂚  Test Normal"},
        {"󰀨  Тест важного", "󰀨  Test Critical"},
        {"Поведение и таймаут", "Behavior & Timeout"},
        {"Время показа (мс):", "Display timeout:"},
        {"Макс. уведомлений на экране:", "Max visible notifications:"},
        {"Показывать иконки приложений:", "Show application icons:"},
        {"↺   Сбросить настройки Mako по умолчанию", "↺   Reset Mako Settings to Defaults"},
        {"Выравнивание экрана приветствия:", "Welcome screen alignment:"},
        {"Слева", "Left"},
        {"По центру", "Center"},
        {"Справа", "Right"},
        {"На всех экранах", "All Screens"},
        {"Только приветствие", "Welcome Only"},
        {"Выкл", "Off"},
        {"Вкл", "On"},
        {"В играх", "In Games"},
        {"По часовой", "Clockwise"},
        {"Против часовой", "Counter-CW"},
        {"Навстречу", "Symmetrical"},
        {"Монохром", "Monochrome"},
        {"Холодный лед", "Cold Ice"},
        {"Аврора", "Aurora"},
        {"Теплый неон", "Warm Neon"},
        {"Свой цвет", "Custom Color"},
        {"Кольцо", "Ring"},
        {"Импульс", "Pulse"},
        {"Звезда", "Star"},
        {"Двойная волна", "Double Wave"},
        {"Слайд", "Slide"},
        {"Кроссфейд", "Crossfade"},
        {"Глубина", "Depth"},
        {"Пружина", "Bounce"},
        {"Каскад", "Cascade"},
        {"Воронка", "Black Hole"},
        {"Портал", "Portal"},
        {"Телепорт", "Teleport"},
        {"Все", "All"},
        {"Видео", "Video"},
        {"Фото", "Photo"},
        {"Только файлы", "Files Only"},
        {"Только приложения", "Apps Only"},
        {"Домашняя (~)", "Home (~)"},
        {"Вся система (/)", "Full System (/)"},
        {"1м", "1m"}, {"2м", "2m"}, {"5м", "5m"}, {"10м", "10m"}, {"30м", "30m"},
        {"Интернет", "Internet"},
        {"Документы", "Documents"},
        {"Разработка", "Development"},
        {"Мультимедиа", "Multimedia"},
        {"Графика", "Graphics"},
        {"Система", "System"},
        {"Игры", "Games"},
        {"Утилиты", "Utilities"},
        {"Клавиатура", "Keyboard"},
        {"Мышь", "Mouse"},
        {"Боковые кнопки", "Side Buttons"},
        {"Колесико", "Scroll Wheel"},
        {"Отображать только комбинации клавиш (Ctrl/Alt/Super/Shift)", "Show key combinations only (Ctrl/Alt/Super/Shift)"},
        {"24-часовой формат", "24-hour format"},
        {"Секунды", "Seconds"},
        {"Дата", "Date"},
        {"День недели", "Day of week"},
        {"🕒   Часы Peaclock (Foot)", "🕒   Peaclock Clock (Foot)"},
        {"󰣇   Информер Fastfetch (Foot)", "󰣇   Fastfetch Info (Foot)"},
        {"󰍹   Монитор процессов Btop (Kitty)", "󰍹   Btop Process Monitor (Kitty)"},
        {"Обычная (Normal)", "Normal"},
        {"Отразить (Flipped)", "Flipped"},
        {"Отразить 90°", "Flipped 90°"},
        {"Отразить 180°", "Flipped 180°"},
        {"Отразить 270°", "Flipped 270°"},
        {"Новый пресет", "New Preset"},
        {"Трава", "Grass"},
        {"Сакура", "Sakura"},
        {"✓ Готово", "✓ Done"},
        {"Выбор цвета", "Color Picker"},
        {"Применить", "Apply"},
        {"Сохранить", "Save"},
        {"Удалить", "Delete"},
        {"Добавить", "Add"},
        {" + Добавить", " + Add"},
        {"+ Добавить", "+ Add"},
        {"Обновить", "Refresh"},
        {"Подключить", "Connect"},
        {"Отключить", "Disconnect"},
        {"Поиск...", "Searching..."},
        {"Выключить все эффекты (Normal)", "Disable All Effects (Normal)"},
        {"Шейдеры экрана (GLSL)", "Screen Shaders (GLSL)"},
        {"Настройки курсора и лупы", "Cursor & Magnifier Settings"},
        {"Устройства ввода", "Input Devices"},
        {"Беспроводные сети Wi-Fi", "Wi-Fi Wireless Networks"},
        {"Bluetooth устройства", "Bluetooth Devices"},
        {"Анимации и кривые Безье", "Animations & Bezier Curves"},
        {"Настройка панели Waybar", "Waybar Panel Settings"},
        {"Автозапуск приложений и служб", "Startup Applications & Services"},
        {"Горячие клавиши (Keybinds)", "Keybinds & Shortcuts"},
        {"Правила окон (Window Rules)", "Window Rules"},
        {"Поиск", "Search"},
        {"Окна", "Windows"},
        {"Анимации", "Animations"},
        {"Курсор", "Cursor"},
        {"Мониторы", "Monitors"},
        {"Устройства", "Devices"},
        {"Сеть", "Network"},
        {"Блютуз", "Bluetooth"},
        {"Автозапуск", "Autostart"},
        {"Бинды", "Keybinds"},
        {"Правила окон", "Window Rules"},
        {"Приложения", "Applications"},
                {"Атмосфера", "Atmosphere"},
        {"󰖗  Атмосфера", "󰖗  Atmosphere"},
        {"Дождь, снег, листья и физика", "Rain, snow, leaves & physics"},
        {"Живая атмосфера (Live Atmosphere)", "Live Atmosphere"},
        {"󰖝  Порыв ветра", "󰖝  Wind Gust"},
        {"󰃢  Стряхнуть капли и сугробы", "󰃢  Clear Drops & Snow"},
        {"Режим работы и сезонные профили", "Operation Mode & Seasonal Profiles"},
        {"Внутри окна HySett (Песочница с физикой UI):", "Inside HySett window (UI physics sandbox):"},
        {"Глобальный оверлей рабочего стола (Waybar и окна Hyprland):", "Global desktop overlay (Waybar & Hyprland windows):"},
        {"🌧  Ливень", "🌧  Downpour"},
        {"🍂  Осень (Дождь + Листья)", "🍂  Autumn (Rain + Leaves)"},
        {"❄  Зима (Снег и сугробы)", "❄  Winter (Snow & Drifts)"},
        {"🍁  Листопад", "🍁  Falling Leaves"},
        {"Погодные слои: Дождь, Снег и Листья", "Weather Layers: Rain, Snow & Leaves"},
        {"Включить дождь:", "Enable rain:"},
        {"Интенсивность дождя:", "Rain intensity:"},
        {"Эффект «мокрого стекла» и стекающие капли:", "Wet glass effect & trickling drops:"},
        {"Включить снегопад:", "Enable snowfall:"},
        {"Интенсивность снега:", "Snow intensity:"},
        {"Накопление сугробов на кнопках, карточках и Waybar:", "Accumulate snowdrifts on buttons, cards & Waybar:"},
        {"Добавить падающие листья:", "Add falling leaves:"},
        {"Количество листьев:", "Leaves amount:"},
        {"Палитра листьев:", "Leaves palette:"},
        {"Багряная осень", "Crimson Autumn"},
        {"Золотой клен", "Golden Maple"},
        {"Лес", "Forest"},
        {"Физика, ветер и интерактивность с окнами", "Physics, Wind & Window Interactivity"},
        {"Сила и направление ветра:", "Wind strength & direction:"},
        {"Турбулентность воздуха:", "Air turbulence:"},
        {"Гравитация (скорость падения):", "Gravity (fall speed):"},
        {"Размер частиц:", "Particle scale:"},
        {"Коллизии со всеми элементами внутри HySett (карточки, кнопки, слайдеры):", "Collide with all UI elements inside HySett:"},
        {"Интерактивность с панелью Waybar (препятствие для капель и сугробов):", "Interact with Waybar panel (obstacle for drops & snow):"},
        {"Интерактивность с окнами Hyprland (сброс воды/снега вниз при закрытии окна):", "Interact with Hyprland windows (drop water/snow on close):"},
        {"Конденсат на открытых окнах спустя пару секунд:", "Condensation on open windows after a few seconds:"},
        {"Реакция частиц и сдувание листьев курсором мыши:", "Particle reaction & leaf blowing by mouse cursor:"},
        {"Оптимизация и частота кадров (FPS)", "Optimization & Frame Rate (FPS)"},
        {"Лимит FPS погоды:", "Weather FPS limit:"},
        {"Автопауза (0% GPU) при полноэкранных играх и видео:", "Auto-pause (0% GPU) on fullscreen games & video:"},
        {"↺   Сбросить настройки атмосферы по умолчанию", "↺   Reset Atmosphere Settings to Defaults"},
        {"Шейдеры", "Shaders"},
        {"Обои", "Wallpapers"},
        {"Виджеты", "Widgets"},
        {"Настройки", "Settings"},
        {"Закрыть", "Close"},
        {"Привет, Whrr!", "Hello, Whrr!"},
        {"󰍉  Поиск", "󰍉  Search"},
        {"Файлы системы и программы", "System files & applications"},
        {"󰖲  Окна", "󰖲  Windows"},
        {"Рамки, блюр, прозрачность", "Borders, blur, opacity"},
        {"󱐌  Анимации", "󱐌  Animations"},
        {"Скорости и кривые Безье", "Speeds & Bezier curves"},
        {"󰆿  Курсор", "󰆿  Cursor"},
        {"Тема, размер, лупа", "Theme, size, magnifier"},
        {"󰍹  Мониторы", "󰍹  Monitors"},
        {"Разрешение, Гц, VRR", "Resolution, Hz, VRR"},
        {"󰌌  Устройства", "󰌌  Devices"},
        {"Клавиатура, мышь, тачпад", "Keyboard, mouse, touchpad"},
        {"󰖩  Сеть", "󰖩  Network"},
        {"Wi-Fi сети и подключения", "Wi-Fi networks & connections"},
        {"󰂯  Блютуз", "󰂯  Bluetooth"},
        {"Беспроводные устройства", "Wireless devices"},
        {"󱓞  Waybar", "󱓞  Waybar"},
        {"Позиция, отступы, пилюли", "Position, margins, pills"},
        {"󰒲  Автозапуск", "󰒲  Autostart"},
        {"Службы при старте системы", "Startup services & apps"},
        {"⌨  Бинды", "⌨  Keybinds"},
        {"Горячие клавиши Hyprland", "Hyprland hotkeys"},
        {"󰘳  Правила окон", "󰘳  Window Rules"},
        {"Плавающие окна и размеры", "Floating windows & sizes"},
        {"󰀻  Приложения", "󰀻  Applications"},
        {"Лаунчер системных программ", "System app launcher"},
        {"󰏘  Шейдеры", "󰏘  Shaders"},
        {"Эффекты экрана и CRT", "Screen effects & CRT"},
        {"󰸉  Обои", "󰸉  Wallpapers"},
        {"Галерея, пресеты и демон", "Gallery, presets & daemon"},
        {"󰕰  Виджеты", "󰕰  Widgets"},
        {"Часы, оверлей клавиш, сводка", "Clock, key overlay, stats"},
        {"󰒓  Настройки", "󰒓  Settings"},
        {"Шрифт, масштаб, стекло", "Font, scale, liquid glass"},
        // Поиск и Настройки
        {"Глобальный поиск (Файлы и Приложения)", "Global Search (Files & Applications)"},
        {"󰑐  Поиск...", "󰑐  Searching..."},
        {"Введите название файла, папки или приложения...", "Type file, folder, or application name..."},
        {"Показать:", "Show:"},
        {"Область:", "Scope:"},
        {"󰉋 Папка", "󰉋 Folder"},
        {"󰆏 Путь", "󰆏 Copy Path"},
        {"Папка", "Folder"},
        {"Настройки центра управления", "Control Center Settings"},
        {"Интерфейс", "Interface"},
        {"Язык интерфейса (Language):", "Interface Language:"},
        {"Запоминать последнюю открытую вкладку:", "Remember last opened tab:"},
        {"Высота окна (при след. запуске):", "Window height (on next launch):"},
        {"Масштаб интерфейса (UI Scale):", "Interface scale (UI Scale):"},
        {"Размер шрифта:", "Font size:"},
        {"Текст бокового меню:", "Sidebar text alignment:"},
        {"Отображаемые пункты в боковом меню", "Visible Sidebar Menu Items"},
        {"Показать все", "Show All"},
        {"Цвета и палитра оформления", "Colors & Theme Palette"},
        {"Синхронизировать цвета с основным акцентом:", "Sync colors with main accent:"},
        {"Основной акцентный цвет:", "Main accent color:"},
        {"Цвет свечения границ:", "Border glow color:"},
        {"Цвет курсора и вспышки:", "Cursor & click flash color:"},
        {"Цвет фона окна:", "Window background color:"},
        {"Цвет карточек и панелей:", "Cards & panels color:"},
        {"Сбросить цвета", "Reset Colors"},
        {"Изменить", "Change"},
        {"Подсветка границ окна и курсор", "Window Border Glow & Cursor"},
        {"Режим отображения границ:", "Border display mode:"},
        {"Направление движения:", "Movement direction:"},
        {"Палитра свечения:", "Glow palette:"},
        {"Яркость свечения границ:", "Border glow brightness:"},
        {"Ширина свечения у края:", "Border glow spread:"},
        {"Скорость движения света:", "Light movement speed:"},
        {"Сила свечения и следа от курсора:", "Cursor glow & wake strength:"},
        {"Форма вспышки / волны при клике:", "Click flash / wave shape:"},
        {"Сила вспышки при клике:", "Click flash strength:"},
        {"Анимации переходов между вкладками", "Tab Transition Animations"},
        {"Переход с экрана приветствия:", "Welcome screen transition:"},
        {"Тип анимации между вкладками:", "Tab switch animation:"},
        {"Длительность переходов:", "Transition duration:"},
        {"Прозрачность и эффекты стекла (Liquid Glass)", "Transparency & Liquid Glass"},
        {"Жидкое стекло для кнопок, тумблеров и ползунков:", "Liquid Glass for buttons, switches & sliders:"},
        {"Главный фон (Окно):", "Main background (Window):"},
        {"Интенсивность блюра окна:", "Window blur intensity:"},
        {"Прозрачность диалоговых окон:", "Dialog windows opacity:"},
        {"Блюр диалоговых окон:", "Dialog windows blur:"},
        {"Искажение стекла (Refraction):", "Glass refraction:"},
        {"Боковое меню:", "Sidebar opacity:"},
        {"Карточки и панели:", "Cards & panels opacity:"},
        {"↺   Сбросить настройки центра по умолчанию", "↺   Reset Control Center Settings to Defaults"},
        {"Выкл", "Off"},
        // Обои, Окна, Мониторы, Виджеты, Приложения
        {"Обои рабочего стола", "Desktop Wallpapers"},
        {"Фоновый демон и режим", "Background Daemon & Mode"},
        {"Автосмена обоев:", "Auto-change wallpapers:"},
        {"Режим:", "Mode:"},
        {"Интервал:", "Interval:"},
        {"Случайная анимация:", "Random animation:"},
        {"Скругления окон:", "Rounded corners:"},
        {"Прозрачность вкладки:", "Tab opacity:"},
        {"Блюр вкладки:", "Tab blur:"},
        {"󰒝   Случайные обои", "󰒝   Random Wallpaper"},
        {"Пресеты", "Presets"},
        {"+ Создать", "+ Create"},
        {"Создание нового пресета", "Create New Preset"},
        {"Название:", "Name:"},
        {"Путь к обоям:", "Wallpaper path:"},
        {"📁 Обзор...", "📁 Browse..."},
        {"✏  Записать текущие Обои + Окна", "✏  Capture Current Wallpaper + Windows"},
        {"Прозрачность окон:", "Active window opacity:"},
        {"Неактивные окна:", "Inactive windows:"},
        {"Блюр окон:", "Window blur:"},
        {"Размер блюра:", "Blur size:"},
        {"Сохранить пресет", "Save Preset"},
        {"Окна и оформление рабочего стола", "Windows & Desktop Appearance"},
        {"Прозрачность активного окна:", "Active window opacity:"},
        {"Прозрачность неактивного:", "Inactive window opacity:"},
        {"Затемнять неактивные:", "Dim inactive windows:"},
        {"Сила затемнения:", "Dim strength:"},
        {"Затемнение вокруг (dimaround):", "Dim around:"},
        {"Блюр:", "Blur:"},
        {"Проходы блюра:", "Blur passes:"},
        {"Насыщенность блюра:", "Blur vibrancy:"},
        {"Тени:", "Shadows:"},
        {"Размер теней:", "Shadow range:"},
        {"Отступы между окнами:", "Gaps in:"},
        {"Внешние отступы:", "Gaps out:"},
        {"Толщина рамки:", "Border size:"},
        {"Анимации:", "Animations:"},
        {"Цвет активной рамки (RGBA):", "Active border color (RGBA):"},
        {"Цвет неактивной рамки (RGBA):", "Inactive border color (RGBA):"},
        {"Сбросить к hyprland.lua", "Reset to hyprland.lua"},
        {"Дисплей и Мониторы", "Display & Monitors"},
        {"↺  Обновить список", "↺  Refresh List"},
        {"Разрешение и частота:", "Resolution & refresh rate:"},
        {"Масштабирование (Scale):", "Scaling (Scale):"},
        {"Ориентация экрана:", "Screen orientation:"},
        {"Настройки дисплея (Display Settings)", "Display Settings"},
        {"Адаптивная частота (VRR / FreeSync):", "Variable Refresh Rate (VRR / FreeSync):"},
        {"Пробуждать экран мышью (DPMS):", "Wake screen on mouse move (DPMS):"},
        {"Пробуждать экран клавишами (DPMS):", "Wake screen on key press (DPMS):"},
        {"Сохранить новое разрешение?", "Keep new display settings?"},
        {"✓  Сохранить", "✓  Keep Changes"},
        {"Вернуть назад", "Revert"},
        {"Приложения системы", "System Applications"},
        {"Поиск приложений...", "Search applications..."},
        {"Виджеты и оверлеи", "Widgets & Overlays"},
        {"Оверлей клавиш", "Key Overlay"},
        {"Часы на фоне", "Desktop Clock"},
        {"Информеры", "System Informers"},
        {"Оверлей клавиатуры и мыши", "Keyboard & Mouse Overlay"},
        {"Компоненты отображения", "Display Components"},
        {"Положение и управление", "Position & Controls"},
        {"Расположение на экране:", "Screen position:"},
        {"󰈈  Скрыть/Показать (Super + F9)", "󰈈  Show/Hide (Super + F9)"},
        {"↺  Перезапустить процесс", "↺  Restart Process"},
        {"Часы на рабочем столе", "Desktop Clock"},
        {"Размер часов:", "Clock size:"},
        {"Прозрачность часов:", "Clock opacity:"},
        {"󰆓  Сохранить параметры", "󰆓  Save Settings"},
        {"↺  Перезапустить часы", "↺  Restart Clock"},
        {"Мониторы процессов и системная сводка", "Process Monitors & System Info"}
    };
}

QString AppConfig::trAuto(const QString &ruText) const {
    if (m_language != "en") return ruText;
    auto it = m_enDict.constFind(ruText);
    if (it != m_enDict.constEnd()) return it.value();
    if (ruText.startsWith("↩ Откатить")) {
        QString s = ruText;
        return s.replace("↩ Откатить", "↩ Undo");
    }
    if (ruText.startsWith("Файлы и папки")) {
        QString s = ruText;
        return s.replace("Файлы и папки", "Files & Folders");
    }
    if (ruText.startsWith("Настройка пресета")) {
        QString s = ruText;
        return s.replace("Настройка пресета", "Edit Preset");
    }
    if (ruText.startsWith("Откат к прежнему режиму через")) {
        QString s = ruText;
        s.replace("Откат к прежнему режиму через", "Reverting in");
        s.replace("сек...", "sec...");
        return s;
    }
    return ruText;
}

void AppConfig::syncHyprlandLuaHeight(int h) const {
    QString luaPath = QDir::homePath() + "/.config/hypr/hyprland.lua";
    QFile f(luaPath);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return;
    QString content = QString::fromUtf8(f.readAll());
    f.close();

    QRegularExpression re1(R"((\["com\.whrr\.HyprSettings"\]\s*=\s*\{\s*x\s*=\s*1040\s*,\s*y\s*=\s*)\d+(\s*\}))");
    content.replace(re1, QString("\\1%1\\2").arg(h));

    QRegularExpression re2(R"((match\s*=\s*\{\s*class\s*=\s*"com\.whrr\.HyprSettings"\s*\}[\s\S]{1,120}?size\s*=\s*\{\s*1040\s*,\s*)\d+(\s*\}))");
    content.replace(re2, QString("\\1%1\\2").arg(h));

    if (f.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        f.write(content.toUtf8());
        f.close();
    }
}

void AppConfig::load() {
    QFile file(configFilePath());
    if (file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        QTextStream in(&file);
        while (!in.atEnd()) {
            QString line = in.readLine().trimmed();
            if (line.isEmpty() || line.startsWith('#')) continue;
            int eq = line.indexOf('=');
            if (eq == -1) continue;
            QString key = line.left(eq).trimmed();
            QString val = line.mid(eq + 1).trimmed();

            if (key == "font_size") m_fontSize = std::clamp(val.toInt(), 9, 14);
            else if (key == "ui_scale") m_uiScale = std::clamp(val.toDouble(), 0.8, 1.3);
            else if (key == "window_height") m_windowHeight = std::clamp(val.toInt(), 440, 960);
            else if (key == "align_center") m_alignCenter = (val == "1" || val == "true");
            else if (key == "welcome_align_mode") m_welcomeAlignMode = std::clamp(val.toInt(), 0, 2);
            else if (key == "sidebar_width") m_sidebarWidth = std::clamp(val.toInt(), 110, 260);
            else if (key == "opacity") m_opacity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "sidebar_opacity") m_sidebarOpacity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "card_opacity") m_cardOpacity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "wallpapers_opacity") m_wallpapersOpacity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "wallpapers_blur") m_wallpapersBlur = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "dialog_opacity") m_dialogOpacity = std::clamp(val.toDouble(), 0.05, 1.0);
            else if (key == "dialog_blur") m_dialogBlur = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "auto_glass") m_autoGlass = (val == "1" || val == "true");
            else if (key == "anim_type") m_animType = val;
            else if (key == "welcome_anim_type") m_welcomeAnimType = val;
            else if (key == "anim_duration") m_animDuration = std::clamp(val.toInt(), 0, 1000);
            else if (key == "remember_last_tab") m_rememberLastTab = (val == "1" || val == "true");
            else if (key == "hidden_sidebar_tabs") m_hiddenSidebarTabs = val;
            else if (key == "language") m_language = (val == "en" ? "en" : "ru");
            else if (key == "border_glow_enabled") m_borderGlowEnabled = (val == "1" || val == "true");
            else if (key == "border_glow_all_pages") m_borderGlowAllPages = (val == "1" || val == "true");
            else if (key == "border_glow_intensity") m_borderGlowIntensity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "border_glow_spread") m_borderGlowSpread = std::clamp(val.toDouble(), 0.1, 1.0);
            else if (key == "border_glow_speed") m_borderGlowSpeed = std::clamp(val.toDouble(), 0.1, 2.5);
            else if (key == "border_glow_color_mode") m_borderGlowColorMode = std::clamp(val.toInt(), 0, 4);
            else if (key == "border_glow_direction") m_borderGlowDirection = std::clamp(val.toInt(), 0, 2);
            else if (key == "cursor_glow_intensity") m_cursorGlowIntensity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "click_flash_intensity") m_clickFlashIntensity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "click_flash_shape") m_clickFlashShape = std::clamp(val.toInt(), 0, 3);
            else if (key == "sync_colors_with_accent") m_syncColorsWithAccent = (val == "1" || val == "true");
            else if (key == "accent_color" && QColor::isValidColorName(val)) m_accentColor = QColor(val);
            else if (key == "border_glow_custom_color" && QColor::isValidColorName(val)) m_borderGlowCustomColor = QColor(val);
            else if (key == "cursor_custom_color" && QColor::isValidColorName(val)) m_cursorCustomColor = QColor(val);
            else if (key == "window_bg_color" && QColor::isValidColorName(val)) m_windowBgColor = QColor(val);
            else if (key == "card_bg_color" && QColor::isValidColorName(val)) m_cardBgColor = QColor(val);
            else if (key == "m3_dynamic_wallpaper_colors") m_m3DynamicWallpaperColors = (val == "1" || val == "true");
            else if (key == "m3_secondary_color" && QColor::isValidColorName(val)) m_m3SecondaryColor = QColor(val);
            else if (key == "m3_tertiary_color" && QColor::isValidColorName(val)) m_m3TertiaryColor = QColor(val);
            else if (key == "m3_preset") m_m3Preset = std::clamp(val.toInt(), 0, 5);
            else if (key == "m3_elevation_style") m_m3ElevationStyle = std::clamp(val.toInt(), 0, 2);
            else if (key == "m3_surface_tint") m_m3SurfaceTintStrength = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "m3_contrast") m_m3ContrastLevel = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "m3_window_radius") m_m3WindowRadius = std::clamp(val.toInt(), 4, 32);
            else if (key == "m3_card_radius") m_m3CardRadius = std::clamp(val.toInt(), 4, 28);
            else if (key == "m3_control_radius") m_m3ControlRadius = std::clamp(val.toInt(), 2, 20);
            else if (key == "m3_outline_width") m_m3OutlineWidth = std::clamp(val.toDouble(), 0.0, 3.0);
            else if (key == "m3_outline_opacity") m_m3OutlineOpacity = std::clamp(val.toDouble(), 0.0, 1.0);
            else if (key == "slider_wave_speed") m_sliderWaveSpeed = std::clamp(val.toDouble(), 0.0, 5.0);
            else if (key == "slider_wave_amp") m_sliderWaveAmplitude = std::clamp(val.toDouble(), 0.0, 7.0);
            else if (key == "slider_wave_len") m_sliderWaveLength = std::clamp(val.toDouble(), 8.0, 64.0);
            else if (key == "slider_thickness") m_sliderThickness = std::clamp(val.toDouble(), 1.2, 6.0);
        }
    }
}

static QTimer *s_cfgSaveTimer = nullptr;

void AppConfig::save() {
    if (!s_cfgSaveTimer) {
        s_cfgSaveTimer = new QTimer(this);
        s_cfgSaveTimer->setSingleShot(true);
        s_cfgSaveTimer->setInterval(150);
        connect(s_cfgSaveTimer, &QTimer::timeout, this, [this]() {
            QMap<QString, QString> extra;
            QFile rfile(configFilePath());
            if (rfile.open(QIODevice::ReadOnly | QIODevice::Text)) {
                QTextStream in(&rfile);
                while (!in.atEnd()) {
                    QString line = in.readLine().trimmed();
                    int eq = line.indexOf('=');
                    if (eq != -1) extra[line.left(eq).trimmed()] = line.mid(eq + 1).trimmed();
                }
                rfile.close();
            }
            extra["font_size"] = QString::number(m_fontSize);
            extra["ui_scale"] = QString::number(m_uiScale, 'f', 2);
            extra["window_height"] = QString::number(m_windowHeight);
            extra["align_center"] = m_alignCenter ? "1" : "0";
            extra["welcome_align_mode"] = QString::number(m_welcomeAlignMode);
            extra["sidebar_width"] = QString::number(m_sidebarWidth);
            extra["opacity"] = QString::number(m_opacity, 'f', 2);
            extra["sidebar_opacity"] = QString::number(m_sidebarOpacity, 'f', 2);
            extra["card_opacity"] = QString::number(m_cardOpacity, 'f', 2);
            extra["wallpapers_opacity"] = QString::number(m_wallpapersOpacity, 'f', 2);
            extra["wallpapers_blur"] = QString::number(m_wallpapersBlur, 'f', 2);
            extra["dialog_opacity"] = QString::number(m_dialogOpacity, 'f', 2);
            extra["dialog_blur"] = QString::number(m_dialogBlur, 'f', 2);
            extra["auto_glass"] = m_autoGlass ? "1" : "0";
            extra["anim_type"] = m_animType;
            extra["welcome_anim_type"] = m_welcomeAnimType;
            extra["anim_duration"] = QString::number(m_animDuration);
            extra["remember_last_tab"] = m_rememberLastTab ? "1" : "0";
            extra["hidden_sidebar_tabs"] = m_hiddenSidebarTabs;
            extra["language"] = m_language;
            extra["border_glow_enabled"] = m_borderGlowEnabled ? "1" : "0";
            extra["border_glow_all_pages"] = m_borderGlowAllPages ? "1" : "0";
            extra["border_glow_intensity"] = QString::number(m_borderGlowIntensity, 'f', 2);
            extra["border_glow_spread"] = QString::number(m_borderGlowSpread, 'f', 2);
            extra["border_glow_speed"] = QString::number(m_borderGlowSpeed, 'f', 2);
            extra["border_glow_color_mode"] = QString::number(m_borderGlowColorMode);
            extra["border_glow_direction"] = QString::number(m_borderGlowDirection);
            extra["cursor_glow_intensity"] = QString::number(m_cursorGlowIntensity, 'f', 2);
            extra["click_flash_intensity"] = QString::number(m_clickFlashIntensity, 'f', 2);
            extra["click_flash_shape"] = QString::number(m_clickFlashShape);
            extra["sync_colors_with_accent"] = m_syncColorsWithAccent ? "1" : "0";
            extra["accent_color"] = m_accentColor.name(QColor::HexRgb);
            extra["border_glow_custom_color"] = m_borderGlowCustomColor.name(QColor::HexRgb);
            extra["cursor_custom_color"] = m_cursorCustomColor.name(QColor::HexRgb);
            extra["window_bg_color"] = m_windowBgColor.name(QColor::HexRgb);
            extra["card_bg_color"] = m_cardBgColor.name(QColor::HexRgb);
            extra["window_open_anim_type"] = m_windowOpenAnimType;
            extra["m3_dynamic_wallpaper"] = m_m3DynamicWallpaperColors ? "1" : "0";
            extra["m3_dynamic_wallpaper_colors"] = m_m3DynamicWallpaperColors ? "1" : "0";
            extra["m3_preset"] = QString::number(m_m3Preset);
            extra["m3_window_radius"] = QString::number(m_m3WindowRadius);
            extra["m3_card_radius"] = QString::number(m_m3CardRadius);
            extra["m3_control_radius"] = QString::number(m_m3ControlRadius);
            extra["m3_surface_tint"] = QString::number(m_m3SurfaceTintStrength, 'f', 2);
            extra["m3_contrast"] = QString::number(m_m3ContrastLevel, 'f', 2);
            extra["m3_contrast_level"] = QString::number(m_m3ContrastLevel, 'f', 2);
            extra["m3_elevation_style"] = QString::number(m_m3ElevationStyle);
            extra["m3_outline_width"] = QString::number(m_m3OutlineWidth, 'f', 1);
            extra["m3_outline_opacity"] = QString::number(m_m3OutlineOpacity, 'f', 2);
            extra["m3_secondary_color"] = m_m3SecondaryColor.name(QColor::HexRgb);
            extra["m3_tertiary_color"] = m_m3TertiaryColor.name(QColor::HexRgb);
            extra["slider_wave_speed"] = QString::number(m_sliderWaveSpeed, 'f', 2);
            extra["slider_wave_amp"] = QString::number(m_sliderWaveAmplitude, 'f', 2);
            extra["slider_wave_len"] = QString::number(m_sliderWaveLength, 'f', 1);
            extra["slider_thickness"] = QString::number(m_sliderThickness, 'f', 1);

            QFile wfile(configFilePath());
            if (wfile.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
                QTextStream out(&wfile);
                for (auto it = extra.begin(); it != extra.end(); ++it) out << it.key() << "=" << it.value() << "\n";
                wfile.close();
            }
            QProcess::startDetached("/usr/bin/python3", {QDir::homePath() + "/.config/hypr/scripts/sync_m3_windows.py"});
        });
    }
    s_cfgSaveTimer->start();
}

QColor AppConfig::accentTextColor() const {
    double lum = 0.299 * m_accentColor.redF() + 0.587 * m_accentColor.greenF() + 0.114 * m_accentColor.blueF();
    return lum > 0.52 ? QColor("#000000") : QColor("#ffffff");
}

bool AppConfig::isTabVisible(int idx) const {
    if (m_hiddenSidebarTabs.trimmed().isEmpty()) return true;
    const QStringList parts = m_hiddenSidebarTabs.split(',', Qt::SkipEmptyParts);
    return !parts.contains(QString::number(idx));
}

void AppConfig::setTabVisible(int idx, bool visible) {
    QStringList parts = m_hiddenSidebarTabs.split(',', Qt::SkipEmptyParts);
    QString sIdx = QString::number(idx);
    if (visible) parts.removeAll(sIdx);
    else if (!parts.contains(sIdx)) parts.append(sIdx);
    setHiddenSidebarTabs(parts.join(','));
}

void AppConfig::setHiddenSidebarTabs(const QString &v) {
    if (m_hiddenSidebarTabs != v) { m_hiddenSidebarTabs = v; emit hiddenSidebarTabsChanged(); save(); }
}

void AppConfig::setLanguage(const QString &v) {
    QString clean = (v == "en" ? "en" : "ru");
    if (m_language != clean) { m_language = clean; emit languageChanged(); save(); }
}

void AppConfig::setFontSize(int v) { v = std::clamp(v, 9, 14); if (m_fontSize != v) { m_fontSize = v; emit fontSizeChanged(); save(); } }
void AppConfig::setUiScale(qreal v) { v = std::clamp(v, 0.8, 1.3); if (!qFuzzyCompare(m_uiScale, v)) { m_uiScale = v; emit uiScaleChanged(); save(); } }
void AppConfig::setWindowHeight(int v) { v = std::clamp(v, 440, 960); if (m_windowHeight != v) { m_windowHeight = v; emit windowHeightChanged(); save(); syncHyprlandLuaHeight(v); } }
void AppConfig::setAlignCenter(bool v) { if (m_alignCenter != v) { m_alignCenter = v; emit alignCenterChanged(); save(); } }
void AppConfig::setWelcomeAlignMode(int v) { v = std::clamp(v, 0, 2); if (m_welcomeAlignMode != v) { m_welcomeAlignMode = v; emit welcomeAlignModeChanged(); save(); } }
void AppConfig::setSidebarWidth(int v) { v = std::clamp(v, 110, 260); if (m_sidebarWidth != v) { m_sidebarWidth = v; emit sidebarWidthChanged(); save(); } }
void AppConfig::setOpacity(qreal v) { v = std::round(std::clamp(v, 0.0, 1.0) * 200.0) / 200.0; if (std::abs(m_opacity - v) >= 0.004) { m_opacity = v; emit opacityChanged(); save(); } }
void AppConfig::setSidebarOpacity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_sidebarOpacity, v)) { m_sidebarOpacity = v; emit sidebarOpacityChanged(); save(); } }
void AppConfig::setCardOpacity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_cardOpacity, v)) { m_cardOpacity = v; emit cardOpacityChanged(); save(); } }
void AppConfig::setWallpapersOpacity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_wallpapersOpacity, v)) { m_wallpapersOpacity = v; emit wallpapersOpacityChanged(); save(); } }
void AppConfig::setWallpapersBlur(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_wallpapersBlur, v)) { m_wallpapersBlur = v; emit wallpapersBlurChanged(); save(); } }
void AppConfig::setDialogOpacity(qreal v) { v = std::clamp(v, 0.05, 1.0); if (!qFuzzyCompare(m_dialogOpacity, v)) { m_dialogOpacity = v; emit dialogOpacityChanged(); save(); } }
void AppConfig::setDialogBlur(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_dialogBlur, v)) { m_dialogBlur = v; emit dialogBlurChanged(); save(); } }
void AppConfig::setAutoGlass(bool v) { if (m_autoGlass != v) { m_autoGlass = v; emit autoGlassChanged(); save(); } }
void AppConfig::setAnimType(const QString &v) { if (m_animType != v) { m_animType = v; emit animTypeChanged(); save(); } }
void AppConfig::setWelcomeAnimType(const QString &v) { if (m_welcomeAnimType != v) { m_welcomeAnimType = v; emit welcomeAnimTypeChanged(); save(); } }
void AppConfig::setAnimDuration(int v) { v = std::clamp(v, 0, 1000); if (m_animDuration != v) { m_animDuration = v; emit animDurationChanged(); save(); } }
void AppConfig::setRememberLastTab(bool v) { if (m_rememberLastTab != v) { m_rememberLastTab = v; emit rememberLastTabChanged(); save(); } }
void AppConfig::setBorderGlowEnabled(bool v) { if (m_borderGlowEnabled != v) { m_borderGlowEnabled = v; emit borderGlowEnabledChanged(); save(); } }
void AppConfig::setBorderGlowAllPages(bool v) { if (m_borderGlowAllPages != v) { m_borderGlowAllPages = v; emit borderGlowAllPagesChanged(); save(); } }
void AppConfig::setBorderGlowIntensity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_borderGlowIntensity, v)) { m_borderGlowIntensity = v; emit borderGlowIntensityChanged(); save(); } }
void AppConfig::setBorderGlowSpread(qreal v) { v = std::clamp(v, 0.1, 1.0); if (!qFuzzyCompare(m_borderGlowSpread, v)) { m_borderGlowSpread = v; emit borderGlowSpreadChanged(); save(); } }
void AppConfig::setBorderGlowSpeed(qreal v) { v = std::clamp(v, 0.1, 2.5); if (!qFuzzyCompare(m_borderGlowSpeed, v)) { m_borderGlowSpeed = v; emit borderGlowSpeedChanged(); save(); } }
void AppConfig::setBorderGlowColorMode(int v) { v = std::clamp(v, 0, 4); if (m_borderGlowColorMode != v) { m_borderGlowColorMode = v; emit borderGlowColorModeChanged(); save(); } }
void AppConfig::setBorderGlowDirection(int v) { v = std::clamp(v, 0, 2); if (m_borderGlowDirection != v) { m_borderGlowDirection = v; emit borderGlowDirectionChanged(); save(); } }
void AppConfig::setCursorGlowIntensity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_cursorGlowIntensity, v)) { m_cursorGlowIntensity = v; emit cursorGlowIntensityChanged(); save(); } }
void AppConfig::setClickFlashIntensity(qreal v) { v = std::clamp(v, 0.0, 1.0); if (!qFuzzyCompare(m_clickFlashIntensity, v)) { m_clickFlashIntensity = v; emit clickFlashIntensityChanged(); save(); } }
void AppConfig::setClickFlashShape(int v) { v = std::clamp(v, 0, 3); if (m_clickFlashShape != v) { m_clickFlashShape = v; emit clickFlashShapeChanged(); save(); } }

void AppConfig::setSyncColorsWithAccent(bool v) {
    if (m_syncColorsWithAccent != v) {
        m_syncColorsWithAccent = v;
        if (v) {
            m_borderGlowCustomColor = m_accentColor;
            m_cursorCustomColor = m_accentColor;
            m_borderGlowColorMode = 4;
            emit borderGlowCustomColorChanged();
            emit cursorCustomColorChanged();
            emit borderGlowColorModeChanged();
        }
        emit syncColorsWithAccentChanged();
        save();
    }
}

void AppConfig::setAccentColor(const QColor &c) {
    if (!c.isValid() || m_accentColor == c) return;
    m_accentColor = c;
    emit accentColorChanged();
    if (m_syncColorsWithAccent) {
        m_borderGlowCustomColor = c;
        m_cursorCustomColor = c;
        m_borderGlowColorMode = 4;
        emit borderGlowCustomColorChanged();
        emit cursorCustomColorChanged();
        emit borderGlowColorModeChanged();
    }
    save();
}

void AppConfig::setBorderGlowCustomColor(const QColor &c) {
    if (!c.isValid() || m_borderGlowCustomColor == c) return;
    m_borderGlowCustomColor = c;
    m_borderGlowColorMode = 4;
    emit borderGlowCustomColorChanged();
    emit borderGlowColorModeChanged();
    save();
}

void AppConfig::setCursorCustomColor(const QColor &c) {
    if (!c.isValid() || m_cursorCustomColor == c) return;
    m_cursorCustomColor = c;
    emit cursorCustomColorChanged();
    save();
}

void AppConfig::setWindowBgColor(const QColor &c) {
    if (!c.isValid() || m_windowBgColor == c) return;
    m_windowBgColor = c;
    emit windowBgColorChanged();
    save();
}

void AppConfig::setCardBgColor(const QColor &c) {
    if (!c.isValid() || m_cardBgColor == c) return;
    m_cardBgColor = c;
    emit cardBgColorChanged();
    save();
}

void AppConfig::resetColors() {
    m_syncColorsWithAccent = true;
    m_accentColor = QColor("#ffffff");
    m_borderGlowCustomColor = QColor("#ffffff");
    m_cursorCustomColor = QColor("#ffffff");
    m_windowBgColor = QColor("#0a0a0c");
    m_cardBgColor = QColor("#141419");
    m_borderGlowColorMode = 0;
    emit syncColorsWithAccentChanged();
    emit accentColorChanged();
    emit borderGlowCustomColorChanged();
    emit cursorCustomColorChanged();
    emit windowBgColorChanged();
    emit cardBgColorChanged();
    emit borderGlowColorModeChanged();
    save();
}

void AppConfig::resetDefaults() {
    setFontSize(11);
    setUiScale(1.0);
    setWindowHeight(720);
    setAlignCenter(false);
    setWelcomeAlignMode(1);
    setSidebarWidth(136);
    setOpacity(0.70);
    setSidebarOpacity(0.00);
    setCardOpacity(0.10);
    setWallpapersOpacity(0.59);
    setWallpapersBlur(0.15);
    setDialogOpacity(0.45);
    setDialogBlur(0.65);
    setAutoGlass(true);
    setAnimType("blackhole");
    setWelcomeAnimType("blackhole");
    setAnimDuration(150);
    setRememberLastTab(false);
    setHiddenSidebarTabs("");
    setBorderGlowEnabled(true);
    setBorderGlowAllPages(true);
    setBorderGlowIntensity(0.75);
    setBorderGlowSpread(0.45);
    setBorderGlowSpeed(1.00);
    setBorderGlowDirection(0);
    setCursorGlowIntensity(0.65);
    setClickFlashIntensity(0.70);
    setClickFlashShape(0);
    resetColors();
}

QString AppConfig::consumeLaunchCmd() {
    QFile f("/tmp/hysett_launch_cmd");
    if (!f.exists()) return "";
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text)) return "";
    QString cmd = QString::fromUtf8(f.readAll()).trimmed();
    f.close();
    f.remove();
    return cmd;
}

bool AppConfig::isDaemonStart() const {
    return qEnvironmentVariable("HYSETT_DAEMON_START") == "1";
}

QColor AppConfig::m3Primary() const {
    return m_accentColor;
}

QColor AppConfig::m3PrimaryContainer() const {
    float h, s, l, a;
    m_accentColor.getHslF(&h, &s, &l, &a);
    float targetL = std::clamp(0.20f + float(m_m3ContrastLevel) * 0.10f, 0.14f, 0.38f);
    return QColor::fromHslF(h < 0 ? 0.6f : h, std::clamp(s * 0.72f, 0.0f, 1.0f), targetL, 0.94f);
}

QColor AppConfig::m3OnPrimaryContainer() const {
    float h, s, l, a;
    m_accentColor.getHslF(&h, &s, &l, &a);
    return QColor::fromHslF(h < 0 ? 0.6f : h, std::clamp(s * 0.90f, 0.0f, 1.0f), 0.92f, 1.0f);
}

QColor AppConfig::m3SecondaryContainer() const {
    float h, s, l, a;
    m_m3SecondaryColor.getHslF(&h, &s, &l, &a);
    if (m_syncColorsWithAccent) m_accentColor.getHslF(&h, &s, &l, &a);
    return QColor::fromHslF(h < 0 ? 0.6f : h, std::clamp(s * 0.45f, 0.0f, 1.0f), 0.22f, 0.90f);
}

QColor AppConfig::m3TertiaryContainer() const {
    float h, s, l, a;
    m_m3TertiaryColor.getHslF(&h, &s, &l, &a);
    return QColor::fromHslF(h < 0 ? 0.8f : h, std::clamp(s * 0.55f, 0.0f, 1.0f), 0.25f, 0.90f);
}

QColor AppConfig::m3Surface() const {
    float tint = float(m_m3SurfaceTintStrength) * 0.10f;
    float base = 1.0f - tint;
    return QColor::fromRgbF(
        std::clamp(m_windowBgColor.redF() * base + m_accentColor.redF() * tint, 0.0f, 1.0f),
        std::clamp(m_windowBgColor.greenF() * base + m_accentColor.greenF() * tint, 0.0f, 1.0f),
        std::clamp(m_windowBgColor.blueF() * base + m_accentColor.blueF() * tint, 0.0f, 1.0f),
        1.0f
    );
}

QColor AppConfig::m3SurfaceContainer() const {
    float tint = float(m_m3SurfaceTintStrength) * 0.16f;
    float base = 1.0f - tint * 0.75f;
    return QColor::fromRgbF(
        std::clamp(m_cardBgColor.redF() * base + m_accentColor.redF() * tint, 0.0f, 1.0f),
        std::clamp(m_cardBgColor.greenF() * base + m_accentColor.greenF() * tint, 0.0f, 1.0f),
        std::clamp(m_cardBgColor.blueF() * base + m_accentColor.blueF() * tint, 0.0f, 1.0f),
        1.0f
    );
}

QColor AppConfig::m3SurfaceContainerHigh() const {
    float tint = float(m_m3SurfaceTintStrength) * 0.22f;
    float lift = 0.015f + float(m_m3ContrastLevel) * 0.02f;
    return QColor::fromRgbF(
        std::clamp(m_cardBgColor.redF() * 0.82f + m_accentColor.redF() * tint + lift, 0.0f, 1.0f),
        std::clamp(m_cardBgColor.greenF() * 0.82f + m_accentColor.greenF() * tint + lift, 0.0f, 1.0f),
        std::clamp(m_cardBgColor.blueF() * 0.82f + m_accentColor.blueF() * tint + lift, 0.0f, 1.0f),
        1.0f
    );
}

QColor AppConfig::m3Outline() const {
    float c = 0.32f + float(m_m3ContrastLevel) * 0.35f;
    return QColor::fromRgbF(
        std::clamp(c + m_accentColor.redF() * 0.28f, 0.0f, 1.0f),
        std::clamp(c + m_accentColor.greenF() * 0.28f, 0.0f, 1.0f),
        std::clamp(c + m_accentColor.blueF() * 0.28f, 0.0f, 1.0f),
        std::clamp(float(m_m3OutlineOpacity), 0.0f, 1.0f)
    );
}

void AppConfig::setM3DynamicWallpaperColors(bool v) {
    if (m_m3DynamicWallpaperColors != v) {
        m_m3DynamicWallpaperColors = v;
        if (v) {
            emit m3AttributesChanged();
            save();
            extractPaletteFromWallpaper();
        } else {
            resetToDefaultMonochrome();
        }
    }
}

void AppConfig::extractPaletteFromWallpaper() {
    QString linkPath = QDir::homePath() + "/.cache/wallpaper-current";
    QString lockBgPath = QDir::homePath() + "/.cache/lock_bg.png";
    QString target = QFileInfo(linkPath).symLinkTarget();
    if (target.isEmpty()) target = linkPath;

    QImage img(target);
    if (img.isNull()) {
        // Если обои — видео (mpvpaper), обновляем/берем кадр из ~/.cache/lock_bg.png
        QProcess::execute(QDir::homePath() + "/.config/hypr/scripts/update_lock_bg.sh", {});
        img.load(lockBgPath);
    }
    if (img.isNull()) return;

    QImage small = img.scaled(64, 64, Qt::IgnoreAspectRatio, Qt::FastTransformation);
    double binWeight[36] = {0.0};
    double binHueSum[36] = {0.0};
    double binSatSum[36] = {0.0};

    for (int y = 0; y < small.height(); ++y) {
        for (int x = 0; x < small.width(); ++x) {
            QColor px = small.pixelColor(x, y);
            float h, s, l, a;
            px.getHslF(&h, &s, &l, &a);
            if (h < 0.0f || s < 0.02f || l < 0.05f || l > 0.95f) continue;
            double chromaWeight = double(s) * (1.0 - std::abs(2.0 * double(l) - 1.0) * 0.75);
            int bin = std::clamp(int(h * 36.0f), 0, 35);
            binWeight[bin] += chromaWeight;
            binHueSum[bin] += double(h) * chromaWeight;
            binSatSum[bin] += double(s) * chromaWeight;
        }
    }

    int bestBin = -1;
    double maxW = 0.0;
    for (int i = 0; i < 36; ++i) {
        if (binWeight[i] > maxW) {
            maxW = binWeight[i];
            bestBin = i;
        }
    }

    if (bestBin == -1 || maxW < 0.005) {
        // Нейтрально-монохромные обои
        m_accentColor = QColor("#d0d8e8");
        m_m3SecondaryColor = QColor("#b8c0d0");
        m_m3TertiaryColor = QColor("#d4c4d8");
        m_windowBgColor = QColor("#111317");
        m_cardBgColor = QColor("#1c1f26");
    } else {
        float domH = float(binHueSum[bestBin] / maxW);
        float avgS = float(binSatSum[bestBin] / maxW);
        float priS = std::clamp(avgS * 1.85f + 0.32f, 0.52f, 0.88f);

        m_accentColor = QColor::fromHslF(domH, priS, 0.78f);
        m_m3SecondaryColor = QColor::fromHslF(std::fmod(domH + 0.035f, 1.0f), std::clamp(priS * 0.48f, 0.26f, 0.58f), 0.74f);
        m_m3TertiaryColor = QColor::fromHslF(std::fmod(domH + 0.15f, 1.0f), std::clamp(priS * 0.70f, 0.36f, 0.78f), 0.80f);
        m_windowBgColor = QColor::fromHslF(domH, std::clamp(priS * 0.32f, 0.14f, 0.35f), 0.045f);
        m_cardBgColor = QColor::fromHslF(domH, std::clamp(priS * 0.36f, 0.16f, 0.40f), 0.085f);
    }

    if (m_syncColorsWithAccent) {
        m_borderGlowCustomColor = m_accentColor;
        m_cursorCustomColor = m_accentColor;
        emit borderGlowCustomColorChanged();
        emit cursorCustomColorChanged();
    }
    emit accentColorChanged();
    emit windowBgColorChanged();
    emit cardBgColorChanged();
    emit m3AttributesChanged();
    save();
}

void AppConfig::setM3SecondaryColor(const QColor &c) {
    if (!c.isValid() || m_m3SecondaryColor == c) return;
    m_m3SecondaryColor = c;
    emit accentColorChanged();
    emit m3AttributesChanged();
    save();
}

void AppConfig::setM3TertiaryColor(const QColor &c) {
    if (!c.isValid() || m_m3TertiaryColor == c) return;
    m_m3TertiaryColor = c;
    emit accentColorChanged();
    emit m3AttributesChanged();
    save();
}

void AppConfig::applyM3Preset(int idx) {
    idx = std::clamp(idx, 0, 5);
    m_m3Preset = idx;
    m_m3DynamicWallpaperColors = false;
    struct Preset { const char *pri; const char *sec; const char *ter; const char *surf; const char *card; };
    static const Preset presets[6] = {
        {"#a8c7fa", "#bec6dc", "#debcdf", "#0a0c10", "#13161e"},
        {"#82f8c6", "#b4ccc0", "#a6cce0", "#090e0c", "#111916"},
        {"#d0bcff", "#ccc2dc", "#efb8c8", "#0c0a10", "#16141c"},
        {"#ffb1c8", "#e2bdc6", "#efbd94", "#100a0c", "#1b1316"},
        {"#ffba42", "#ddc2a1", "#b8cea1", "#0f0c08", "#1a150f"},
        {"#66d9ef", "#b1cbd0", "#bac6ea", "#090d0f", "#12181b"}
    };
    m_accentColor = QColor(presets[idx].pri);
    m_m3SecondaryColor = QColor(presets[idx].sec);
    m_m3TertiaryColor = QColor(presets[idx].ter);
    m_windowBgColor = QColor(presets[idx].surf);
    m_cardBgColor = QColor(presets[idx].card);
    if (m_syncColorsWithAccent) {
        m_borderGlowCustomColor = m_accentColor;
        m_cursorCustomColor = m_accentColor;
        emit borderGlowCustomColorChanged();
        emit cursorCustomColorChanged();
    }
    emit accentColorChanged();
    emit windowBgColorChanged();
    emit cardBgColorChanged();
    emit m3AttributesChanged();
    save();
}

void AppConfig::setM3ElevationStyle(int v) {
    v = std::clamp(v, 0, 2);
    if (m_m3ElevationStyle != v) { m_m3ElevationStyle = v; emit m3AttributesChanged(); emit cardBgColorChanged(); save(); }
}

void AppConfig::setM3SurfaceTintStrength(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (!qFuzzyCompare(m_m3SurfaceTintStrength, v)) {
        m_m3SurfaceTintStrength = v;
        emit m3AttributesChanged();
        emit windowBgColorChanged();
        emit cardBgColorChanged();
        save();
    }
}

void AppConfig::setM3ContrastLevel(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (!qFuzzyCompare(m_m3ContrastLevel, v)) {
        m_m3ContrastLevel = v;
        emit m3AttributesChanged();
        emit accentColorChanged();
        emit cardBgColorChanged();
        save();
    }
}

void AppConfig::setM3WindowRadius(int v) {
    v = std::clamp(v, 4, 32);
    if (m_m3WindowRadius != v) { m_m3WindowRadius = v; emit m3AttributesChanged(); save(); }
}

void AppConfig::setM3CardRadius(int v) {
    v = std::clamp(v, 4, 28);
    if (m_m3CardRadius != v) { m_m3CardRadius = v; emit m3AttributesChanged(); save(); }
}

void AppConfig::setM3ControlRadius(int v) {
    v = std::clamp(v, 2, 20);
    if (m_m3ControlRadius != v) { m_m3ControlRadius = v; emit m3AttributesChanged(); save(); }
}

void AppConfig::setM3OutlineWidth(qreal v) {
    v = std::clamp(v, 0.0, 3.0);
    if (!qFuzzyCompare(m_m3OutlineWidth, v)) { m_m3OutlineWidth = v; emit m3AttributesChanged(); save(); }
}

void AppConfig::setM3OutlineOpacity(qreal v) {
    v = std::clamp(v, 0.0, 1.0);
    if (!qFuzzyCompare(m_m3OutlineOpacity, v)) { m_m3OutlineOpacity = v; emit m3AttributesChanged(); emit accentColorChanged(); save(); }
}

void AppConfig::resetM3Attributes() {
    m_m3ElevationStyle = 0;
    m_m3SurfaceTintStrength = 0.22;
    m_m3ContrastLevel = 0.50;
    m_m3WindowRadius = 20;
    m_m3CardRadius = 16;
    m_m3ControlRadius = 10;
    m_m3OutlineWidth = 1.0;
    m_m3OutlineOpacity = 0.28;
    m_m3DynamicWallpaperColors = true;
    extractPaletteFromWallpaper();
}

void AppConfig::resetToDefaultMonochrome() {
    m_m3DynamicWallpaperColors = false;
    m_m3Preset = -1;
    m_m3SurfaceTintStrength = 0.0;
    m_m3ContrastLevel = 0.50;
    m_accentColor = QColor("#ffffff");
    m_m3SecondaryColor = QColor("#2b2d36");
    m_m3TertiaryColor = QColor("#383b46");
    m_windowBgColor = QColor("#0a0a0c");
    m_cardBgColor = QColor("#121318");
    m_borderGlowCustomColor = QColor("#ffffff");
    m_cursorCustomColor = QColor("#ffffff");
    m_borderGlowColorMode = 0;
    emit syncColorsWithAccentChanged();
    emit accentColorChanged();
    emit borderGlowCustomColorChanged();
    emit cursorCustomColorChanged();
    emit windowBgColorChanged();
    emit cardBgColorChanged();
    emit borderGlowColorModeChanged();
    emit m3AttributesChanged();
    save();
}

void AppConfig::setSliderWaveSpeed(qreal v) {
    v = std::clamp(v, 0.0, 5.0);
    if (!qFuzzyCompare(m_sliderWaveSpeed, v)) { m_sliderWaveSpeed = v; emit m3AttributesChanged(); save(); }
}
void AppConfig::setSliderWaveAmplitude(qreal v) {
    v = std::clamp(v, 0.0, 7.0);
    if (!qFuzzyCompare(m_sliderWaveAmplitude, v)) { m_sliderWaveAmplitude = v; emit m3AttributesChanged(); save(); }
}
void AppConfig::setSliderWaveLength(qreal v) {
    v = std::clamp(v, 8.0, 64.0);
    if (!qFuzzyCompare(m_sliderWaveLength, v)) { m_sliderWaveLength = v; emit m3AttributesChanged(); save(); }
}
void AppConfig::setSliderThickness(qreal v) {
    v = std::clamp(v, 1.2, 6.0);
    if (!qFuzzyCompare(m_sliderThickness, v)) { m_sliderThickness = v; emit m3AttributesChanged(); save(); }
}
