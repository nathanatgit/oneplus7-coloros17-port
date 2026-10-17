# LineageOS 24 alert slider implementation
Verified upstream android_hardware_oneplus lineage-24.0, 2026-10-15.
- KeyHandler observes kernel uevents matching tri-state-key and tri_state_key, reads SWITCH_STATE (or legacy STATE).
- Positions 1/2/3 map to configurable silent/vibrate/normal by default, via AudioManager.ringerModeInternal and NotificationManager zen API.
- Optional mute media and DND position mappings; vibrator feedback.
- Separate AlertSliderPlugin SystemUI overlay renders dialog; device overlay places it relative to physical slider.
- tri-state-key-calibrate.sh restores existing persist/engineermode/tri_state_hall_data into hall_data_calib. Do not alter calibration.
- ColorOS action-button Settings is not this implementation. Port needs a working three-state backend and appropriate Settings entry. Native ColorOS slider path exists per handoff but misc HAL is absent; previous broad framework patch failed and was rolled back.
- No slider repair installed by this investigation.
Sources: https://github.com/LineageOS/android_hardware_oneplus/tree/lineage-24.0/packages/KeyHandler
