import collections, json, pathlib, re
root=pathlib.Path(__file__).resolve().parent
rows=json.loads((root/'changelog-rows.json').read_text(encoding='utf-8-sig'))
inventory=(root/'vendor-file-inventory.txt').read_text(encoding='utf-8-sig')
donor=(root/'donor-file-inventory.txt').read_text(encoding='utf-8-sig')
checks=(root/'port-component-checks.txt').read_text(encoding='utf-8-sig')
special={
'503532':('PRESENT','Port power service rc already says group system readproc.','port-component-checks.txt'),
'507525':('CANDIDATE','Lineage libperfmgr binary is present. Check paused-session thread-update behavior; source-level inclusion cannot be inferred from its filename. This does not fix missing Oplus IPerformance.','vendor-file-inventory.txt; reviews/507525.patch'),
'507152':('CANDIDATE','Lineage ADPF implementation is present. Verify heuristic-profile switching and exact binary provenance before rebuilding the service.','vendor-file-inventory.txt; reviews/507152.patch'),
'506374':('CANDIDATE','Actual audio interface is legacy HIDL 6.0. Android 17 strict dynamic routing can affect USB/Bluetooth paths. Compare donor AudioPolicyManager behavior and test USB audio; inclusion in LOS system does not carry into ColorOS.','handoff-2026-10-15.md; reviews/506374.patch'),
'505310':('RELEVANT-BUT-INSUFFICIENT','ColorOS waits for IOplusProject; port vendor manifest has no such service. Matrix version 3 is a declaration, not an implementation. Repair the actual caller/service contract; do not add a fake declaration.','port-vendor-manifest.xml; logs/plk-live2/rec-power-nfc.txt'),
'507507':('CONDITIONAL','Patch forwards an old BufferPoolSender symbol for proprietary Dolby Codec2. Topic targets SM8550; no matching Dolby Codec2 store found in port vendor. Donor Dolby effect/config files alone are insufficient. Require exact unresolved symbol/client evidence.','vendor-file-inventory.txt; reviews/507507.patch'),
'507300':('CONDITIONAL','Port vendor has libui.so but no libui-v32.so. A missing optional shim is not itself a defect. Check client DT_NEEDED and missing symbol ABI before adding it.','vendor-file-inventory.txt; reviews/507300.patch'),
'507128':('CONDITIONAL','Fix addresses a MotionEvent ABI/null-transform failure in WFD. Our power-key delay is an Oplus service lookup, not that crash. Check donor WFD dependencies and casting/input trace separately.','handoff-2026-10-15.md; reviews/507128.patch'),
'506215':('CANDIDATE','NXP NFC HAL exists in vendor. This is a REVERT of a problematic timer cleanup change, not a new timer fix. Verify binary ancestry and shutdown/restart behavior; reader inactivity alone does not prove this defect.','port-component-checks.txt; reviews/506215.patch'),
'505158':('ENFORCING-AUDIT','Camera provider exists. Compare effective policy for persist-camera reads before returning to enforcing. It cannot fix missing LLNDK library visibility or pop-up motor integration.','handoff-2026-10-15.md; reviews/505158.patch'),
'505182':('ENFORCING-AUDIT','Fingerprint/TEE stack exists. Check qseecomd create access to /data/vendor in effective merged policy. Current permissive operation cannot establish enforcing correctness.','handoff-2026-10-15.md; reviews/505182.patch'),
'505177':('CONDITIONAL','Reverts display config-ID workaround because device-tree cause was fixed. Do not import both original and revert; inspect current composer/kernel behavior first. Our SET_LAYER_TYPE failure was separately repaired in SF.','handoff-2026-10-15.md; reviews/505177.patch'),
'504302':('CONDITIONAL','Original config-ID workaround is followed by revert 505177. Compare extended config collisions; no evidence it fixes our QTI extension command mismatch.','handoff-2026-10-15.md; reviews/504302.patch'),
'507480':('NO-FUNCTIONAL-CHANGE','Refactors shared V3/V4 Bluetooth parcel conversion without changing entry points or supported tags. Do not treat this cleanup as a repair for a demonstrated port fault.','reviews/507480.patch'),
'507363':('CONDITIONAL','Port exposes Bluetooth audio AIDL V6. This patch adapts old V4 callers; require client symbol/return-object evidence, not merely V6 service presence.','port-component-checks.txt; reviews/507363.patch'),
'507319':('CONDITIONAL','Patch repairs V3 caller/V6 return-object mismatch that can corrupt the stack during A2DP open. Inspect actual legacy client imports and test A2DP; Bluetooth being enabled does not prove audio streaming.','port-component-checks.txt; reviews/507319.patch'),
'358161':('CONDITIONAL','Legacy camera allocation compatibility may be relevant in principle, but this patch is build-gated and topic targets SDM845. Inspect SM8150 gralloc/CamX ABI and reproduce buffer allocation failure first.','reviews/358161.patch; handoff-2026-10-15.md'),
'437263':('BUILD-TIME-ONLY','Introduces a build flag for legacy custom camera formats. Existing vendor gralloc is already compiled; verify its setting/provenance before considering a rebuild.','reviews/437263.patch; vendor-file-inventory.txt'),
'506431':('NO-CURRENT-NEED','High-priority EGL context is an animation scheduling improvement. The observed display fault was unsupported QTI composer commands and was fixed by the SF extension gate; no matching scheduling failure is established.','reviews/506431.patch; handoff-2026-10-15.md'),
'502511':('NOT-TARGET-HARDWARE','MediaTek offload coexistence mechanism does not target Snapdragon SM8150. Check Qualcomm path independently.','reviews/502511.patch; handoff-2026-10-14.md'),
'506972':('CONDITIONAL','Bluetooth offload coexistence guard is related to reserved buffers, not proof of the port audio failure. Check whether the ColorOS Bluetooth implementation contains that mechanism and measure streaming before adapting.','reviews/506972.patch; handoff-2026-10-15.md'),
'506390':('CONDITIONAL','Removes an unused Bluetooth callback field. Confirm actual callback ABI/implementation before changing a donor module; no matching failure is recorded.','reviews/506390.patch'),
'505862':('CONDITIONAL','HDR capability advertising must match panel capabilities. Compare live HWC advertised HDR types and panel bindings; no evidence this fixes the QTI command parse failure.','reviews/505862.patch; handoff-2026-10-15.md'),
'505239':('PRESENT-EQUIVALENT','Port pipeline explicitly enables ADB and bakes this PC key for debugging. This provides the intended debug access through our own build configuration, not proof the donor contains the upstream revert.','tools/build-port-b.sh'),
'506461':('NO-CURRENT-NEED','No folio daemon appears in port vendor inventory. Removing a Lineage component that is absent does not repair this port.','vendor-file-inventory.txt; reviews/506461.patch'),
'506382':('NO-DIRECT-PORT','Change removes a Lineage OplusDoze help dialog, not a sensor algorithm or hardware fix; ColorOS has its own doze UI.','donor-file-inventory.txt; reviews/506382.patch'),
'459688':('BUILD-TIME-ONLY','Sensor module source-directory reorganization is not a runtime ALS fix. FusionLight implementation/profile compatibility is audited separately.','reviews/459688.patch'),
'505234':('BUILD-TIME-ONLY','Car-framework source dependency cycle is outside the repacked phone image build pipeline.','reviews/505234.patch; tools/build-port-b.sh'),
'503184':('CONDITIONAL','Native HWUI path self-add bug requires comparing donor libhwui behavior/source. No matching graphics crash is recorded; this is separate from the fixed composer command incompatibility.','reviews/503184.patch; handoff-2026-10-15.md'),
'507264':('CONDITIONAL','Assist-key event consumption change is not the recorded Theia power-key service wait. Test assist key only if an actual mapped assist button/gesture misbehaves.','reviews/507264.patch; logs/plk-live2/rec-power-nfc.txt'),
'506995':('NO-DIRECT-PORT','Adds a framework max-refresh API for a client integration such as pen support. ColorOS has its own display APIs; no missing caller symbol or refresh fault is established here.','reviews/506995.patch; handoff-2026-10-15.md'),
'505853':('CONDITIONAL','Restores a framework API for compatibility. Inspect donor InputManager and actual client NoSuchMethodError before adapting; power input is already received by ColorOS.','reviews/505853.patch; logs/plk-live2/rec-power-nfc.txt'),
'438952':('CONDITIONAL','DRM/wvmkiller AIDL adaptation needs actual Widevine service/dependency and playback checks. No recorded failure identifies this component as a cause.','reviews/438952.patch; vendor-file-inventory.txt'),
'505137':('CONDITIONAL','Telephony special-code parsing change needs ColorOS PhoneInterfaceManager and an appropriate non-destructive code test. No SIM or special-code failure has been verified; do not run service/reset codes for diagnosis.','reviews/505137.patch; handoff-2026-10-15.md'),
}
app_repos=['android_packages_apps_Catapult','android_packages_apps_Launcher3','android_packages_inputmethods_LatinIME','android_packages_apps_Canvas','android_packages_apps_Twelve','android_packages_apps_ExactCalculator','android_packages_apps_LineageParts','android_packages_apps_SetupWizard','android_packages_apps_EuiccPolicy','android_packages_apps_Updater','android_packages_apps_Messaging','android_lineage-sdk','android_packages_apps_DeskClock']
for row in rows:
    p=root/'reviews'/(row['id']+'.json'); patch=root/'reviews'/(row['id']+'.patch')
    data=json.loads(p.read_text(encoding='utf-8-sig')) if p.exists() else {}
    rev=data.get('revisions',{}).get(data.get('current_revision'),{})
    files=[x for x in rev.get('files',{}) if x!='/COMMIT_MSG']
    repo=row['repo']; title=row['title']; topic=data.get('topic','')
    status,reason,evidence=special.get(row['id'],('UNRESOLVED','Requires direct donor implementation or runtime comparison; do not infer inclusion from Android version.','reviews/'+row['id']+'.json; reviews/'+row['id']+'.patch'))
    if row['id'] not in special:
        if repo in app_repos:
            status='NO-DIRECT-PORT'; reason='Targets a Lineage app/SDK implementation rather than the ColorOS counterpart. Donor inventory uses OplusLauncher/Settings; keyboard installation is a separate missing-package task. Similar user-visible defects require inspecting the ColorOS implementation.'; evidence='donor-file-inventory.txt; '+evidence
        elif repo in ['android_hardware_qcom_audio-ar','android_vendor_qcom_opensource_arpal-lx']:
            status='NOT-TARGET-STACK'; reason='Patch is for newer PAL/audio-ar stack. Port runs android.hardware.audio@6.0-impl and legacy msmnile audio HAL. Do not transplant PAL/AIDL interface versions into it.'; evidence='vendor-file-inventory.txt; port-vendor-manifest.xml; '+evidence
        elif 'eSim' in title or 'Euicc' in title or 'EUICC' in title or 'Pen:' in title or 'pogo_keyboard' in title or 'iceland wakeup' in title:
            status='NOT-TARGET-HARDWARE'; reason='Patch targets eSIM switching or tablet/pen/pogo hardware, not a demonstrated GM1910 hardware path. No corresponding port vendor service is inventoried.'; evidence='port-vendor-manifest.xml; '+evidence
        elif 'fusionlight' in title or 'FusionLight' in title or 'oplusSensor' in title:
            status='CONDITIONAL'; reason='Donor contains fusionlight profiles but vendor inventory has no FusionLight SubHAL. Profile presence alone does not mean this algorithm runs. Inspect current sensor HAL and ALS behavior before importing a sensor subHAL.'; evidence='donor-file-inventory.txt; vendor-file-inventory.txt; '+evidence
        elif 'Dolby' in title or 'dolby' in topic:
            status='CONDITIONAL'; reason='Shared Oplus Dolby support is not guacamole-specific. No corresponding Dolby service found in port vendor; donor effect/config assets are not proof of service implementation. Require matching service/client and ABI evidence.'; evidence='port-vendor-manifest.xml; vendor-file-inventory.txt; '+evidence
        elif repo in ['android_build','android_build_soong','android_development','android_hardware_google_pixel-sepolicy','android_hardware_lineage_generic-ims'] or 'extract-utils' in title or 'thermal' in title and 'extract' in title or title.startswith('kernel:') or 'generated_kernel_includes' in title or 'toolbox/modprobe' in title:
            status='BUILD-TIME-ONLY'; reason='Change affects source build/extraction tooling or another product policy. Our pipeline repacks existing images; this change is not automatically a runtime repair. Revisit if rebuilding that component from source.'; evidence='tools/build-port-b.sh; '+evidence
        elif 'super size' in title or 'GrowBlockDevices' in title or repo in ['android_bootable_recovery'] or title.startswith('fastbootd:'):
            status='NO-CURRENT-NEED'; reason='Recovery/dynamic-layout change does not address current running ColorOS failures. Port uses static slot-B system/vendor and the existing Lineage recovery; do not repartition to apply it.'; evidence='handoff-2026-10-14.md; '+evidence
        elif 'sdm845' in title or 'parrot/taro' in title or 'cape MSM' in title:
            status='NOT-TARGET-HARDWARE'; reason='Patch explicitly gates another SoC/platform. Guacamole is SM8150. Review shared code separately only if a matching defect appears.'; evidence='handoff-2026-10-14.md; '+evidence
        elif 'UDFPS' in title or 'face enroll' in title or 'face attention' in title or 'face enrollment' in title:
            status='CONDITIONAL'; reason='Lineage Settings/SystemUI rendering or face-HAL integration is not the failing ColorOS enrollment-video path. Compare ColorOS equivalent and reproduce geometry/rotation issue before porting.'; evidence='handoff-2026-10-15.md; '+evidence
        elif 'sepolicy:' in title:
            status='ENFORCING-AUDIT'; reason='Compare service/type/node presence and compiled merged policy. Permissive debug state hides enforcement defects; adding unrelated allow rules is not justified by changelog inclusion.'; evidence='port-vendor-manifest.xml; tools/patch-vendor-sepolicy.py; '+evidence
        elif 'Merge tag' in title:
            status='SOURCE-MERGE-AUDIT'; reason='Large shared upstream merge, not one guacamole defect. Inspect changed files and component provenance; do not replace this port with newer-SoC blobs.'
        elif repo=='android_vendor_lineage':
            status='NO-DIRECT-PORT'; reason='Lineage product packaging/default configuration does not directly configure ColorOS. Evaluate equivalent behavior separately.'; evidence='tools/build-port-b.sh; '+evidence
        elif repo in ['android_packages_apps_Settings','android_packages_apps_SettingsIntelligence','android_external_setupcompat','android_external_setupdesign','android_packages_services_Telephony']:
            status='CONDITIONAL'; reason='This modifies a Lineage/AOSP app while the port uses ColorOS counterparts. Compare the named class/method and trigger directly before adapting; shared package names do not establish identical implementation.'; evidence='donor-file-inventory.txt; '+evidence
        elif 'PduParser' in title or 'decodeWapPdu' in title:
            status='SECURITY-AUDIT'; reason='Security repair warrants exact donor class/method comparison independent of hardware symptoms. Current changelog and security patch string cannot prove that ColorOS includes it. No runtime exploit test is appropriate.'
        elif 'SystemUI:' in title or 'systemui:' in title or 'CharacterPickerDialog' in title or 'swipe gesture' in title:
            status='CONDITIONAL'; reason='ColorOS replaces/customizes this UI path. Check its equivalent behavior and implementation; no matching UI failure is established by the handoff.'; evidence='handoff-2026-10-15.md; '+evidence
        elif 'UVC' in title:
            status='CONDITIONAL'; reason='USB webcam gadget scripts require actual port function/configuration comparison. These changes are not pop-up camera motor/provider fixes. Avoid replacing USB scripts without checking SM8150 endpoints.'; evidence='vendor-file-inventory.txt; '+evidence
        elif 'OplusTouch' in title:
            status='CONDITIONAL'; reason='AIDL touch contract corrections are distinct from the renamed vendor HAL type and missing Oplus services. Compare actual caller/server versions and parcel fields before rebuilding interfaces.'; evidence='port-vendor-manifest.xml; '+evidence
    row.update(status=status,assessment=reason,evidence=evidence,commit=data.get('current_revision'),branch=data.get('branch'),topic=topic,changed_files=files,patch_saved=patch.exists(),review_saved=p.exists())
