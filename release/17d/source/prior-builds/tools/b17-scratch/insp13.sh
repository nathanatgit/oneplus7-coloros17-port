export PATH=/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd /root/b17
for a in los-se h40-se c17-sysui h40-sysui; do echo "## $a"; unzip -l $a.apk | grep -E 'META-INF/.*\.(RSA|EC|DSA)' | head -2
 r=$(unzip -Z1 $a.apk | grep -E '^META-INF/.*\.(RSA|EC|DSA)$' | head -1)
 [ -n "$r" ] && unzip -p $a.apk "$r" | openssl pkcs7 -inform DER -print_certs | openssl x509 -noout -fingerprint -sha256 -subject; done
for a in los-se h40-se; do echo "## manifest $a"; unzip -p $a.apk AndroidManifest.xml | strings -e l | head -60 | tr '\n' ' '; echo; done
