cmake_minimum_required(VERSION 3.20)
project(CopilotButtonEngine CXX RC)

# ── Standart ────────────────────────────────────────────────────────
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ── Unicode zorunlu tanımlar ─────────────────────────────────────────
add_compile_definitions(UNICODE _UNICODE WIN32_LEAN_AND_MEAN)

# ── Kaynak dosyaları ─────────────────────────────────────────────────
set(SOURCES
    src/main.cpp
    ../common/src/Config.cpp
    src/Audio.cpp
    src/KeyHook.cpp
    src/Actions.cpp
    src/MicOverlay.cpp
    src/SpotifyTracker.cpp
    src/Osd.cpp
    app.rc
)

# ── Konsol penceresi açılmayacak (arka plan daemon) ──────────────────
add_executable(CopilotButtonEngine WIN32 ${SOURCES})

# ── Include dizinleri ────────────────────────────────────────────────
target_include_directories(CopilotButtonEngine PRIVATE
    include
    ../common/include
)

# ── Windows sistem kütüphaneleri ─────────────────────────────────────
target_link_libraries(CopilotButtonEngine PRIVATE
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
    windowsapp
)

# ── Derleyici bayrakları ─────────────────────────────────────────────
if(MSVC)
    target_compile_options(CopilotButtonEngine PRIVATE
        /W4
        /WX-
        /O2
        /EHsc
    )
    set_target_properties(CopilotButtonEngine PROPERTIES
        LINK_FLAGS "/MANIFEST:NO"
    )
else()
    target_compile_options(CopilotButtonEngine PRIVATE
        -Wall -Wextra -O2
        -flto
        -ffunction-sections
        -fdata-sections
        -mwindows
    )
    target_link_options(CopilotButtonEngine PRIVATE
        -mwindows
        -s
        -flto
        -Wl,--gc-sections
        -static-libgcc
        -static-libstdc++
        -static
    )
endif()

# ── Çıktı adı ────────────────────────────────────────────────────────
set_target_properties(CopilotButtonEngine PROPERTIES
    OUTPUT_NAME "CopilotButtonEngine"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/.."
    RUNTIME_OUTPUT_DIRECTORY_RELEASE "${CMAKE_CURRENT_SOURCE_DIR}/.."
    RUNTIME_OUTPUT_DIRECTORY_DEBUG "${CMAKE_CURRENT_SOURCE_DIR}/.."
)
