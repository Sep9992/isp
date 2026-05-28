Instrukce pro Mac — krok za krokem
1. Příprava projektu

Zkopíruj celý projektový adresář z flash disku na Mac
Otevři Terminál a přejdi do adresáře projektu
Spusť flutter pub get
Spusť cd ios && pod install && cd ..

2. Otevři Xcode

Otevři soubor ios/Runner.xcworkspace (ne .xcodeproj!)
V levém panelu klikni na Runner
Záložka Signing & Capabilities
Zaškrtni Automatically manage signing
V Team vyber svůj Apple ID (přidáš ho přes Xcode → Settings → Accounts)
Bundle Identifier změň na něco unikátního, např. cz.tvéjméno.ispobedy

3. Připoj iPhone

Připoj iPhone kabelem
Na iPhonu potvrď Důvěřovat tomuto počítači
V Xcode nahoře vyber svůj iPhone jako cíl

4. Build a instalace

Zmáčkni ▶ (Run) nebo Cmd+R
Xcode app zkompiluje a nainstaluje přímo na iPhone

5. Povolit vývojářský certifikát na iPhonu

iPhone → Nastavení → Obecné → VPN a správa zařízení
Klikni na svůj Apple ID → Důvěřovat


Pokud chceš AltStore (doporučuji)
Na Macu nainstaluj AltServer z altstore.io, zbytek zařídí automaticky — certifikát obnovuje každých 7 dní přes WiFi pokud je Mac ve stejné síti.

------------------------------------------------------------------------------------------------------------------------------------------------------

Perfektně. Tady jsou přesné instrukce co dělat na Macu:

ČÁST 1 — Příprava projektu (Terminál)
bash# Přejdi do projektového adresáře
cd /cesta/k/projektu

# Nainstaluj závislosti
flutter pub get

# Nainstaluj iOS CocoaPods závislosti
cd ios && pod install && cd ..

ČÁST 2 — Nastavení Xcode

Otevři ios/Runner.xcworkspace (ne .xcodeproj!)
Vlevo klikni na Runner → záložka Signing & Capabilities
Zaškrtni Automatically manage signing
V Team klikni na Add an Account → přihlas se svým Apple ID (stačí běžné, zdarma)
Bundle Identifier změň na něco unikátního: cz.tvejmail.ispobedy


ČÁST 3 — Build IPA pro AltStore
V Terminálu:
bashflutter build ipa --no-codesign
IPA soubor najdeš v:
build/ios/ipa/isp.ipa

ČÁST 4 — Instalace AltStore

Na Macu jdi na altstore.io → stáhni AltServer pro Mac
Spusť AltServer — objeví se ikonka v menu baru (horní lišta)
Připoj iPhone kabelem
Klikni na ikonku AltServer → Install AltStore → vyber svůj iPhone
Zadej Apple ID a heslo
Na iPhonu: Nastavení → Obecné → VPN a správa zařízení → důvěřuj svému Apple ID


ČÁST 5 — Instalace tvé app přes AltStore

Na iPhonu otevři AltStore
Klikni na + (plus) vpravo nahoře
Vyber IPA soubor (přenést ho na iPhone přes AirDrop nebo iCloud Drive)
AltStore app nainstaluje


ČÁST 6 — Automatické obnovování

Na Macu: AltServer ikonka → Enable Background Refresh
Na iPhonu v AltStore: Nastavení → zapni Background App Refresh
Hotovo — dokud jsou Mac a iPhone ve stejné WiFi, obnova běží automaticky


Jedna věc navíc — před buildem doporučuji otestovat jestli JS injekce a CSS fungují správně na iOS WebView, protože Safari engine se chová trochu jinak než Android. Ale to řešíme až budeš mít build na iPhonu.