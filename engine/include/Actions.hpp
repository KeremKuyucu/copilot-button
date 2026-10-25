#pragma once
#include "Config.hpp"
#include <string>

// Eylem dağıtıcı – tek giriş noktası
// Actions.cpp içinde tanımlanmıştır.
void DispatchAction(Action act, const std::wstring& customAppPath, bool soundFx);
