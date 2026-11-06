# Battery handoff: OnePlus 7 Pro (GM1910) ColorOS 17 port — asking for outside help

Date: 2026-11-05. Written for: someone outside this project (kernel/power dev, SD855 community, or similar) being asked to help diagnose the open issue below. Two related issues are already fixed; one is still open and is the reason for this handoff.

## Device and software

- **Hardware:** OnePlus 7 Pro, GM1910, codename `guacamoleb`, Snapdragon 855 (msmnile), battery fuel gauge is a Qualcomm Gen4 FG (`bms` power_supply), charger IC exposes an OPLUS driver (`battery` power_supply).
- **Software:** a custom port — LineageOS 24 (Android 15) kernel/vendor base, with a ColorOS 17 donor system grafted on top (not a stock ROM). Build tag `17j-r2`. Bootloader unlocked, `su` available, SELinux is **permissive** on this build.
- This is NOT stock firmware, so stock-ROM assumptions about which driver owns what may not hold — but the kernel/vendor side is the donor's own LineageOS-based vendor blobs for this device, so kernel behavior should be representative of the real SD855/WCD9340 platform.

## Issue 1 (FIXED, verified live, not yet baked into a build): 85% charge limit did nothing

**Symptom:** user sets a charge limit of 85% in the ColorOS Battery settings; phone keeps charging past it.

**Root cause:** the ColorOS Battery app sends the limit via `OplusBatteryManager.setChgConfig(14, "2++<switch>+<level>")` → `ICharger.setChgConfig()`. On stock ColorOS/OPLUS hardware, the vendor charger HAL implements this and performs the cutoff. This port's `ICharger` is a Java re-implementation (not the real vendor HAL) and had `setChgConfig`/`getChgConfig` stubbed as no-ops — so the limit was accepted by the UI but never reached hardware.

**Confirmed working hardware control:** `/sys/class/power_supply/battery/mmi_charging_enable` — writing `0` stops charging (status → `Not charging`/`Discharging`) within ~4s; writing `1` resumes it. `input_suspend` also stops the charge current but leaves `status` misleadingly as `Charging`.

**Fix:** a small userspace daemon (`port-chglimit.sh`) polls the Settings keys the Battery app writes (`regular_charge_protection_switch_state`, `regular_charge_protection_open_power_level`) and toggles `mmi_charging_enable` accordingly. Verified live holding at an arbitrary level (30%) for 5+ minutes with correct release/re-hold behavior. Not yet baked into a system image (lives as a live-patched init service for now).

## Issue 2 (FIXED, verified live, not yet baked): reported battery % reads ~10-15 points too high

**Symptom:** Android/Settings showed 97-100% while the real battery was at ~84%.

**Root cause:** Android's health HAL/BatteryService reads `/sys/class/power_supply/battery/capacity` — the **OPLUS charger driver's own SoC estimate**, not the Qualcomm fuel gauge (`/sys/class/power_supply/bms/capacity`). The OPLUS driver's SoC **snapped to 100% and held there** immediately after issue 1's cutoff fix stopped the charge current (it appears to interpret `mmi_charging_enable=0` as "charge complete"), then decayed slowly (~1%/10-15min) back toward reality. The Qualcomm fuel gauge (coulomb counter vs `charge_full`) stayed accurate throughout and tracked the real level.

