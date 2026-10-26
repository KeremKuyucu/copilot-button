// WebViewSettings.cpp – Native Win32 penceresinde WebView2 ve SetVirtualHostNameToFolderMapping entegrasyonu
// Yerel HTTP sunucusu KULLANILMAZ. Yerel HTML doğrudan 'https://settings.local' sanal alan adına bağlanır.
#include "WebViewSettings.hpp"
#include "AppRegister.hpp"
#include "Osd.hpp"
#include "I18n.hpp"
#include "WebView2.h"
#include <wrl/client.h>
#include <commdlg.h>
#include <dwmapi.h>
#include <shlobj.h>
#include <shellapi.h>
#include <sstream>
#include <atomic>
#include <functional>
#include <vector>

#pragma comment(lib, "user32.lib")
#pragma comment(lib, "gdi32.lib")
#pragma comment(lib, "dwmapi.lib")
#pragma comment(lib, "comdlg32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "shell32.lib")

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#  define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

static constexpr UINT IDI_APP_ICON = 101;

// ─────────────────────────────────────────────
//  Hafif COM Callback Şablonu (WRL Bağımsız)
// ─────────────────────────────────────────────
template <typename Interface, typename... Args>
class CallbackImpl : public Interface {
public:
    using Func = std::function<HRESULT(Args...)>;
    CallbackImpl(Func f) : m_f(std::move(f)) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID, void** ppv) override {
        if (!ppv) return E_POINTER;
        *ppv = static_cast<Interface*>(this);
        AddRef();
        return S_OK;
    }

    ULONG STDMETHODCALLTYPE AddRef() override { return ++m_ref; }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG r = --m_ref;
        if (r == 0) delete this;
        return r;
    }

    HRESULT STDMETHODCALLTYPE Invoke(Args... args) override {
        return m_f(args...);
    }

private:
    std::atomic<ULONG> m_ref{1};
    Func m_f;
};

template <typename Interface, typename... Args, typename Func>
static Interface* MakeCallback(Func func) {
    return new CallbackImpl<Interface, Args...>(func);
}

// ─────────────────────────────────────────────
//  Dinamik WebView2Loader Fonksiyon İmzası
// ─────────────────────────────────────────────
typedef HRESULT (STDAPICALLTYPE *CreateCoreWebView2EnvironmentWithOptionsFn)(
    PCWSTR browserExecutableFolder,
    PCWSTR userDataFolder,
    ICoreWebView2EnvironmentOptions* environmentOptions,
    ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler* environment_created_handler
);

static std::wstring WStringToUtf8(const std::wstring& wstr) {
    if (wstr.empty()) return L"";
    return wstr;
}

static std::string WStringToUtf8Str(const std::wstring& wstr) {
    if (wstr.empty()) return "";
    int sz = WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, nullptr, 0, nullptr, nullptr);
    std::string res(sz - 1, 0);
    WideCharToMultiByte(CP_UTF8, 0, wstr.c_str(), -1, &res[0], sz, nullptr, nullptr);
    return res;
}

static std::wstring Utf8ToWString(const std::string& str) {
    if (str.empty()) return L"";
    int sz = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
    std::wstring res(sz - 1, 0);
    MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &res[0], sz);
    return res;
}

static std::string ExtractJsonString(const std::string& json, const std::string& key) {
    std::string pattern = "\"" + key + "\":\"";
    size_t pos = json.find(pattern);
    if (pos == std::string::npos) return "";
    pos += pattern.length();
    size_t end = json.find("\"", pos);
    if (end == std::string::npos) return "";
    return json.substr(pos, end - pos);
}

static int ExtractJsonInt(const std::string& json, const std::string& key, int def = 0) {
    std::string pattern = "\"" + key + "\":";
    size_t pos = json.find(pattern);
    if (pos == std::string::npos) return def;
    pos += pattern.length();
    while (pos < json.length() && (json[pos] == ' ' || json[pos] == '"')) pos++;
    int val = def;
    try {
        val = std::stoi(json.substr(pos));
    } catch (...) {}
    return val;
}

