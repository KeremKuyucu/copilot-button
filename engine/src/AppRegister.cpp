// AppRegister.cpp – Uygulamanın Windows'a tanıtılması ve AutoStart yönetimi
#include "AppRegister.hpp"
#include <shlobj.h>
#include <propvarutil.h>
#include <propkey.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ole32.lib")

static const wchar_t* APP_ID        = L"KeremKuyucu.CopilotButton";
static const wchar_t* APP_NAME      = L"Copilot Button Denetleyicisi";
static const wchar_t* RUN_REG_KEY   = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
static const wchar_t* APP_PATHS_KEY = L"Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\CopilotButton.exe";

static std::wstring GetCurrentExePath() {
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    return path;
}

void RegisterAppWithWindows() {
    // 1. İşleme resmi AppUserModelID ata (Görev çubuğu, bildirimler ve alt+tab gruplaması için)
    SetCurrentProcessExplicitAppUserModelID(APP_ID);

    std::wstring exePath = GetCurrentExePath();

    // 2. HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\CopilotButton.exe kaydı
    // Bu sayede Win+R (Çalıştır) veya komut satırından 'CopilotButton' yazıldığında Windows tanır.
    HKEY hKey = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, APP_PATHS_KEY, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, nullptr, 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(exePath.c_str()),
                       static_cast<DWORD>((exePath.length() + 1) * sizeof(wchar_t)));

        // Dizin yolu
        size_t lastSlash = exePath.find_last_of(L"\\/");
        if (lastSlash != std::wstring::npos) {
            std::wstring dirPath = exePath.substr(0, lastSlash);
            RegSetValueExW(hKey, L"Path", 0, REG_SZ,
                           reinterpret_cast<const BYTE*>(dirPath.c_str()),
                           static_cast<DWORD>((dirPath.length() + 1) * sizeof(wchar_t)));
        }
        RegCloseKey(hKey);
    }

    // 3. HKCU\Software\Classes\AppUserModelId\KeremKuyucu.CopilotButton kaydı
    // Windows Bildirim Merkezi ve Görev Yöneticisi için uygulama adı ve ikon tanıtımı
    std::wstring aumidKey = std::wstring(L"Software\\Classes\\AppUserModelId\\") + APP_ID;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, aumidKey.c_str(), 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, L"DisplayName", 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(APP_NAME),
                       static_cast<DWORD>((wcslen(APP_NAME) + 1) * sizeof(wchar_t)));

        std::wstring iconUri = exePath + L",0";
        RegSetValueExW(hKey, L"IconUri", 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(iconUri.c_str()),
                       static_cast<DWORD>((iconUri.length() + 1) * sizeof(wchar_t)));
        RegCloseKey(hKey);
    }
}

void SetAutoStartRegistry(bool enable) {
    HKEY hKey = nullptr;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, RUN_REG_KEY, 0,
                      KEY_SET_VALUE | KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
        if (enable) {
            std::wstring cmd = L"\"" + GetCurrentExePath() + L"\"";
            RegSetValueExW(hKey, L"CopilotButton", 0, REG_SZ,
                           reinterpret_cast<const BYTE*>(cmd.c_str()),
                           static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
        } else {
            RegDeleteValueW(hKey, L"CopilotButton");
        }
        RegCloseKey(hKey);
    }
}

bool GetAutoStartRegistry() {
    HKEY hKey = nullptr;
    bool exists = false;
    if (RegOpenKeyExW(HKEY_CURRENT_USER, RUN_REG_KEY, 0, KEY_QUERY_VALUE, &hKey) == ERROR_SUCCESS) {
        DWORD type = 0;
        if (RegQueryValueExW(hKey, L"CopilotButton", nullptr, &type, nullptr, nullptr) == ERROR_SUCCESS) {
            exists = true;
        }
        RegCloseKey(hKey);
    }
    return exists;
}
