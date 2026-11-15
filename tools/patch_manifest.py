"""Parchea el AndroidManifest generado por `flutter create`:
- permiso de INTERNET (necesario en release)
- <queries> para que url_launcher pueda abrir enlaces https
- nombre visible de la app
Ejecutar desde la raíz del proyecto:  python tools/patch_manifest.py
"""
import pathlib

p = pathlib.Path("android/app/src/main/AndroidManifest.xml")
s = p.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in s:
    s = s.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n    <application',
        1,
    )

if "<queries>" not in s:
    s = s.replace(
        "<application",
        "<queries>\n"
        "        <intent>\n"
        '            <action android:name="android.intent.action.VIEW"/>\n'
        '            <data android:scheme="https"/>\n'
        "        </intent>\n"
        "    </queries>\n"
        "    <application",
        1,
    )

s = s.replace('android:label="looks_ia"', 'android:label="Looks IA"')
p.write_text(s, encoding="utf-8")
print("AndroidManifest.xml parcheado")
