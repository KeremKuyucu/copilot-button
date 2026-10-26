#include "AppRegister.hpp"
#include <shlobj.h>
#include <propvarutil.h>
#include <propkey.h>
#include <tlhelp32.h>
#include <vector>
#include <thread>
#include <chrono>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "ole32.lib")

static const wchar_t* APP_ID        = L"KeremKuyucu.CopilotButton";
static const wchar_t* APP_NAME      = L"Copilot Button";
static const wchar_t* RUN_REG_KEY   = L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
static const wchar_t* APP_PATHS_KEY = L"Software\\Microsoft\\Windows\\CurrentVersion\\App Paths\\CopilotButton.exe";

static std::wstring GetCurrentExePath() {
    wchar_t path[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, path, MAX_PATH);
    return path;
}

// ─────────────────────────────────────────────
//  Başlat Menüsü Kısayolu (%APPDATA%\...\Start Menu\Programs\Copilot Button.lnk)
// ─────────────────────────────────────────────
static void CreateStartMenuShortcut(const std::wstring& exePath) {
    HRESULT hrInit = CoInitialize(nullptr);

    wchar_t programsPath[MAX_PATH] = {};
    if (SUCCEEDED(SHGetFolderPathW(nullptr, CSIDL_PROGRAMS, nullptr, 0, programsPath))) {
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
                if (SUCCEEDED(pPersistFile->Save(shortcutPath.c_str(), TRUE))) {
                    SHChangeNotify(SHCNE_CREATE, SHCNF_PATHW, shortcutPath.c_str(), nullptr);
                }
                pPersistFile->Release();
            }
            pShellLink->Release();
        }
    }

    if (SUCCEEDED(hrInit)) {
        CoUninitialize();
    }
}

void RegisterAppWithWindows() {
    SetCurrentProcessExplicitAppUserModelID(APP_ID);
    std::wstring exePath = GetCurrentExePath();
    CreateStartMenuShortcut(exePath);

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
    std::wstring exePath = GetCurrentExePath();

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

// ─────────────────────────────────────────────
//  Kendi Kendini %LOCALAPPDATA%\CopilotButton Klasörüne Taşıma
// ─────────────────────────────────────────────
bool CheckAndPerformSelfRelocate() {
    wchar_t currentExe[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, currentExe, MAX_PATH);

    wchar_t localApp[MAX_PATH] = {};
    if (FAILED(SHGetFolderPathW(nullptr, CSIDL_LOCAL_APPDATA, nullptr, 0, localApp))) {
        return false;
    }

    std::wstring targetDir = std::wstring(localApp) + L"\\CopilotButton";
    std::wstring targetExe = targetDir + L"\\CopilotButton.exe";

    // Zaten hedef konumda (%LOCALAPPDATA%\CopilotButton\CopilotButton.exe) çalışıyorsa taşıma yapma
    if (_wcsicmp(currentExe, targetExe.c_str()) == 0) {
        return false;
    }

    wchar_t curDir[MAX_PATH] = {};
    wcscpy_s(curDir, currentExe);
    wchar_t* lastSlash = wcsrchr(curDir, L'\\');
    if (lastSlash) *lastSlash = L'\0';

    CreateDirectoryW(targetDir.c_str(), nullptr);

    // Hedef konumda eski çalışan bir örnek varsa sonlandır ki CopyFile kilitlenmesin
    DWORD currentPid = GetCurrentProcessId();
    HANDLE snap = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snap != INVALID_HANDLE_VALUE) {
        PROCESSENTRY32W pe = { sizeof(pe) };
        if (Process32FirstW(snap, &pe)) {
            do {
                if (pe.th32ProcessID != currentPid &&
                    (_wcsicmp(pe.szExeFile, L"Copilot.exe") == 0 ||
                     _wcsicmp(pe.szExeFile, L"CopilotButton.exe") == 0 ||
                     _wcsicmp(pe.szExeFile, L"CopilotButtonEngine.exe") == 0)) {
                    HANDLE hProc = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, pe.th32ProcessID);
                    if (hProc) {
                        TerminateProcess(hProc, 0);
                        WaitForSingleObject(hProc, 1000);
                        CloseHandle(hProc);
                    }
                }
            } while (Process32NextW(snap, &pe));
        }
        CloseHandle(snap);
    }
    Sleep(150);

    bool copied = false;
    for (int retry = 0; retry < 5; ++retry) {
        if (CopyFileW(currentExe, targetExe.c_str(), FALSE)) {
            copied = true;
            break;
        }
        Sleep(200);
    }

    if (!copied) {
        return false;
    }

    // Kaynak dizinde config.ini varsa ve hedefte henüz yoksa kopyala
    std::wstring curConfig = std::wstring(curDir) + L"\\config.ini";
    std::wstring targetConfig = targetDir + L"\\config.ini";
    if (GetFileAttributesW(curConfig.c_str()) != INVALID_FILE_ATTRIBUTES &&
        GetFileAttributesW(targetConfig.c_str()) == INVALID_FILE_ATTRIBUTES) {
        CopyFileW(curConfig.c_str(), targetConfig.c_str(), TRUE);
    }

    CreateStartMenuShortcut(targetExe);

    HKEY hKey = nullptr;
    if (RegCreateKeyExW(HKEY_CURRENT_USER, APP_PATHS_KEY, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr, &hKey, nullptr) == ERROR_SUCCESS) {
        RegSetValueExW(hKey, nullptr, 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(targetExe.c_str()),
                       static_cast<DWORD>((targetExe.length() + 1) * sizeof(wchar_t)));
        RegSetValueExW(hKey, L"Path", 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(targetDir.c_str()),
                       static_cast<DWORD>((targetDir.length() + 1) * sizeof(wchar_t)));
        RegCloseKey(hKey);
    }

    STARTUPINFOW si = { sizeof(si) };
    PROCESS_INFORMATION pi = {};
    std::wstring launchCmd = L"\"" + targetExe + L"\" --delete-source \"" + currentExe + L"\"";

    std::vector<wchar_t> cmdBuf(launchCmd.begin(), launchCmd.end());
    cmdBuf.push_back(L'\0');

    if (CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, 0, nullptr, targetDir.c_str(), &si, &pi)) {
        CloseHandle(pi.hProcess);
        CloseHandle(pi.hThread);
        return true;
    }

    return false;
}

void CleanupOldSourceIfRequested() {
    const wchar_t* cmdLine = GetCommandLineW();
    const wchar_t* tag = L"--delete-source ";
    const wchar_t* pos = wcsstr(cmdLine, tag);
    if (!pos) return;

    pos += wcslen(tag);
    std::wstring sourcePath;

    if (*pos == L'"') {
        pos++;
        const wchar_t* end = wcschr(pos, L'"');
        if (end) sourcePath = std::wstring(pos, end - pos);
    } else {
        const wchar_t* end = wcschr(pos, L' ');
        if (end) sourcePath = std::wstring(pos, end - pos);
        else sourcePath = pos;
    }

    if (sourcePath.empty()) return;

    std::thread([sourcePath]() {
        for (int i = 0; i < 20; ++i) {
            std::this_thread::sleep_for(std::chrono::milliseconds(500));
            if (DeleteFileW(sourcePath.c_str())) break;
        }
    }).detach();
}

