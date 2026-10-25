cmake_minimum_required(VERSION 3.20)
project(CopilotButton CXX RC)

# ── Standart ────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Unicode zorunlu tanımlar ─────────────────────────────────────────
add_compile_definitions(UNICODE _UNICODE WIN32_LEAN_AND_MEAN)

# ── Kaynak dosyaları ─────────────────────────────────────────────────
set(SOURCES
    src/main.cpp
    src/Config.cpp
    src/Audio.cpp
    src/KeyHook.cpp
    src/Actions.cpp
    src/MicOverlay.cpp
    src/SpotifyTracker.cpp
    src/Osd.cpp
    src/Tray.cpp
    src/WebViewSettings.cpp
    src/AppRegister.cpp
    app.rc          # manifest + sürüm kaynağı
)

# ── Konsol penceresi açılmayacak (arka plan daemon) ──────────────────
add_executable(CopilotButton WIN32 ${SOURCES})

# ── Include dizini ───────────────────────────────────────────────────
target_include_directories(CopilotButton PRIVATE include)

# ── Windows sistem kütüphaneleri ─────────────────────────────────────
target_link_libraries(CopilotButton PRIVATE
    user32
    shell32
    ole32
    oleaut32
    uuid
    winmm
    advapi32
    gdi32
    dwmapi
    comdlg32
)

# ── Derleyici bayrakları ─────────────────────────────────────────────
if(MSVC)
    target_compile_options(CopilotButton PRIVATE
        /W4
        /WX-
        /O2
        /EHsc
    )
    set_target_properties(CopilotButton PROPERTIES
        LINK_FLAGS "/MANIFEST:NO"
    )
else()
    target_compile_options(CopilotButton PRIVATE
        -Wall -Wextra -O2
        -mwindows
    )
    target_link_options(CopilotButton PRIVATE
        -mwindows
        -static-libgcc
        -static-libstdc++
        -static
    )
endif()

# ── Çıktı adı ────────────────────────────────────────────────────────
set_target_properties(CopilotButton PROPERTIES
    OUTPUT_NAME "CopilotButton"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_SOURCE_DIR}/.."
)