**Fix:** a bind-mount (`port-bmslevel.sh`) that continuously rewrites `battery/capacity` from the real `bms/capacity` value every 5s, so every reader (Android's health HAL, the OPLUS services, our own chglimit daemon) sees the truth. Verified live: framework level matches the fuel gauge within ~1% and tracks it live while charging.

**Caveat found along the way:** after a hard hang/reboot, the Qualcomm fuel gauge's own coulomb counter can itself be briefly wrong (we saw it under-read to ~5-8% against a battery that was actually ~45%, self-correcting over the next charge cycle) — so immediately-post-reboot readings from `bms/capacity` should also be treated with suspicion for the first charge/discharge cycle.

## Issue 3 (OPEN — this is what we need help with): ~100-170 mA continuous drain with the screen off, unexplained

### The problem, stated precisely

With the screen off and the phone otherwise idle, the battery drains at a sustained **100-170 mA**, measured via the Qualcomm fuel gauge's coulomb counter (`bms/charge_counter`) over multi-minute to multi-hour windows (unplugged, on battery). A healthy modern phone idles at roughly 1-30 mA screen-off. This has been reproduced across multiple nights and shorter sessions and does not vary much:

| Test | Duration | Conditions | Result |
|---|---|---|---|
| Overnight 1 | ~2.4h (sampled), ~10h total | AOD on, everything else default | ~99 mA sustained |
| Overnight 2 | ~10h | AOD toggled via (unreliable) Settings keys, ambiguous whether really off | 107-140 mA across several sub-windows |
| Daytime, hands-off except brief checks | ~2h | default | 157-194 mA (includes some screen-on time, so not pure idle) |
| Fast test A (baseline) | 5 min | all defaults | 174 mA |
| Fast test B | 5 min | **airplane mode** (modem radio fully POWER_OFF, confirmed via `dumpsys telephony.registry`) | 161 mA |
| Fast test C | 5 min | **Bluetooth off** (`svc bluetooth disable`, confirmed `bluetooth_on=0`) | 156 mA |
| Fast test D | 5 min | **Breeno/OPLUS wake-word service disabled** (`pm disable-user com.oplus.ovoicemanager.wakeup`) | 163 mA |
| Fast test E | 5 min | **Battery saver ON** (`low_power=1`, confirmed `mSettingBatterySaverEnabled=true`) | 158 mA |
| Fast test F | ~7.3 min, stopped early | all defaults, **zero adb commands sent during the window** (single launch, single final read, to rule out adb-over-Wi-Fi polling itself as a confound) | 145 mA |
| Test G | 30 min | **`/sys/power/mem_sleep` forced to `deep`** instead of the default `s2idle` (confirmed active throughout: `cat /sys/power/mem_sleep` → `s2idle [deep]`) | 147 mA |

**None of these individual toggles produced anything beyond noise-level change** (all cluster 145-194 mA for the short tests, which have more sampling noise than the 20min+ tests). Test F also rules out the adb-over-Wi-Fi polling itself as a source of the elevated numbers — with literally zero commands sent during the measurement window, the result (145 mA) was the same as every polled test. We also independently confirmed:
- **CPU is genuinely suspending**, not stuck awake: in a ~10h overnight window the CPU was only awake ~18% of the time at worst, and in the cleanest 51-minute window, CPU uptime was only 2.9% of elapsed wall time (deep sleep ~97%).
- **No wakeup source is blocking suspend**: every node under `/sys/class/wakeup/*/prevent_suspend_time_ms` reads 0. Suspend is completing successfully (`dmesg`-counted suspend aborts are low single digits per night, and are transient, not a loop).
- **No crash-loop services**: audio HAL, sensors HAL, GNSS HAL, IMS daemons all have process age == system uptime (no restarts). One-off `cameraserver` SIGABRT and `qtidataservices` FATAL EXCEPTION were seen once each, tied to unrelated camera testing, not recurring.
- **Forcing real `deep` suspend instead of the default `s2idle` makes no measurable difference either** (test G). `dmesg` does not reliably log every suspend/resume cycle on this kernel (a cluster of ~270ms-apart "suspend entry (deep)" lines found in the ring buffer turned out to be ~18h old, from an unrelated earlier session, not from this test — there were zero matching lines inside the actual test window). The test script's own forced-wake sample spacing was irregular (70-138s apart instead of the intended ~30s), suggesting the CPU did sleep in longer, less-interrupted stretches under `deep` than under `s2idle` — but the average current draw was identical. This is a meaningful negative result: **the drain appears unrelated to suspend depth or wake frequency**, which argues against a software/scheduling cause and further toward a steady hardware-level draw.
- **Battery saver mode makes no measurable difference either** (test E above). Dumping `dumpsys power`'s battery-saver policy explains why on this specific ColorOS build: the "effective" policy explicitly overrides `disable_aod` back to `false` and `soundtrigger_mode` back to `0` (via a `battery_saver_constants` Settings override: `soundtrigger_disabled=false,aod_disabled=false`), so saver mode doesn't touch AOD or the wake-word service here. Its other real effects (`force_all_apps_standby`, `force_background_check`, `disable_optional_sensors`, dimmer brightness, quicker Doze) are all app/scheduling-level things that bite during screen-on/active use, not screen-off idle — consistent with them not moving the floor.
- **AOD (always-on display)** only renders for ~0.8s per screen-off event (confirmed via the systemui log line `CapsuleDataHandler-->newState: ...aodEnable=false, aodDisplayState=OFF` appearing right after a brief `DOZE` transition) — it is NOT continuously rendering, so it cannot be the ~150mA floor.
- **Not a USB-powered artifact**: tried measuring with the charge-cutoff fix forcing `status=Discharging` while physically still plugged in, to get faster iteration without needing full unplug cycles. This back-fired: even with the screen actively on, the coulomb counter barely moved (<20mA), proving the charger IC still powers the system directly from VBUS (power-path bypass) regardless of the charge-enable state — so that shortcut is invalid and all real numbers above are from genuine physical-unplug tests.

### What has NOT been ruled out / where we need help

1. **Whether the SoC is reaching its actual lowest-power sleep state at all.** `cpuidle` sysfs on this device only exposes two states per CPU (`C0`, `C1`) with no visibility into deeper SoC/RPM(h) power-domain states, and `/sys/kernel/debug` does not exist on this kernel. **Root cause confirmed, not a port bug:** `zcat /proc/config.gz` on the running kernel shows `# CONFIG_DEBUG_FS is not set` and `# CONFIG_PM_DEBUG is not set`. Traced to upstream `LineageOS/android_kernel_oneplus_sm8150` (branch `lineage-24.0`), file `arch/arm64/configs/vendor/debugfs.config`, which explicitly sets `CONFIG_DEBUG_FS=n`. This is deliberate upstream kernel configuration (likely hardening), not something broken by this cross-vendor port, but it does mean the usual `rpmh_stats`/`genpd_summary`/`regulator_summary` debugfs diagnostics are categorically unavailable on any LineageOS-24-based build for this device family, not just this one. Also confirmed from the same config dump: `# CONFIG_PM_AUTOSLEEP is not set` — there is no automatic kernel-side suspend trigger at all; suspend is driven entirely by whatever loop the userspace `android.system.suspend-service` HAL runs (see the finding below). **Question for anyone who knows this kernel:** is there a non-debugfs way to inspect RPMh/XO sleep-state residency on an SM8150 with `CONFIG_DEBUG_FS=n` (a QMI/diag command, a different sysfs path, SCM call, or similar)?

   **Suspend completes normally (a "94 vs 4" mismatch reported in an earlier draft was wrong, retracted 2026-11-06).** That reading was taken ~6 minutes after a reboot, not over 28 hours. After an overnight run (11.5 h uptime), `/sys/power/suspend_stats/success = 8163` matches `SuspendControl.NormalSuspendDelay = 8164` almost exactly, so the SystemSuspend HAL and the kernel agree. What remains: `fail = 466` (`SuspendControl.FailedSuspendDelay` 466, 158 s total backoff) and `failed_suspend_noirq = 620`, with `last_failed_dev = 18800000.qcom,icnss` (WLAN). About 5 % of suspend attempts are aborted by the WLAN driver. That is real but probably too small to explain ~150 mA on its own.

   **RPMh residency is not visible anywhere on this build:** the DT nodes `b221200.qcom,rpmh-master-stats`, `c300000.qcom,rpm-stats` and `c221000.qcom,mpm2-sleep-counter` exist under `/sys/devices/platform/soc/` but have no driver bound (no stats files); there is no `android.hardware.power.stats` HAL, so batterystats' `vmin=0 vlow=0 apss=0 mpss=0 adsp=0 cdsp=0` fields are unpopulated (all 129 history samples are zero), not measured. The CPU-side low-power config looks correct: `lpm_levels` has `sleep_disabled=N` and every level enabled for idle and suspend, including the system-level `L3/llcc-off`; cpuidle driver `msm_idle` exposes `wfi` and `rail-pc`. So the CPUs and cluster are allowed to collapse; whether the whole SoC then reaches XO shutdown / VDD_MIN depends on the other subsystems (modem, ADSP, CDSP, SLPI, WLAN) releasing their RPMh votes, and that is exactly what cannot be observed here. Kernel: `4.14.357-openela-perf`.
   - Separately, boot-time `dmesg` shows several `qcom,rpmh-regulator soc:rpmh-regulator-{mxlvl,mmcxlvl}: TCS Busy, retrying RPMH message send` lines — RPMh command-queue contention on at least two regulator rails, independent evidence of friction at exactly the layer in question.
2. **The WCD9340 codec / SLIMbus intermittently aborts suspend** (`wcd_spi_suspend` returning `-16`/EBUSY, `tavil-slim-pgd` wakeup source firing a handful of times per night) — low event count, but unclear if a failed/retried suspend here costs disproportionate power even without blocking suspend outright (i.e., does a failed suspend attempt that then succeeds on retry still cost a full suspend/resume power cycle's worth of overhead, happening silently without raising `prevent_suspend_time`?).
3. **Hardware with no easy software on/off switch that we have NOT tested in isolation**: NFC/eSE controller, fingerprint sensor controller, touchscreen controller (ruled out as an *interrupt* source — it's just touch IRQs — but not ruled out as a *continuous power draw* source), camera/ISP power rails left enabled, PMIC regulator leakage, or something in the donor ColorOS camera/codec stack that stays powered since this is a cross-vendor donor-system graft rather than a matched stock build.
4. **Whether ~100-170mA is actually anomalous for this specific board/battery**, or whether this particular unit's battery/PMIC combination (battery health reads ~81% SoH; the fuel gauge itself needed to "relearn" charge_full after a hard reboot, going from 3.571Ah to a transiently-reported 2.906Ah) has degraded enough that this is closer to "normal for this worn battery" than a software bug. We don't have a second unit or stock ROM to A/B against on the same hardware.

### Reproduction / measurement method (for anyone who wants to dig in)

- `bms/charge_counter` (µAh) delta over elapsed wall time, phone fully unplugged, screen off, gives the most reliable number; short (<20min) windows are noisy due to coulomb-counter resolution.
- `bms/current_now` instantaneous samples are unreliable as an average (heavily biased toward whatever the CPU is doing at the instant of the read, since the CPU must wake to service the read).
- adb-over-Wi-Fi works for driving these tests without needing physical replug between states, EXCEPT enabling full airplane mode kills the Wi-Fi link too (it disables Wi-Fi along with the modem) — if remote-testing a "modem off" state, either use a narrower radio toggle or accept losing remote access until Wi-Fi is independently re-enabled on top of airplane mode (ColorOS allows this combination).
- Any background script run via `adb shell su -c "... &"` needs an explicit grace period (`sleep 1-2`) before the invoking shell exits, or the backgrounded child can die with it despite `setsid`/`nohup` — Android's adb shell teardown appears to race with session detachment.

## Files, for reference (not needed to answer the question, just for completeness)

Project root `OnePlus7Port/`, live-patch scripts in `tools/live/`:
- `tools/live/chglimit/port-chglimit.sh` — Issue 1 fix
- `tools/live/battery-gauge/port-bmslevel.sh` — Issue 2 fix
- `tools/live/idle-current-test.sh` — the fast A/B test script used for Issue 3
- `tools/live/BAKE-LIST.md` — full change log with exact file hashes, verification notes, and undo commands for every live patch mentioned above
- `battery-drain-findings-2026-11-04.md` — earlier, more narrative write-up of the same Issue 3 investigation (this document supersedes it for anyone being asked to help from outside)
