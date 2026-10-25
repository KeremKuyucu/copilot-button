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

// ─────────────────────────────────────────────
//  Başlat Menüsü Kısayolu (%APPDATA%\...\Start Menu\Programs\Copilot Button.lnk)
//  Windows Arama ve Başlat Menüsünün uygulamayı tanımasını sağlar.
// ─────────────────────────────────────────────
static void CreateStartMenuShortcut(const std::wstring& exePath) {
    wchar_t programsPath[MAX_PATH] = {};
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_PROGRAMS, nullptr, 0, programsPath))) {
        return;
    }

    std::wstring shortcutPath = std::wstring(programsPath) + L"\\Copilot Button.lnk";

    IShellLinkW* pShellLink = nullptr;
    if (SUCCEEDED(CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                   IID_IShellLinkW, reinterpret_cast<void**>(&pShellLink)))) {
        pShellLink->SetPath(exePath.c_str());

        size_t lastSlash = exePath.find_last_of(L"\\/");
        if (lastSlash != std::wstring::npos) {
            pShellLink->SetWorkingDirectory(exePath.substr(0, lastSlash).c_str());
        }

        pShellLink->SetIconLocation(exePath.c_str(), 0);
        pShellLink->SetDescription(APP_NAME);

        // AppUserModelID ataması (Windows bildirim ve görev çubuğu gruplaması için)
        IPropertyStore* pPropStore = nullptr;
        if (SUCCEEDED(pShellLink->QueryInterface(IID_IPropertyStore, reinterpret_cast<void**>(&pPropStore)))) {
            PROPVARIANT pv;
            PropVariantInit(&pv);
            pv.vt = VT_LPWSTR;
            pv.pwszVal = const_cast<wchar_t*>(APP_ID);
            pPropStore->SetValue(PKEY_AppUserModel_ID, pv);
            pPropStore->Commit();
            pPropStore->Release();
        }

        IPersistFile* pPersistFile = nullptr;
        if (SUCCEEDED(pShellLink->QueryInterface(IID_IPersistFile, reinterpret_cast<void**>(&pPersistFile)))) {
            pPersistFile->Save(shortcutPath.c_str(), TRUE);
            pPersistFile->Release();
        }
        pShellLink->Release();
    }
}

void RegisterAppWithWindows() {
    // 1. İşleme resmi AppUserModelID ata
    SetCurrentProcessExplicitAppUserModelID(APP_ID);

    std::wstring exePath = GetCurrentExePath();

    // 2. Başlat Menüsü Kısayolu Oluştur (Windows Search ve Başlat Menüsü için)
    CreateStartMenuShortcut(exePath);

    // 3. HKCU\Software\Microsoft\Windows\CurrentVersion\App Paths\CopilotButton.exe kaydı
    // Win+R (Çalıştır) veya terminalden 'CopilotButton' yazıldığında çalışması için
    HKEY hKey = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, APP_PATHS_KEY, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, nullptr, 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(exePath.c_str()),
                       static_cast<DWORD>((exePath.length() + 1) * sizeof(wchar_t)));

        size_t lastSlash = exePath.find_last_of(L"\\/");
        if (lastSlash != std::wstring::npos) {
            std::wstring dirPath = exePath.substr(0, lastSlash);
            RegSetValueExW(hKey, L"Path", 0, REG_SZ,
                           reinterpret_cast<const BYTE*>(dirPath.c_str()),
                           static_cast<DWORD>((dirPath.length() + 1) * sizeof(wchar_t)));
        }
        RegCloseKey(hKey);
    }

    // 4. HKCU\Software\Classes\AppUserModelId\KeremKuyucu.CopilotButton kaydı
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

// ─────────────────────────────────────────────
//  Windows Başlangıcında Otomatik Başlatma (AutoStart)
//  İki katmanlı güvenilirlik:
//  1. HKCU\...\Run (Standart kayıt defteri)
//  2. Windows Task Scheduler (/rl highest /sc onlogon)
//     CopilotButton requireAdministrator manifestine sahip olduğundan,
//     Windows Explorer başlangıçta standart Run kaydını UAC sebebiyle engelleyebilir.
//     Task Scheduler sayesinde yönetici izinleriyle UAC sormadan logon anında başlar.
// ─────────────────────────────────────────────
void SetAutoStartRegistry(bool enable) {
    std::wstring exePath = GetCurrentExePath();

    // 1. HKCU\...\Run kaydı
    HKEY hKey = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, RUN_REG_KEY, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE | KEY_QUERY_VALUE,
                        nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
        if (enable) {
            std::wstring cmd = L"\"" + exePath + L"\"";
            RegSetValueExW(hKey, L"CopilotButton", 0, REG_SZ,
                           reinterpret_cast<const BYTE*>(cmd.c_str()),
                           static_cast<DWORD>((cmd.length() + 1) * sizeof(wchar_t)));
        } else {
            RegDeleteValueW(hKey, L"CopilotButton");
        }
        RegCloseKey(hKey);
    }

    // 2. Windows Task Scheduler (Görev Zamanlayıcısı)
    wchar_t schCmd[512] = {};
    if (enable) {
        wsprintfW(schCmd, L"schtasks.exe /create /tn \"CopilotButton\" /tr \"\\\"%s\\\"\" /sc onlogon /rl highest /f", exePath.c_str());
    } else {
        wsprintfW(schCmd, L"schtasks.exe /delete /tn \"CopilotButton\" /f");
    }

    STARTUPINFOW si = { sizeof(si) };
    si.dwFlags = STARTF_USESHOWWINDOW;
    si.wShowWindow = SW_HIDE;
    PROCESS_INFORMATION pi = {};
    if (CreateProcessW(nullptr, schCmd, nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
        WaitForSingleObject(pi.hProcess, 2000);
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
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
