// Audio.cpp – Core Audio COM ile ses yönetimi ve harici bildirim izleme
#include "Audio.hpp"
#include <mmdeviceapi.h>
#include <endpointvolume.h>
#include <mmsystem.h>
#include <objbase.h>

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "winmm.lib")

// ─────────────────────────────────────────────
//  IAudioEndpointVolume alma yardımcısı
// ─────────────────────────────────────────────
static IAudioEndpointVolume* GetEPV(EDataFlow flow) {
    IMMDeviceEnumerator* pEnum = nullptr;
    HRESULT hr = CoCreateInstance(
        __uuidof(MMDeviceEnumerator), nullptr,
        CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
        reinterpret_cast<void**>(&pEnum));
    if (FAILED(hr)) return nullptr;

    IMMDevice* pDevice = nullptr;
    hr = pEnum->GetDefaultAudioEndpoint(flow, eConsole, &pDevice);
    if (FAILED(hr) && flow == eCapture) {
        hr = pEnum->GetDefaultAudioEndpoint(flow, eCommunications, &pDevice);
    }
    pEnum->Release();
    if (FAILED(hr) || !pDevice) return nullptr;

    IAudioEndpointVolume* pEPV = nullptr;
    hr = pDevice->Activate(__uuidof(IAudioEndpointVolume),
                           CLSCTX_ALL, nullptr,
                           reinterpret_cast<void**>(&pEPV));
    pDevice->Release();
    return SUCCEEDED(hr) ? pEPV : nullptr;
}

static IAudioEndpointVolume* GetDefaultCaptureEPV() { return GetEPV(eCapture); }
static IAudioEndpointVolume* GetDefaultRenderEPV()  { return GetEPV(eRender);  }

// ─────────────────────────────────────────────
//  Mikrofon – Get / Set / Toggle
// ─────────────────────────────────────────────
bool GetMicMuteState() {
    auto* epv = GetDefaultCaptureEPV();
    if (!epv) return false;
    BOOL m = FALSE;
    epv->GetMute(&m);
    epv->Release();
    return m != FALSE;
}

void SetMicMuteState(bool mute) {
    auto* epv = GetDefaultCaptureEPV();
    if (!epv) return;
    epv->SetMute(mute ? TRUE : FALSE, nullptr);
    epv->Release();
}

void ToggleMicMute() {
    SetMicMuteState(!GetMicMuteState());
}

// ─────────────────────────────────────────────
//  Master ses – Get / Set / Toggle
// ─────────────────────────────────────────────
bool GetMasterMuteState() {
    auto* epv = GetDefaultRenderEPV();
    if (!epv) return false;
    BOOL m = FALSE;
    epv->GetMute(&m);
    epv->Release();
    return m != FALSE;
}

static void SetMasterMuteState(bool mute) {
    auto* epv = GetDefaultRenderEPV();
    if (!epv) return;
    epv->SetMute(mute ? TRUE : FALSE, nullptr);
    epv->Release();
}

void ToggleMasterMute() {
    SetMasterMuteState(!GetMasterMuteState());
}

// ─────────────────────────────────────────────
//  ToggleDeafen – hem mic hem master
// ─────────────────────────────────────────────
void ToggleDeafen() {
    bool mic    = GetMicMuteState();
    bool master = GetMasterMuteState();

    // Herhangi biri açıksa ikisini de sustur; ikisi de kapalıysa aç
    bool shouldMute = (!mic || !master);

    SetMicMuteState(shouldMute);
    SetMasterMuteState(shouldMute);
}

// ─────────────────────────────────────────────
//  Medya tuşları (SendInput)
// ─────────────────────────────────────────────
void SendMediaKey(WORD vk) {
    INPUT in[2] = {};
    in[0].type       = INPUT_KEYBOARD;
    in[0].ki.wVk     = vk;
    in[1].type       = INPUT_KEYBOARD;
    in[1].ki.wVk     = vk;
    in[1].ki.dwFlags = KEYEVENTF_KEYUP;
    SendInput(2, in, sizeof(INPUT));
}

// ─────────────────────────────────────────────
//  Ses efekti – Windows Media klasöründen
// ─────────────────────────────────────────────
void PlayMicSound(bool muted) {
    wchar_t winDir[MAX_PATH];
    GetWindowsDirectoryW(winDir, MAX_PATH);

    auto try_play = [&](const wchar_t* file) -> bool {
        wchar_t path[MAX_PATH];
        wsprintfW(path, L"%s\\Media\\%s", winDir, file);
        return PlaySoundW(path, nullptr, SND_FILENAME | SND_ASYNC | SND_NODEFAULT) != FALSE;
    };

    if (muted) {
        if (!try_play(L"Speech Off.wav"))
            try_play(L"Windows Pop-up Blocked.wav");
    } else {
        if (!try_play(L"Speech On.wav"))
            try_play(L"Windows Navigation Start.wav");
    }
}

// ─────────────────────────────────────────────
//  Harici mikrofon değişikliği dinleyicisi
//  IAudioEndpointVolumeCallback (Event-driven)
// ─────────────────────────────────────────────
class MicEndpointCallback : public IAudioEndpointVolumeCallback {
public:
    virtual ~MicEndpointCallback() = default;

