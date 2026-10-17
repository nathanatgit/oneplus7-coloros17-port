. /mnt/c/Users/Han/Project/OnePlus7Port/tools/b17-scratch/mnt.sh
grep -rn 'nfc_se' /mnt/i-eodm/etc/init /mnt/i-eodm/init*.rc 2>/dev/null
for f in /mnt/i-eodm/bin/hw/android.hardware.nfc@1.2-service /mnt/i-eodm/lib64/nfc_nci.pn54x.default.so /mnt/i-eodm/lib64/hal_libnfc.so /mnt/i-eodm/lib64/ese_spi_nxp_nq330.so; do echo "## $f"; strings $f | grep -i 'config_ready\|nfc_se\|no_ese\|wait_config' ; done
objdump -d --no-show-raw-insn /mnt/i-eodm/bin/hw/android.hardware.secure_elementnq330@1.1-service 2>/dev/null | grep -n 'config_ready' | head -3
