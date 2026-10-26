#pragma once
#include "Config.hpp"
#include <string>

// Eylem dağıtıcı – tek giriş noktası
void DispatchAction(Action act, const std::wstring& customAppPath = L"", bool soundFx = true);