    MicEndpointCallback(MicChangeCallback cb)
        : m_ref(1), m_cb(std::move(cb)) {}

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (riid == __uuidof(IUnknown) || riid == __uuidof(IAudioEndpointVolumeCallback)) {
            *ppv = static_cast<IAudioEndpointVolumeCallback*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    STDMETHODIMP_(ULONG) AddRef() override {
        return InterlockedIncrement(&m_ref);
    }

    STDMETHODIMP_(ULONG) Release() override {
        ULONG ref = InterlockedDecrement(&m_ref);
        if (ref == 0) delete this;
        return ref;
    }

    STDMETHODIMP OnNotify(PAUDIO_VOLUME_NOTIFICATION_DATA pNotify) override {
        if (pNotify && m_cb) {
            m_cb(pNotify->bMuted != FALSE);
        }
        return S_OK;
    }

private:
    LONG m_ref;
    MicChangeCallback m_cb;
};

class MicDeviceNotificationClient : public IMMNotificationClient {
public:
    virtual ~MicDeviceNotificationClient() = default;

    explicit MicDeviceNotificationClient(AudioDeviceChangeCallback cb)
        : m_ref(1), m_cb(std::move(cb)) {}

    STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override {
        if (!ppv) return E_POINTER;
        if (riid == __uuidof(IUnknown) || riid == __uuidof(IMMNotificationClient)) {
            *ppv = static_cast<IMMNotificationClient*>(this);
            AddRef();
            return S_OK;
        }
        *ppv = nullptr;
        return E_NOINTERFACE;
    }

    STDMETHODIMP_(ULONG) AddRef() override {
        return InterlockedIncrement(&m_ref);
    }

    STDMETHODIMP_(ULONG) Release() override {
        ULONG ref = InterlockedDecrement(&m_ref);
        if (ref == 0) delete this;
        return ref;
    }

    STDMETHODIMP OnDeviceStateChanged(LPCWSTR, DWORD) override {
        if (m_cb) m_cb();
        return S_OK;
    }

    STDMETHODIMP OnDeviceAdded(LPCWSTR) override {
        return S_OK;
    }

    STDMETHODIMP OnDeviceRemoved(LPCWSTR) override {
        return S_OK;
    }

    STDMETHODIMP OnDefaultDeviceChanged(EDataFlow flow, ERole role, LPCWSTR) override {
        if (flow == eCapture && (role == eConsole || role == eCommunications) && m_cb) {
            m_cb();
        }
        return S_OK;
    }

    STDMETHODIMP OnPropertyValueChanged(LPCWSTR, const PROPERTYKEY) override {
        return S_OK;
    }

private:
    LONG m_ref;
    AudioDeviceChangeCallback m_cb;
};

static IMMDeviceEnumerator*         g_pDeviceEnum   = nullptr;
static MicDeviceNotificationClient* g_pDeviceNotify = nullptr;
static IAudioEndpointVolume*        g_pObservedEPV  = nullptr;
static MicEndpointCallback*         g_pMicCallback  = nullptr;
static MicChangeCallback            g_savedMicCb;

static void DetachMicEndpoint() {
    if (g_pObservedEPV && g_pMicCallback) {
        g_pObservedEPV->UnregisterControlChangeNotify(g_pMicCallback);
    }
    if (g_pMicCallback) {
        g_pMicCallback->Release();
        g_pMicCallback = nullptr;
    }
    if (g_pObservedEPV) {
        g_pObservedEPV->Release();
        g_pObservedEPV = nullptr;
    }
}

static void AttachMicEndpoint() {
    DetachMicEndpoint();
    if (!g_savedMicCb) return;

    g_pObservedEPV = GetDefaultCaptureEPV();
    if (!g_pObservedEPV) return;

    g_pMicCallback = new MicEndpointCallback(g_savedMicCb);
    HRESULT hr = g_pObservedEPV->RegisterControlChangeNotify(g_pMicCallback);
    if (FAILED(hr)) {
        DetachMicEndpoint();
    }
}

bool RegisterMicNotification(MicChangeCallback cb, AudioDeviceChangeCallback onDeviceChanged) {
    UnregisterMicNotification();
    g_savedMicCb = std::move(cb);

    if (onDeviceChanged) {
        HRESULT hrEnum = CoCreateInstance(
            __uuidof(MMDeviceEnumerator), nullptr,
            CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
            reinterpret_cast<void**>(&g_pDeviceEnum));
        if (SUCCEEDED(hrEnum) && g_pDeviceEnum) {
            g_pDeviceNotify = new MicDeviceNotificationClient(std::move(onDeviceChanged));
            HRESULT hrReg = g_pDeviceEnum->RegisterEndpointNotificationCallback(g_pDeviceNotify);
            if (FAILED(hrReg)) {
                g_pDeviceNotify->Release();
                g_pDeviceNotify = nullptr;
                g_pDeviceEnum->Release();
                g_pDeviceEnum = nullptr;
            }
        }
    }

    AttachMicEndpoint();
    return (g_pObservedEPV != nullptr || g_pDeviceNotify != nullptr);
}

bool RefreshMicNotification() {
    AttachMicEndpoint();
    return g_pObservedEPV != nullptr;
}

void UnregisterMicNotification() {
    DetachMicEndpoint();

    if (g_pDeviceEnum && g_pDeviceNotify) {
        g_pDeviceEnum->UnregisterEndpointNotificationCallback(g_pDeviceNotify);
    }
    if (g_pDeviceNotify) {
        g_pDeviceNotify->Release();
        g_pDeviceNotify = nullptr;
    }
    if (g_pDeviceEnum) {
        g_pDeviceEnum->Release();
        g_pDeviceEnum = nullptr;
    }
    g_savedMicCb = nullptr;
}
