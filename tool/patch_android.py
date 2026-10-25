import pathlib, re, sys

key = sys.argv[1]
root = pathlib.Path("android")

# 1) Manifest: permissões + chave do Google Maps
mf = root / "app/src/main/AndroidManifest.xml"
t = mf.read_text()
perms = (
    '<uses-permission android:name="android.permission.INTERNET"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>\n'
    '    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>\n'
    '    '
)
assert "<application" in t, "manifest sem <application>"
t = t.replace("<application", perms + "<application", 1)
meta = (
    '\n        <meta-data android:name="com.google.android.geo.API_KEY" '
    'android:value="' + key + '"/>'
)
t = re.sub(r"(<application[^>]*>)", lambda m: m.group(1) + meta, t, count=1)
mf.write_text(t)

# 2) settings.gradle: plugin do Google Services
sg = root / "settings.gradle"
t = sg.read_text()
pat = r'(id "com\.android\.application" version "[^"]+" apply false)'
assert re.search(pat, t), "padrão não encontrado em settings.gradle"
t = re.sub(
    pat,
    lambda m: m.group(1) + '\n    id "com.google.gms.google-services" version "4.4.2" apply false',
    t, count=1,
)
sg.write_text(t)

# 3) app/build.gradle: plugin, minSdk 23 e compileSdk 35
bg = root / "app/build.gradle"
t = bg.read_text()
assert 'id "kotlin-android"' in t, "padrão não encontrado em app/build.gradle"
t = t.replace('id "kotlin-android"', 'id "kotlin-android"\n    id "com.google.gms.google-services"', 1)
t, n = re.subn(r"minSdk\s*=?\s*flutter\.minSdkVersion", "minSdk = 23", t)
assert n == 1, "minSdk não encontrado"
t, n = re.subn(r"compileSdk\s*=?\s*flutter\.compileSdkVersion", "compileSdk = 35", t)
assert n == 1, "compileSdk não encontrado"
bg.write_text(t)
print("Patch Android aplicado com sucesso")
