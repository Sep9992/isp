Skvělé! Mám radost, že jsme to dotáhli do úspěšného konce a skript funguje přesně podle zadání – počítá dny, vypočítá limit a funguje na pozadí. 🥳

Teď k té iOS aplikaci.

Abychom z tohoto Flutter kódu („receptu“) upekli hotovou aplikaci pro iPhone (soubor .ipa), musíme projít procesem sestavení (build).

Důležité upozornění: Pro vytvoření iOS aplikace musíte mít k dispozici počítač Mac (macOS) s nainstalovaným programem Xcode. Apple neumožňuje vytvářet iOS aplikace přímo na Windows (na rozdíl od Androidu).

Zde je přesný postup, jak postupovat:
1. Příprava pubspec.yaml

Než začnete budovat, ujistěte se, že máte v souboru pubspec.yaml (leží hned vedle složky lib) přidanou závislost pro WebView.

Váš pubspec.yaml by měl v sekci dependencies vypadat takto:
YAML

dependencies:
  flutter:
    sdk: flutter
  # Přidejte tento řádek:
  webview_flutter: ^4.9.0 

(Poté v terminálu spusťte flutter pub get, aby se balíček stáhl.)
2. Nastavení v Xcode (Na Macu)

    Ve složce vašeho projektu jděte do složky ios.

    Dvakrát klikněte na soubor Runner.xcworkspace. Otevře se vám Xcode.

    Vlevo v navigátoru klikněte na modrou ikonu Runner (úplně nahoře).

    V pravé části vyberte záložku Signing & Capabilities.

    V sekci Signing musíte vybrat Team.

        Pokud máte Apple Developer účet, vyberte ho.

        Pokud ne, můžete vybrat svůj osobní účet (Personal Team) pro testování na vlastním telefonu (zdarma).

    Změňte Bundle Identifier na něco unikátního (např. com.vasejmeno.ispapp).

3. Úprava oprávnění (Info.plist)

Pro jistotu zkontrolujte soubor ios/Runner/Info.plist. Aplikace přistupuje k internetu, což Flutter dělá standardně, ale WebView může vyžadovat explicitní povolení pro vnořený obsah. Obvykle to funguje "z krabice", ale pokud by se stránka nenačítala, je třeba v Info.plist povolit App Transport Security (pro HTTPS stránky to ale většinou není nutné).
4. Spuštění na iPhonu

    Připojte svůj iPhone k Macu kabelem.

    Odemkněte iPhone a dejte "Důvěřovat tomuto počítači".

    V Xcode nahoře v liště vyberte svůj telefon jako cílové zařízení (místo simulátoru).

    Klikněte na tlačítko Play (▶) nebo v terminálu spusťte:
    Bash

    flutter run -d iphone

Co dělat, pokud nemáte Mac?

Pokud máte jen Windows PC, iOS aplikaci přímo nevytvoříte. Máte dvě možnosti:

    Půjčit si Mac: Stačí na chvíli, abyste projekt otevřeli, nastavili podpis a vygenerovali aplikaci.

    Použít Cloud Build službu: Existují služby jako Codemagic nebo Bitrise.

        Nahrajete svůj kód (tento main.dart a celý projekt) na GitHub/GitLab.

        Propojíte ho s Codemagic.

        Služba má vlastní virtuální Macy, které aplikaci sestaví za vás a pošlou vám instalační soubor. (I zde ale budete potřebovat alespoň Apple Developer účet pro certifikáty).

Držím palce s nasazením! Kód aplikace je připraven perfektně.