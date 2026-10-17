set -e
cd "$(dirname "$0")"
python3 gen.py
smali a smali -o port-charger.dex
sha256sum port-charger.dex