// ─────────────────────────────────────────────
//  Singleton & Yaşam Döngüsü
// ─────────────────────────────────────────────
WebViewSettingsWindow& WebViewSettingsWindow::Instance() {
    static WebViewSettingsWindow s_inst;
    return s_inst;
}

WebViewSettingsWindow::~WebViewSettingsWindow() {
    Close();
}

bool WebViewSettingsWindow::IsOpen() const {
    return (m_hWnd != nullptr && IsWindow(m_hWnd) && IsWindowVisible(m_hWnd));
}

void WebViewSettingsWindow::Close() {
    HWND hWndToDestroy = m_hWnd;
    m_hWnd = nullptr;

    UINT32 browserPid = m_browserPid;
    m_browserPid = 0;

    if (m_controller) {
        auto* ctrl = static_cast<ICoreWebView2Controller*>(m_controller);
        ctrl->put_IsVisible(FALSE);
        ctrl->Close();
        ctrl->Release();
        m_controller = nullptr;
    }
    if (m_webView) {
        auto* wv = static_cast<ICoreWebView2*>(m_webView);
        wv->Release();
        m_webView = nullptr;
    }
    if (m_env) {
        auto* env = static_cast<ICoreWebView2Environment*>(m_env);
        env->Release();
        m_env = nullptr;
    }
    if (hWndToDestroy && IsWindow(hWndToDestroy)) {
        DestroyWindow(hWndToDestroy);
    }
    m_initialized = false;

    // WebView2 tarayıcı alt süreçlerini bekle / temizle
    if (browserPid != 0) {
        HANDLE hProc = OpenProcess(PROCESS_TERMINATE | SYNCHRONIZE, FALSE, browserPid);
        if (hProc) {
            DWORD w = WaitForSingleObject(hProc, 500);
            if (w == WAIT_TIMEOUT) {
                // Ana tarayıcı sürecini ve ona bağlı alt süreçleri (GPU/Renderer/Utility) sessizce temizle
                wchar_t cmdLine[128] = {};
                wsprintfW(cmdLine, L"taskkill.exe /F /T /PID %u", browserPid);
                STARTUPINFOW si = { sizeof(si) };
                si.dwFlags = STARTF_USESHOWWINDOW;
                si.wShowWindow = SW_HIDE;
                PROCESS_INFORMATION pi = {};
                if (CreateProcessW(nullptr, cmdLine, nullptr, nullptr, FALSE, CREATE_NO_WINDOW, nullptr, nullptr, &si, &pi)) {
                    WaitForSingleObject(pi.hProcess, 1000);
                    CloseHandle(pi.hProcess);
                    CloseHandle(pi.hThread);
                } else {
                    TerminateProcess(hProc, 0);
                }
            }
            CloseHandle(hProc);
        }
    }
}