(root/'audit-all-24.json').write_text(json.dumps(rows,indent=2),encoding='utf-8')
counts=collections.Counter(r['status'] for r in rows)
lines=['# LineageOS 24 guacamole changelog: per-entry port audit','',
'Scope: all 265 entries exposed under next 24.0 and 20261011 build, stopping at 23.2. Captured 2026-10-15. This is the complete version-24 list on that page, not every historical Gerrit change.','',
'Evidence: existing ColorOS donor tree, out-plk/vendor.img mounted read-only, build scripts, saved boot/live logs, and each upstream commit metadata/patch. ADB subsequently connected; read-only state/HAL/media/NFC checks are saved under live/. No flash or phone modification performed. See LIVE-TESTS.md for actual runtime limits.','',
'Statuses are applicability decisions, not claims that every binary matches upstream. UNRESOLVED/CONDITIONAL/CANDIDATE require the indicated comparison or runtime test. Source absence cannot be established from filenames. Lineage system-side changes are not inherited just because vendor/boot come from Lineage.','',
'Metadata: '+str(sum(r['review_saved'] for r in rows))+'/'+str(len(rows))+' saved; patches: '+str(sum(r['patch_saved'] for r in rows))+'/'+str(len(rows))+'. Merge patches may return HTTP 409; their metadata and file lists remain saved.','',
'Assessment counts: '+', '.join(f'{k}: {v}' for k,v in sorted(counts.items())),'',
'| # | Change | Build section | Assessment | Port evidence / next check |','|---|---|---|---|---|']
for i,r in enumerate(rows,1):
    title=r['title'].replace('|','\\|'); reason=r['assessment'].replace('|','\\|')
    section='next 24.0' if 'next' in r['section'] else '20261011'
    lines.append(f"| {i} | [{r['id']}: {title}]({r['url']}) | {section} | {r['status']} | {reason} Evidence: {r['evidence']} |")
(root/'AUDIT-ALL-24.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('Rows:',len(rows),'Unique IDs:',len(set(r['id'] for r in rows)),dict(counts))
