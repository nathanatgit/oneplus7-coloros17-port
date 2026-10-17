#!/usr/bin/env python3
"""OnePlus7Port: make the AOSP composer@2.4 command engine accept ColorOS's CAF QtiExtension SET_LAYER_TYPE.

ColorOS 17 SurfaceFlinger (QtiExtension, enabled because ro.product.first_api_level < 34) writes
IQtiComposerClient::SET_LAYER_TYPE (0x800 << 16, 1 word: type) into the composer@2.x command stream. The stock
AOSP engine rejects it ("failed to parse command 0x8000000"), which breaks presentation.

LineageOS sm8150 marks the fingerprint pressed layer by OR-ing FOD_PRESSED_LAYER_ZORDER (0x20000000, kernel
include/uapi/drm/sde_drm.h) into the layer z-order: hwcomposer.qcom.so (FOD_ZPOS) -> PLANE_SET_ZORDER ->
kernel sde_plane PLANE_CUST=2 -> fingerprint_pressed -> HBM + E_FP_EVENT_UI_READY for the Goodix HAL.
This engine sets that bit on the layer whose display frame equals persist.vendor.port.fod_rect (default: ColorOS
OnScreenFingerprintPressedIcon on guacamole) and, optionally, on layers whose QTI type equals
persist.vendor.port.fod_pressed_type. fp_mode (notify_fppress) comes from IDisplayPanelFeature feature 28.

Usage: patch-engine.py <aosp 2.4 ComposerCommandEngine.h> <output header>
"""
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read()

inc_old = '#include <composer-hal/2.3/ComposerCommandEngine.h>'
assert s.count(inc_old) == 1
s = s.replace(inc_old, inc_old + '\n#include <cutils/properties.h>\n#include <cstdio>\n#include <inttypes.h>\n#include <unordered_map>\n#include <cstring>')

old = """    bool executeCommand(V2_1::IComposerClient::Command command, uint16_t length) override {
        switch (static_cast<IComposerClient::Command>(command)) {"""