// ─────────────────────────────────────────────
//  Pencere Prosedürü
// ─────────────────────────────────────────────
LRESULT CALLBACK WebViewSettingsWindow::WndProc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    auto* self = reinterpret_cast<WebViewSettingsWindow*>(GetWindowLongPtrW(hwnd, GWLP_USERDATA));

    switch (msg) {
        case WM_SIZE:
            if (self) {
                self->OnSize(LOWORD(lParam), HIWORD(lParam));
            }
            return 0;

        case WM_KEYDOWN:
            if (wParam == VK_ESCAPE) {
                if (self) self->Close();
                return 0;
            }
            break;

        case WM_CLOSE:
            // Pencere kapatıldığında WebView2 denetleyicisini ve tüm tarayıcı süreçlerini tamamen sonlandır
            if (self) {
                self->Close();
            } else {
                DestroyWindow(hwnd);
            }
            return 0;

        case WM_DESTROY:
            if (self) {
                self->m_hWnd = nullptr;
            }
            return 0;

        default:
            break;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void WebViewSettingsWindow::OnSize(int width, int height) {
    if (m_controller) {
        auto* ctrl = static_cast<ICoreWebView2Controller*>(m_controller);
        RECT bounds = { 0, 0, width, height };
        ctrl->put_Bounds(bounds);
    }
}

// ─────────────────────────────────────────────
//  Pencereyi Aç ve WebView2'yi Başlat
// ─────────────────────────────────────────────
static constexpr UINT IDR_WEBVIEW2_LOADER = 102;
static constexpr UINT IDR_SETTINGS_HTML   = 103;

static bool ExtractResourceToFile(int resourceId, const std::wstring& destPath) {
    HINSTANCE hInst = GetModuleHandleW(nullptr);
    HRSRC hRsrc = FindResourceW(hInst, MAKEINTRESOURCEW(resourceId), MAKEINTRESOURCEW(10));
    if (!hRsrc) return false;

    HGLOBAL hGlobal = LoadResource(hInst, hRsrc);
    if (!hGlobal) return false;

    DWORD size = SizeofResource(hInst, hRsrc);
    const void* pData = LockResource(hGlobal);
    if (!pData || size == 0) return false;

    HANDLE hFile = CreateFileW(
        destPath.c_str(),
        GENERIC_WRITE,
        FILE_SHARE_READ,
        nullptr,
        CREATE_ALWAYS,
        FILE_ATTRIBUTE_NORMAL,
        nullptr
    );
    if (hFile == INVALID_HANDLE_VALUE) return false;

    DWORD written = 0;
    BOOL ok = WriteFile(hFile, pData, size, &written, nullptr);
    CloseHandle(hFile);
    return (ok && written == size);
}

// ─────────────────────────────────────────────
//  Pencereyi Aç ve WebView2'yi Başlat
// ─────────────────────────────────────────────
bool WebViewSettingsWindow::Open(const std::wstring& iniPath) {
    m_iniPath = iniPath;

    // Zaten açıksa veya gizlenmişse öne getir
    if (m_hWnd && IsWindow(m_hWnd)) {
        ShowWindow(m_hWnd, SW_RESTORE);
        SetForegroundWindow(m_hWnd);
        SendCurrentConfig();
        return true;
    }

    HINSTANCE hInst = GetModuleHandleW(nullptr);

    // Dizinleri ve %LOCALAPPDATA% yolunu al
    wchar_t exePath[MAX_PATH] = {};
    GetModuleFileNameW(nullptr, exePath, MAX_PATH);
    wchar_t* last = wcsrchr(exePath, L'\\');
    if (last) *last = L'\0';

    wchar_t localApp[MAX_PATH] = {};
    GetEnvironmentVariableW(L"LOCALAPPDATA", localApp, MAX_PATH);
    std::wstring appDataRoot = std::wstring(localApp) + L"\\CopilotButton";
    CreateDirectoryW(appDataRoot.c_str(), nullptr);

    // 1. HTML klasör yolunu belirle (Geliştirici ortamı veya gömülü kaynaktan)
    std::wstring parentHtml = std::wstring(exePath) + L"\\..\\html";

    if (GetFileAttributesW((parentHtml + L"\\index.html").c_str()) != INVALID_FILE_ATTRIBUTES) {
        // Geliştirici kaynak kodu dizini (canlı düzenleme için)
        m_htmlDir = parentHtml;
    } else {
        // Her zaman en güncel gömülü HTML'i %LOCALAPPDATA%\CopilotButton\html\index.html içine çıkart
        std::wstring appDataHtml = appDataRoot + L"\\html";
        CreateDirectoryW(appDataHtml.c_str(), nullptr);
        std::wstring appDataIndex = appDataHtml + L"\\index.html";
        ExtractResourceToFile(IDR_SETTINGS_HTML, appDataIndex);
        m_htmlDir = appDataHtml;
    }

    // 2. Win32 Pencere Sınıfını Kaydet
    static bool s_registered = false;
    if (!s_registered) {
        WNDCLASSEXW wc   = {};
        wc.cbSize        = sizeof(wc);
        wc.hInstance     = hInst;
        wc.lpfnWndProc   = WndProc;
        wc.lpszClassName = L"CopilotButtonSettingsWnd";
        wc.hCursor       = LoadCursorW(nullptr, MAKEINTRESOURCEW(32512));
        wc.hbrBackground = (HBRUSH)GetStockObject(BLACK_BRUSH);

        int cx = GetSystemMetrics(SM_CXSMICON);
        int cy = GetSystemMetrics(SM_CYSMICON);
        wc.hIcon = (HICON)LoadImageW(hInst, MAKEINTRESOURCEW(IDI_APP_ICON),
                                    IMAGE_ICON, cx, cy, LR_DEFAULTCOLOR);
        if (!wc.hIcon) wc.hIcon = LoadIconW(nullptr, MAKEINTRESOURCEW(32512));
        wc.hIconSm = wc.hIcon;

        RegisterClassExW(&wc);
        s_registered = true;
    }

    // 3. Pencereyi Oluştur (Ekranın ortasında, 680x820)
    int scrW = GetSystemMetrics(SM_CXSCREEN);
    int scrH = GetSystemMetrics(SM_CYSCREEN);
    int w = 680, h = 820;
    int x = (scrW - w) / 2;
    int y = (scrH - h) / 2;

    m_hWnd = CreateWindowExW(
        WS_EX_APPWINDOW,
        L"CopilotButtonSettingsWnd",
        L"Copilot Button Ayarları",
        WS_OVERLAPPED | WS_CAPTION | WS_SYSMENU | WS_MINIMIZEBOX | WS_THICKFRAME,
        x, y, w, h,
        nullptr, nullptr, hInst, nullptr
    );

    if (!m_hWnd) return false;

    SetWindowLongPtrW(m_hWnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(this));

    // Windows 11 / 10 Dark Başlık Çubuğu
    BOOL darkMode = TRUE;
    DwmSetWindowAttribute(m_hWnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &darkMode, sizeof(darkMode));

    ShowWindow(m_hWnd, SW_SHOWNORMAL);
    UpdateWindow(m_hWnd);

    // 4. WebView2Loader.dll yükle (önce diskte ara, yoksa gömülü kaynaktan %LOCALAPPDATA%'ya çıkart)
    HMODULE hLoader = LoadLibraryW(L"WebView2Loader.dll");
    if (!hLoader) {
        std::wstring loaderInExe = std::wstring(exePath) + L"\\WebView2Loader.dll";
        hLoader = LoadLibraryW(loaderInExe.c_str());
    }
    if (!hLoader) {
        std::wstring appDataLoader = appDataRoot + L"\\WebView2Loader.dll";
        if (GetFileAttributesW(appDataLoader.c_str()) == INVALID_FILE_ATTRIBUTES) {
            ExtractResourceToFile(IDR_WEBVIEW2_LOADER, appDataLoader);
        }
        hLoader = LoadLibraryW(appDataLoader.c_str());
    }
    if (!hLoader) {
        MessageBoxW(m_hWnd,
                    L"WebView2Loader başlatılamadı!\nLütfen sisteminizde Microsoft Edge WebView2 Runtime yüklü olduğundan emin olun.",
                    L"Hata", MB_ICONERROR);
        return false;
    }

    auto pfnCreate = reinterpret_cast<CreateCoreWebView2EnvironmentWithOptionsFn>(
        GetProcAddress(hLoader, "CreateCoreWebView2EnvironmentWithOptions"));
    if (!pfnCreate) return false;

    // WebView2 Kullanıcı Veri Klasörü (%LOCALAPPDATA%\CopilotButton\WebView2Data)
    std::wstring userDataFolder = appDataRoot + L"\\WebView2Data";

    // Arka planda WebView2 süreçlerinin asılı kalmasını önlemek için parametreleri ayarla
    SetEnvironmentVariableW(L"WEBVIEW2_ADDITIONAL_BROWSER_ARGUMENTS", L"--no-first-run --disable-background-mode");

    // 5. WebView2 Ortamını Oluştur
    HWND hwndTarget = m_hWnd;
    pfnCreate(
        nullptr, userDataFolder.c_str(), nullptr,
        MakeCallback<ICoreWebView2CreateCoreWebView2EnvironmentCompletedHandler, HRESULT, ICoreWebView2Environment*>(
            [this, hwndTarget](HRESULT hr, ICoreWebView2Environment* env) -> HRESULT {
                if (FAILED(hr) || !env) {
                    if (m_hWnd == hwndTarget) {
                        MessageBoxW(hwndTarget, L"WebView2 ortamı başlatılamadı!", L"Hata", MB_ICONERROR);
                    }
                    return hr;
                }

                if (m_hWnd != hwndTarget || !m_hWnd) {
                    return S_OK;
                }

                env->AddRef();
                m_env = env;

                // 6. Denetleyiciyi (Controller) Oluştur
                env->CreateCoreWebView2Controller(
                    hwndTarget,
                    MakeCallback<ICoreWebView2CreateCoreWebView2ControllerCompletedHandler, HRESULT, ICoreWebView2Controller*>(
                        [this, hwndTarget](HRESULT chr, ICoreWebView2Controller* controller) -> HRESULT {
                            if (FAILED(chr) || !controller) return chr;

                            if (m_hWnd != hwndTarget || !m_hWnd) {
                                controller->Close();
                                return S_OK;
                            }

                            controller->AddRef();
                            m_controller = controller;

                            ICoreWebView2* webView = nullptr;
                            controller->get_CoreWebView2(&webView);
                            if (!webView) return E_FAIL;
                            m_webView = webView;
                            webView->get_BrowserProcessId(&m_browserPid);

                            // Boyutları pencereye uyarla
                            RECT rc;
                            GetClientRect(hwndTarget, &rc);
                            controller->put_Bounds(rc);
                            controller->put_IsVisible(TRUE);

                            // ── SetVirtualHostNameToFolderMapping ──
                            // Yerel HTML klasörünü doğrudan 'https://settings.local' sanal alan adına eşle!
                            // HTTP sunucusu açmaya gerek kalmaz.
                            ICoreWebView2_3* webView3 = nullptr;
                            if (SUCCEEDED(webView->QueryInterface(IID_ICoreWebView2_3, reinterpret_cast<void**>(&webView3))) && webView3) {
                                webView3->SetVirtualHostNameToFolderMapping(
                                    L"settings.local",
                                    m_htmlDir.c_str(),
                                    COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
                                );
                                webView3->Release();
                            }

                            // ── WebMessageReceived Dinleyicisi ──
                            EventRegistrationToken msgToken;
                            webView->add_WebMessageReceived(
                                MakeCallback<ICoreWebView2WebMessageReceivedEventHandler, ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs*>(
                                    [this](ICoreWebView2*, ICoreWebView2WebMessageReceivedEventArgs* args) -> HRESULT {
                                        LPWSTR rawJson = nullptr;
                                        args->get_WebMessageAsJson(&rawJson);
                                        if (rawJson) {
                                            OnWebMessage(rawJson);
                                            CoTaskMemFree(rawJson);
                                        }
                                        return S_OK;
                                    }
                                ),
                                &msgToken
                            );

                            // ── Navigasyon Tamamlandığında Config Gönder ──
                            EventRegistrationToken navToken;
                            webView->add_NavigationCompleted(
                                MakeCallback<ICoreWebView2NavigationCompletedEventHandler, ICoreWebView2*, ICoreWebView2NavigationCompletedEventArgs*>(
                                    [this](ICoreWebView2*, ICoreWebView2NavigationCompletedEventArgs*) -> HRESULT {
                                        SendCurrentConfig();
                                        return S_OK;
                                    }
                                ),
                                &navToken
                            );

                            // Sayfayı Yükle
                            webView->Navigate(L"https://settings.local/index.html");
                            m_initialized = true;
                            return S_OK;
                        }
                    )
                );
                return S_OK;
            }
        )
    );

    return true;
}

// ─────────────────────────────────────────────
//  Bellek İçi Mesaj İşleme (HTTP Socketsiz)
// ─────────────────────────────────────────────
void WebViewSettingsWindow::OnWebMessage(const std::wstring& jsonMsg) {
    std::string utf8 = WStringToUtf8Str(jsonMsg);

    std::string type = ExtractJsonString(utf8, "type");
    if (type == "get_config") {
        SendCurrentConfig();
    } else if (type == "browse") {
        HandleBrowseApp();
    } else if (type == "save_config") {
        HandleSaveConfig(utf8);
    } else if (type == "close") {
        if (m_hWnd) {
            PostMessageW(m_hWnd, WM_CLOSE, 0, 0);
        }
    } else if (type == "open_url") {
        std::string url = ExtractJsonString(utf8, "url");
        if (!url.empty()) {
            ShellExecuteW(nullptr, L"open", Utf8ToWString(url).c_str(), nullptr, nullptr, SW_SHOWNORMAL);
        }
    } else if (type == "update_found") {
        std::string ver = ExtractJsonString(utf8, "version");
        if (!ver.empty()) {
            wchar_t lbuf[32] = {};
            GetPrivateProfileStringW(L"Settings", L"Language", L"tr", lbuf, 32, m_iniPath.c_str());
            OsdManager::Instance().ShowTip(I18n::UpdateFound(lbuf, Utf8ToWString(ver)));
        }
    }
}

void WebViewSettingsWindow::SendCurrentConfig() {
    if (!m_webView) return;
    auto* wv = static_cast<ICoreWebView2*>(m_webView);

    const wchar_t* p = m_iniPath.c_str();

    auto ReadStr = [p](const wchar_t* key, const wchar_t* def = L"") -> std::wstring {
        wchar_t buf[512] = {};
        GetPrivateProfileStringW(L"Settings", key, def, buf, 512, p);
        return buf;
    };

    auto ReadInt = [p](const wchar_t* key, int def = 0) -> int {
        return GetPrivateProfileIntW(L"Settings", key, def, p);
    };

    std::string json = "{\"type\":\"config\",\"appVersion\":\"" + std::string(APP_VERSION) + "\",\"data\":{";
    json += "\"doubleTapMs\":" + std::to_string(ReadInt(L"DoubleTapMs", 250)) + ",";
    json += "\"holdMs\":" + std::to_string(ReadInt(L"HoldMs", 250)) + ",";
    json += "\"action1\":\"" + WStringToUtf8Str(ReadStr(L"Action1", L"MicMute")) + "\",";
    json += "\"action2\":\"" + WStringToUtf8Str(ReadStr(L"Action2", L"PlayPause")) + "\",";
    json += "\"action3\":\"" + WStringToUtf8Str(ReadStr(L"Action3", L"NextTrack")) + "\",";
    json += "\"action4\":\"" + WStringToUtf8Str(ReadStr(L"Action4", L"None")) + "\",";
    json += "\"holdAction\":\"" + WStringToUtf8Str(ReadStr(L"HoldAction", L"PushToTalk")) + "\",";

    std::string escapedPath;
    for (char c : WStringToUtf8Str(ReadStr(L"CustomAppPath", L""))) {
        if (c == '\\') escapedPath += "\\\\";
        else escapedPath += c;
    }
    json += "\"customAppPath\":\"" + escapedPath + "\",";
    json += "\"autoStart\":" + std::to_string(ReadInt(L"AutoStart", 1)) + ",";
    json += "\"soundFxEnabled\":" + std::to_string(ReadInt(L"SoundFxEnabled", 1)) + ",";
    json += "\"language\":\"" + WStringToUtf8Str(ReadStr(L"Language", L"tr")) + "\",";
    json += "\"osdPosition\":\"" + WStringToUtf8Str(ReadStr(L"OsdPosition", L"TopLeft")) + "\",";
    json += "\"osdColor\":\"" + WStringToUtf8Str(ReadStr(L"OsdColor", L"00E5FF")) + "\",";
    json += "\"osdDurationMs\":" + std::to_string(ReadInt(L"OsdDurationMs", 1500)) + ",";
    json += "\"osdFadeEnabled\":" + std::to_string(ReadInt(L"OsdFadeEnabled", 1)) + ",";
    json += "\"spotifyTrackOsd\":" + std::to_string(ReadInt(L"SpotifyTrackOsd", 1));
    json += "}}";

    std::wstring wjson = Utf8ToWString(json);
    wv->PostWebMessageAsJson(wjson.c_str());
}

void WebViewSettingsWindow::HandleSaveConfig(const std::string& jsonBody) {
    if (!m_webView) return;
    auto* wv = static_cast<ICoreWebView2*>(m_webView);

    const wchar_t* p = m_iniPath.c_str();

    auto WriteStr = [p](const wchar_t* key, const std::string& val) {
        WritePrivateProfileStringW(L"Settings", key, Utf8ToWString(val).c_str(), p);
    };

    auto WriteInt = [p](const wchar_t* key, int val) {
        wchar_t buf[32] = {};
        wsprintfW(buf, L"%d", val);
        WritePrivateProfileStringW(L"Settings", key, buf, p);
    };

    std::string a1 = ExtractJsonString(jsonBody, "action1");
    if (!a1.empty()) WriteStr(L"Action1", a1);

    std::string a2 = ExtractJsonString(jsonBody, "action2");
    if (!a2.empty()) WriteStr(L"Action2", a2);

    std::string a3 = ExtractJsonString(jsonBody, "action3");
    if (!a3.empty()) WriteStr(L"Action3", a3);

    std::string a4 = ExtractJsonString(jsonBody, "action4");
    if (!a4.empty()) WriteStr(L"Action4", a4);

    std::string ha = ExtractJsonString(jsonBody, "holdAction");
    if (!ha.empty()) WriteStr(L"HoldAction", ha);

    std::string cap = ExtractJsonString(jsonBody, "customAppPath");
    std::string capClean;
    for (size_t i = 0; i < cap.length(); ++i) {
        if (cap[i] == '\\' && i + 1 < cap.length() && cap[i+1] == '\\') {
            capClean += '\\';
            i++;
        } else {
            capClean += cap[i];
        }
    }
    WriteStr(L"CustomAppPath", capClean);

    WriteInt(L"DoubleTapMs", ExtractJsonInt(jsonBody, "doubleTapMs", 250));
    WriteInt(L"HoldMs", ExtractJsonInt(jsonBody, "holdMs", 250));

    int autoStart = ExtractJsonInt(jsonBody, "autoStart", 1);
    WriteInt(L"AutoStart", autoStart);
    SetAutoStartRegistry(autoStart != 0);

    WriteInt(L"SoundFxEnabled", ExtractJsonInt(jsonBody, "soundFxEnabled", 1));

    std::string lang = ExtractJsonString(jsonBody, "language");
    if (!lang.empty()) WriteStr(L"Language", lang);

    std::string pos = ExtractJsonString(jsonBody, "osdPosition");
    if (!pos.empty()) WriteStr(L"OsdPosition", pos);

    std::string col = ExtractJsonString(jsonBody, "osdColor");
    if (!col.empty()) WriteStr(L"OsdColor", col);

    WriteInt(L"OsdDurationMs", ExtractJsonInt(jsonBody, "osdDurationMs", 1500));
    WriteInt(L"OsdFadeEnabled", ExtractJsonInt(jsonBody, "osdFadeEnabled", 1));
    WriteInt(L"SpotifyTrackOsd", ExtractJsonInt(jsonBody, "spotifyTrackOsd", 1));

    wv->PostWebMessageAsJson(L"{\"type\":\"save_result\",\"success\":true}");
}

void WebViewSettingsWindow::HandleBrowseApp() {
    if (!m_webView) return;
    auto* wv = static_cast<ICoreWebView2*>(m_webView);

    wchar_t lbuf[32] = {};
    GetPrivateProfileStringW(L"Settings", L"Language", L"tr", lbuf, 32, m_iniPath.c_str());

    wchar_t filename[MAX_PATH] = {};
    OPENFILENAMEW ofn = {};
    ofn.lStructSize = sizeof(ofn);
    ofn.hwndOwner = m_hWnd;
    ofn.lpstrFilter = I18n::BrowseFilter(lbuf);
    ofn.lpstrFile = filename;
    ofn.nMaxFile = MAX_PATH;
    ofn.Flags = OFN_FILEMUSTEXIST | OFN_PATHMUSTEXIST | OFN_NOCHANGEDIR;

    if (GetOpenFileNameW(&ofn)) {
        std::string raw = WStringToUtf8Str(filename);
        std::string escaped;
        for (char c : raw) {
            if (c == '\\') escaped += "\\\\";
            else escaped += c;
        }
        std::string json = "{\"type\":\"browse_result\",\"path\":\"" + escaped + "\"}";
        wv->PostWebMessageAsJson(Utf8ToWString(json).c_str());
    }
}
