#pragma once
#include "Config.hpp"

// Eylem dağıtıcı – tek giriş noktası
void DispatchAction(Action act, const Config& cfg);
