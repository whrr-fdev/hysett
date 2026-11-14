cmake_minimum_required(VERSION 3.20)
project(hysett LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(POLICY QTP0001)
    qt_policy(SET QTP0001 NEW)
endif()
if(POLICY QTP0004)
    qt_policy(SET QTP0004 OLD)
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick QuickControls2 ShaderTools Concurrent DBus)

qt_standard_project_setup()

qt_add_executable(hysett
    src/main.cpp
    src/AppInstance.cpp
    src/AppInstance.h
    src/ThemeEngine.cpp
    src/ThemeEngine.h
    src/AppConfig.cpp
    src/AppConfig.h
    src/LookManager.cpp
    src/LookManager.h
    src/CursorManager.cpp
    src/CursorManager.h
    src/MonitorsManager.cpp
    src/MonitorsManager.h
    src/DevicesManager.cpp
    src/DevicesManager.h
    src/NetworkManager.cpp
    src/NetworkManager.h
    src/BluetoothManager.cpp
    src/BluetoothManager.h
    src/AnimsManager.cpp
    src/AnimsManager.h
    src/WaybarManager.cpp
    src/WaybarManager.h
    src/MakoManager.cpp
    src/MakoManager.h
    src/AutostartManager.cpp
    src/AutostartManager.h
    src/BindsManager.cpp
    src/BindsManager.h
    src/RulesManager.cpp
    src/RulesManager.h
    src/AppsManager.cpp
    src/AppsManager.h
    src/WidgetsManager.cpp
    src/WidgetsManager.h
    src/WallpapersManager.cpp
    src/WallpapersManager.h
    src/ShadersManager.cpp
    src/ShadersManager.h
    src/AtmosphereManager.cpp
    src/AtmosphereManager.h
    src/IconImageProvider.cpp
    src/IconImageProvider.h
    src/HyprIpc.cpp
    src/HyprIpc.h
)

qt6_add_shaders(hysett "hysett_shaders"
    PREFIX "/shaders"
    FILES
        qml/shaders/liquid_glass.frag
        qml/shaders/liquid_panel.frag
        qml/shaders/neon_border.frag
        qml/shaders/cursor_fx.frag
        qml/shaders/click_fx.frag
        qml/shaders/dialog_blur.frag
        qml/shaders/vortex_suck.frag
        qml/shaders/atmosphere_fx.frag
        qml/shaders/merged_shell.frag
        qml/shaders/round_clip.frag
        qml/shaders/weather_sky.frag
)

qt_add_qml_module(hysett
    URI HySett
    VERSION 1.0
    RESOURCE_PREFIX "/qt/qml"
    QML_FILES
        qml/Main.qml
        qml/components/Sidebar.qml
        qml/components/NavButton.qml
        qml/components/GlassPanel.qml
        qml/components/StyledSlider.qml
        qml/components/StyledSwitch.qml
        qml/components/StyledCheckBox.qml
        qml/components/StyledButton.qml
        qml/components/StyledComboBox.qml
        qml/components/SegmentedButton.qml
        qml/components/ColorPickerModal.qml
        qml/views/PlaceholderView.qml
        qml/views/WelcomeView.qml
        qml/views/LookSettingsView.qml
        qml/views/AppSettingsView.qml
        qml/views/CursorSettingsView.qml
        qml/views/MonitorsSettingsView.qml
        qml/views/DevicesSettingsView.qml
        qml/views/NetworkSettingsView.qml
        qml/views/BluetoothSettingsView.qml
        qml/views/AnimsSettingsView.qml
        qml/views/WaybarSettingsView.qml
        qml/views/MakoSettingsView.qml
        qml/views/AutostartSettingsView.qml
        qml/views/BindsSettingsView.qml
        qml/views/RulesSettingsView.qml
        qml/views/AppsSettingsView.qml
        qml/views/WidgetsSettingsView.qml
        qml/views/WallpapersView.qml
        qml/views/ShadersView.qml
        qml/views/AtmosphereView.qml
        qml/AtmosphereOverlay.qml
        qml/views/SearchView.qml
        qml/views/WeatherView.qml
        qml/views/SysMonView.qml
        qml/views/CalendarView.qml
        qml/views/ClipboardView.qml
        qml/views/PowerView.qml
        qml/views/LanguageView.qml
        qml/views/VpnView.qml
        qml/views/MusicView.qml
        qml/views/TimerView.qml
        qml/views/BackupView.qml
)

target_link_libraries(hysett PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::QuickControls2
    Qt6::Concurrent
    Qt6::DBus
)


find_package(LayerShellQt QUIET)
if(LayerShellQt_FOUND)
    target_link_libraries(hysett PRIVATE LayerShellQt::Interface)
    target_compile_definitions(hysett PRIVATE HAVE_LAYERSHELLQT=1)
endif()
