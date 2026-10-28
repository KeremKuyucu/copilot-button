#pragma once
#ifndef WIN32_LEAN_AND_MEAN
#  define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#include <functional>

// ─────────────────────────────────────────────
//  Mikrofon işlemleri
// ─────────────────────────────────────────────
bool GetMicMuteState();
void SetMicMuteState(bool mute);
void ToggleMicMute();

// ─────────────────────────────────────────────
//  Master ses işlemleri
// ─────────────────────────────────────────────
bool GetMasterMuteState();
void ToggleMasterMute();

// ─────────────────────────────────────────────
//  Hem mikrofon hem master sesini aynı anda sustur/aç
// ─────────────────────────────────────────────
void ToggleDeafen();

// ─────────────────────────────────────────────
//  Medya tuşları
// ─────────────────────────────────────────────
void SendMediaKey(WORD vk);

// ─────────────────────────────────────────────
//  Ses efekti oynat (Windows Media klasöründen)
// ─────────────────────────────────────────────
void PlayMicSound(bool muted);

// ─────────────────────────────────────────────
//  Harici mikrofon durumu izleme (Event-driven)
//  Donanım kulaklık düğmesi veya Windows ayarlarından
//  gelen değişiklikleri anında yakalar.
// ─────────────────────────────────────────────
using MicChangeCallback = std::function<void(bool isMuted)>;
bool RegisterMicNotification(MicChangeCallback cb);
void UnregisterMicNotification();