new = """    // --- OnePlus7Port: CAF QtiExtension SET_LAYER_TYPE -> FOD pressed z-order bit ---
    static constexpr uint32_t kPortQtiSetLayerType = 0x800u << 16;
    static constexpr uint32_t kPortQtiCommandBase = 0x800u << 16;
    static constexpr uint32_t kPortFodPressedZ = 0x20000000u;  // FOD_PRESSED_LAYER_ZORDER
    std::unordered_map<Layer, uint32_t> mPortLayerType;
    std::unordered_map<Layer, uint32_t> mPortLayerZ;
    uint32_t mPortUnknownLogged = 0;

    // ColorOS SystemUI's OnScreenFingerprintPressedIcon window: frame [583,2591][857,2865] on guacamole (sensor centre
    // 720,2728 r=137, = LOS config_udfps_sensor_props). It exists only while the finger is down.
    std::unordered_map<Layer, bool> mPortLayerFodRect;

    bool portRectIsFod(const hwc_rect_t& r) {
        char buf[PROPERTY_VALUE_MAX];
        property_get("persist.vendor.port.fod_rect", buf, "583,2591,857,2865");
        int l, t, rr, b;
        if (sscanf(buf, "%d,%d,%d,%d", &l, &t, &rr, &b) != 4) return false;
        return r.left == l && r.top == t && r.right == rr && r.bottom == b;
    }

    bool portIsFod(Layer layer) {
        auto f = mPortLayerFodRect.find(layer);
        if (f != mPortLayerFodRect.end() && f->second) return true;
        const int32_t pressed = property_get_int32("persist.vendor.port.fod_pressed_type", -1);
        auto it = mPortLayerType.find(layer);
        return pressed >= 0 && it != mPortLayerType.end() && it->second == static_cast<uint32_t>(pressed);
    }

    uint32_t portZ(Layer layer, uint32_t z) {
        return portIsFod(layer) ? (z | kPortFodPressedZ) : (z & ~kPortFodPressedZ);
    }

    bool portSetLayerDisplayFrame(uint16_t length) {
        if (length != 4) return false;
        hwc_rect_t r;
        r.left = readSigned();
        r.top = readSigned();
        r.right = readSigned();
        r.bottom = readSigned();
        auto err = mHal->setLayerDisplayFrame(mCurrentDisplay, mCurrentLayer, r);
        if (err != V2_1::Error::NONE) mWriter->setError(getCommandLoc(), err);
        const bool fod = portRectIsFod(r);
        if (mPortLayerFodRect.size() > 1024) mPortLayerFodRect.clear();
        bool& cur = mPortLayerFodRect[mCurrentLayer];
        if (cur != fod) {
            cur = fod;
            ALOGI("port: layer %" PRIu64 " frame [%d,%d][%d,%d] fod=%d", mCurrentLayer, r.left, r.top, r.right,
                  r.bottom, fod);
            auto z = mPortLayerZ.find(mCurrentLayer);
            if (z != mPortLayerZ.end()) {
                mHal->setLayerZOrder(mCurrentDisplay, mCurrentLayer, portZ(mCurrentLayer, z->second));
            }
        }
        return true;
    }

    bool portSetLayerType(uint16_t length) {
        if (length < 1) return false;
        const uint32_t type = read();
        for (uint16_t i = 1; i < length; i++) read();
        if (mPortLayerType.size() > 1024) mPortLayerType.clear();
        auto [it, inserted] = mPortLayerType.try_emplace(mCurrentLayer, type);
        if (inserted || it->second != type) {
            ALOGI("port: display %" PRIu64 " layer %" PRIu64 " qti type %u -> %u", mCurrentDisplay,
                  mCurrentLayer, inserted ? 0u : it->second, type);
            it->second = type;
            auto z = mPortLayerZ.find(mCurrentLayer);
            if (z != mPortLayerZ.end()) {
                mHal->setLayerZOrder(mCurrentDisplay, mCurrentLayer, portZ(mCurrentLayer, z->second));
            }
        }
        return true;
    }

    bool portSetLayerZOrder(uint16_t length) {
        if (length != 1) return false;
        const uint32_t z = read();
        if (mPortLayerZ.size() > 1024) mPortLayerZ.clear();
        mPortLayerZ[mCurrentLayer] = z;
        const uint32_t out = portZ(mCurrentLayer, z);
        if (out != z) ALOGI("port: layer %" PRIu64 " fod pressed, z 0x%x -> 0x%x", mCurrentLayer, z, out);
        auto err = mHal->setLayerZOrder(mCurrentDisplay, mCurrentLayer, out);
        if (err != V2_1::Error::NONE) mWriter->setError(getCommandLoc(), err);
        return true;
    }

    // ColorOS 17 SF sends some commands with more payload than the AOSP handler reads; the stock reader then
    // LOG_FATALs in endCommand() ("too little data read") and takes the whole display stack down (build 12, with
    // CUST_LEVEL_LIST features on). Consume and log the remainder instead.
    uint32_t mPortShortLogged = 0;
    uint32_t mPortRegionLogged = 0;
    bool executeCommand(V2_1::IComposerClient::Command command, uint16_t length) override {
        const uint32_t start = mDataRead;
        const bool parsed = portExecuteCommandInner(command, length);
        const uint32_t used = mDataRead - start;
        if (used < length) {
            if (mPortShortLogged++ < 50) {
                ALOGW("port: command 0x%x length %u consumed %u (parsed %d), skipping the rest",
                      static_cast<uint32_t>(command), length, used, parsed);
            }
            for (uint32_t i = used; i < length; i++) read();
        }
        return parsed;
    }

    bool portExecuteCommandInner(V2_1::IComposerClient::Command command, uint16_t length) {
        const uint32_t raw = static_cast<uint32_t>(command);
        if (raw == kPortQtiSetLayerType) return portSetLayerType(length);
        if (raw >= kPortQtiCommandBase) {  // other vendor (QTI) commands: consume, don't fail the frame
            for (uint16_t i = 0; i < length; i++) read();
            if (mPortUnknownLogged++ < 20) ALOGW("port: skipped vendor command 0x%x, length %u", raw, length);
            return true;
        }
        if (command == V2_1::IComposerClient::Command::SET_LAYER_Z_ORDER) return portSetLayerZOrder(length);
        // ColorOS 17 SF sends SET_LAYER_GENERIC_METADATA (composer 2.4, 0x40e) for Oplus layer metadata although the
        // LOS HAL advertises no metadata keys, in a layout the AOSP parser rejects (seen: length 19) ->
        // presentOrValidate BAD_PARAMETER (hung screen) or, unconsumed, LOG_FATAL "too little data read" (composer
        // abort -> display stack restarts, build 12). The HAL has nothing to do with it: log the key once, consume, accept.
        if (command == static_cast<V2_1::IComposerClient::Command>(IComposerClient::Command::SET_LAYER_GENERIC_METADATA)) {
            if (mPortRegionLogged++ < 20 && length >= 1) {
                const uint32_t keySize = mData[mDataRead];
                char key[64] = {};
                if (keySize > 0 && keySize < sizeof(key) && (keySize + 3) / 4 + 1 <= length) {
                    memcpy(key, &mData[mDataRead + 1], keySize);
                }
                ALOGW("port: ignoring generic metadata length %u key '%s'", length, key);
            }
            for (uint16_t i = 0; i < length; i++) read();
            return true;
        }
        if (command == V2_1::IComposerClient::Command::SET_LAYER_DISPLAY_FRAME) {
            return portSetLayerDisplayFrame(length);
        }
        switch (static_cast<IComposerClient::Command>(command)) {"""
assert s.count(old) == 1, 'executeCommand anchor changed'
s = s.replace(old, new)
open(dst, 'w').write(s)
print('patched ->', dst)
