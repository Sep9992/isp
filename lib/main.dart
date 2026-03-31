import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  runApp(const IspApp());
}

class IspApp extends StatelessWidget {
  const IspApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ISP Obědy',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: const Color(0xFF1565C0).withValues(alpha: 0.12),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1565C0),
              );
            }
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: Colors.grey,
            );
          }),
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFF1565C0), size: 24);
            }
            return const IconThemeData(color: Colors.grey, size: 24);
          }),
          elevation: 0,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1565C0),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      home: const IspWebScreen(),
    );
  }
}

// ─── Datový model pro záložky ────────────────────────────────────────────────

class NavTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String url;

  const NavTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.url,
  });
}

const List<NavTab> _tabs = [
  NavTab(
    label: 'Jídelníček',
    icon: Icons.restaurant_menu_outlined,
    selectedIcon: Icons.restaurant_menu,
    url: 'https://isp.mlsoft.cz/web/cateringmenu.htm',
  ),
  NavTab(
    label: 'Objednávky',
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart,
    url: 'https://isp.mlsoft.cz/web/cateringorders.htm',
  ),
  NavTab(
    label: 'Burza',
    icon: Icons.swap_horiz_outlined,
    selectedIcon: Icons.swap_horiz,
    url: 'https://isp.mlsoft.cz/web/cateringexchange.htm',
  ),
  NavTab(
    label: 'Historie',
    icon: Icons.history_outlined,
    selectedIcon: Icons.history,
    url: 'https://isp.mlsoft.cz/web/cateringoperations.htm',
  ),
  NavTab(
    label: 'Nastavení',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    url: 'https://isp.mlsoft.cz/web/profile.htm',
  ),
];

// ─── Hlavní obrazovka ────────────────────────────────────────────────────────

class IspWebScreen extends StatefulWidget {
  const IspWebScreen({super.key});

  @override
  State<IspWebScreen> createState() => _IspWebScreenState();
}

class _IspWebScreenState extends State<IspWebScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  bool isLoginPage = true;
  bool hasError = false;          // ← offline stav
  int _selectedIndex = 0;
  String userName = 'Uživatel';
  String _lastAttemptedUrl = 'https://isp.mlsoft.cz/web/login.htm';

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'IspChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final raw = message.message.trim();
          if (raw.isEmpty || raw == 'Uživatel') return;

          String clean = raw;
          if (clean.contains('-') && clean.contains('unid')) {
            final parts = clean.split('-');
            if (parts.length > 1) clean = parts.last.trim();
          }
          if (clean.length > 2 && clean != userName) {
            setState(() => userName = clean);
          }
        },
      )
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (String url) {
          setState(() {
            isLoading = true;
            hasError = false;   // ← reset chyby při každém novém načítání
          });
        },
        onPageFinished: (String url) async {
          final bool isLogin = url.contains('login.htm');

          // Synchronizace selectedIndex podle URL
          if (!isLogin) {
            for (int i = 0; i < _tabs.length; i++) {
              if (url.contains(Uri.parse(_tabs[i].url).path)) {
                if (_selectedIndex != i) setState(() => _selectedIndex = i);
                break;
              }
            }
          }

          _applyAllFixes();
          await Future.delayed(const Duration(milliseconds: 400));

          if (mounted) {
            setState(() {
              isLoading = false;
              isLoginPage = isLogin;
              if (isLogin) userName = 'Uživatel';
            });
          }
        },

        // ── Zachycení chyby (offline, DNS, timeout…) ──────────────────
        onWebResourceError: (WebResourceError error) {
          // Reagujeme pouze na chyby hlavního rámce (ne subresources)
          if (error.isForMainFrame == true) {
            if (mounted) {
              setState(() {
                isLoading = false;
                hasError = true;
              });
            }
          }
        },
      ))
      ..loadRequest(Uri.parse(_lastAttemptedUrl));
  }

  void _navigateToTab(int index) {
    if (_selectedIndex == index && !isLoading && !hasError) return;
    final url = _tabs[index].url;
    setState(() {
      _selectedIndex = index;
      _lastAttemptedUrl = url;
    });
    controller.loadRequest(Uri.parse(url));
  }

  // Znovu načte poslední URL (použije se z offline stránky)
  void _retry() {
    setState(() {
      hasError = false;
      isLoading = true;
    });
    controller.loadRequest(Uri.parse(_lastAttemptedUrl));
  }

  Future<void> _handleLogout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Odhlásit se?'),
        content: const Text('Opravdu se chceš odhlásit z aplikace?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Zrušit'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Odhlásit'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final WebViewCookieManager cookieManager = WebViewCookieManager();
    await cookieManager.clearCookies();
    await controller.clearCache();
    if (mounted) {
      setState(() {
        userName = 'Uživatel';
        _selectedIndex = 0;
        hasError = false;
        _lastAttemptedUrl = 'https://isp.mlsoft.cz/web/login.htm';
      });
      controller.loadRequest(Uri.parse('https://isp.mlsoft.cz/web/login.htm'));
    }
  }

  // ─── Offline widget ──────────────────────────────────────────────────────

  Widget _buildOfflinePage() {
    return Container(
      color: Colors.white,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.wifi_off_rounded,
                  size: 48,
                  color: Colors.grey[400],
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Bez připojení',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Nepodařilo se načíst stránku.\nZkontroluj připojení k internetu\na zkus to znovu.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Zkusit znovu'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  minimumSize: const Size(180, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _applyAllFixes() {
    controller.runJavaScript(r"""
      var style = document.createElement('style');
      style.innerHTML = `
        #sidebar, .sidebar, #left-col, .left-column, .left-col, #left-menu, .left-menu, 
        #menu, .menu, .nav, .navigation, #navigation, aside, .hidden-xs, .visible-lg 
        { display: none !important; }

        .header, #header, .top-bar {
            display: flex !important; flex-direction: row !important;
            align-items: center !important; justify-content: flex-end !important; 
            height: 50px !important; min-height: 50px !important;
            background-color: #000000 !important; color: #ffffff !important;
            width: 100% !important; padding: 0 10px !important; margin: 0 !important;
            overflow: hidden !important; z-index: 1000 !important;
        }
        .header > *, #header > *, .top-bar > *, .user-panel, #user-panel {
            display: flex !important; flex-direction: row !important;
            align-items: center !important; width: auto !important;
            margin: 0 5px !important; padding: 0 !important;
            float: none !important; background: transparent !important;
        }
        .header *, #header * {
            color: white !important; font-size: 14px !important;
            white-space: nowrap !important; line-height: 50px !important;
        }

        #pageHeaderLogoLabel, #pageHeaderLogoImg, .pageHeaderLogo, #pageHeaderSettings,
        .fa-user, .icon-user, .glyphicon-user { display: none !important; }
        .header img { display: none !important; }
        br { display: none !important; }

        * { box-sizing: border-box !important; }
        body, html { background: white !important; margin: 0 !important; padding: 0 !important; width: 100% !important; }
        #main, .main, #content, .content, .center-column {
            width: 100% !important; max-width: none !important;
            padding-top: 15px !important; padding-left: 10px !important; padding-right: 10px !important;
            background: transparent;
        }
        table { width: 100% !important; border-collapse: collapse !important; }
        
        a[href*="showMess"] { display: none !important; visibility: hidden !important; width: 0 !important; }
        .content-header .fa-home { display: none !important; }
        .content-header img { display: inline-block !important; visibility: visible !important; }

        .ui-dialog {
            position: fixed !important; top: 50% !important; left: 50% !important;
            transform: translate(-50%, -50%) !important;
            width: 92% !important; max-height: 90vh !important;
            background: white !important; padding: 0 !important;
            border: none !important; border-radius: 20px !important; 
            box-shadow: 0 10px 50px rgba(0,0,0,0.6) !important;
            overflow: hidden !important;
            display: flex !important; flex-direction: column !important;
            z-index: 999999 !important;
        }
        .ui-dialog-titlebar { padding: 15px !important; background: #2196F3 !important; color: white !important; border: none !important; }
        .ui-dialog-content { padding: 0 !important; background: white !important; width: 100% !important; overflow-y: auto !important; }
        .ui-dialog-content td { padding: 10px !important; border-bottom: 1px solid #eee !important; }
        .ui-dialog-content td:first-child { padding-left: 15px !important; width: 40px !important; }
        .ui-dialog-buttonpane { background: #f5f5f5 !important; padding: 15px !important; margin: 0 !important; border-top: 1px solid #ddd !important; }

        /* ═══════════════════════════════════════════
           JÍDELNÍČEK – KARTA STYL
           ═══════════════════════════════════════════ */

        /* Navigace datumem (šipky + datum) */
        .menuNavigation, .menuDateNav, [class*="menuNav"], [class*="dateNav"] {
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            gap: 16px !important;
            padding: 12px 16px !important;
            background: #f8f9ff !important;
            border-radius: 14px !important;
            margin: 8px 12px 16px 12px !important;
            border: 1px solid #e8eaf6 !important;
        }
        .menuNavigation a, .menuDateNav a, [class*="menuNav"] a {
            color: #1565C0 !important;
            font-size: 22px !important;
            text-decoration: none !important;
            font-weight: bold !important;
            padding: 0 8px !important;
        }
        .menuNavigation span, .menuDateNav span, [class*="menuNav"] span,
        .menuNavigation b, .menuDateNav b {
            font-size: 15px !important;
            font-weight: 700 !important;
            color: #1a237e !important;
            letter-spacing: 0.3px !important;
        }

        /* Wrapper celého menu gridu */
        .menuGrid, [class*="menuGrid"]:not([class*="menuGridRow"]):not([class*="menuGridCol"]) {
            padding: 4px 10px 16px 10px !important;
            background: transparent !important;
            display: flex !important;
            flex-direction: column !important;
            gap: 10px !important;
        }

        /* Jeden řádek = jedna karta jídla */
        .menuGridRow, .menuGridRowOrdered {
            background: #ffffff !important;
            border-radius: 16px !important;
            box-shadow: 0 2px 12px rgba(21, 101, 192, 0.10) !important;
            border: 1px solid #e8edf8 !important;
            overflow: hidden !important;
            margin: 0 !important;
            padding: 0 !important;
            display: flex !important;
            flex-direction: row !important;
            align-items: center !important;
        }

        /* Objednané – reset červené */
        .menuGridRowOrdered {
            background-color: #ffffff !important;
            border-color: #e8edf8 !important;
        }

        /* Levá část – název + kategorie + badge */
        .menuGridRow > div[style*="flex-grow"],
        .menuGridRowOrdered > div[style*="flex-grow"] {
            flex: 1 !important;
            min-width: 0 !important;
            padding: 10px 0 10px 0 !important;
        }

        /* Barevný levý akcent – odstraníme */
        .menuGridRowMeal {
            border: none !important;
            padding: 0 10px 0 10px !important;
            display: flex !important;
            flex-direction: column !important;
            gap: 4px !important;
            width: 100% !important;
            background: transparent !important;
        }

        /* Název jídla */
        .menuGridRowMeal a[onclick*="openDetail"],
        .menuGridRow a[onclick*="openDetail"],
        .menuGridRowOrdered a[onclick*="openDetail"] {
            color: #1a237e !important;
            font-size: 14px !important;
            font-weight: 600 !important;
            text-decoration: none !important;
            line-height: 1.4 !important;
            display: block !important;
        }

        /* Kategorie jídla */
        .menuGridRowCourse, .menuGridRowCond, [class*="menuGridRowCond"] {
            font-size: 10px !important;
            color: #90a4ae !important;
            font-weight: 500 !important;
            letter-spacing: 0.2px !important;
            padding: 0 10px !important;
            margin-top: 2px !important;
            text-transform: uppercase !important;
            display: flex !important;
            align-items: center !important;
            gap: 6px !important;
            flex-wrap: wrap !important;
        }

        /* Odznak Objednáno – inline vedle kategorie vpravo */
        .isp-ordered-badge {
            display: inline-block !important;
            background: #2E7D32 !important;
            color: white !important;
            font-size: 10px !important;
            font-weight: 700 !important;
            padding: 1px 7px !important;
            border-radius: 20px !important;
            white-space: nowrap !important;
            margin-left: auto !important;
        }

        /* Cena – vpravo */
        .menuGridRowPrice {
            background: #e3f2fd !important;
            color: #1565C0 !important;
            font-size: 12px !important;
            font-weight: 700 !important;
            padding: 4px 8px !important;
            border-radius: 20px !important;
            white-space: nowrap !important;
            flex-shrink: 0 !important;
            margin: 0 4px !important;
        }

        /* Tlačítka +/- – pod sebou pro objednané */
        .menuGridRowOrdered .menuGridRowButton {
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
            padding: 2px 4px !important;
            margin: 0 !important;
            flex-shrink: 0 !important;
        }

        /* Tlačítka +/- – vpravo */
        .menuGridRowButton {
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
            padding: 6px !important;
            margin: 0 !important;
            flex-shrink: 0 !important;
        }

        .menuGridRowButton img {
            width: 28px !important;
            height: 28px !important;
            opacity: 0.7 !important;
            cursor: pointer !important;
        }

        /* ═══════════════════════════════════════════
           NAVIGACE DATEM – contentHeader (čisté CSS)
           ═══════════════════════════════════════════ */

        .contentHeader {
            background: linear-gradient(135deg, #1565C0 0%, #1976D2 100%) !important;
            border-radius: 16px !important;
            margin: 10px 10px 14px 10px !important;
            padding: 4px 8px !important;
            box-shadow: 0 4px 14px rgba(21, 101, 192, 0.30) !important;
            display: flex !important;
            flex-direction: row !important;
            align-items: center !important;
            pointer-events: auto !important;
        }

        /* První div (šipky + datum) */
        .contentHeader > div:first-child {
            display: flex !important;
            flex-direction: row !important;
            align-items: center !important;
            flex: 1 !important;
            gap: 4px !important;
            pointer-events: auto !important;
        }

        /* Šipka vlevo */
        .contentHeader a[href*="part=prev"],
        .contentHeader a[href*="part=next"] {
            display: inline-flex !important;
            align-items: center !important;
            justify-content: center !important;
            width: 38px !important;
            height: 38px !important;
            background: rgba(255,255,255,0.22) !important;
            border-radius: 50% !important;
            color: white !important;
            font-size: 22px !important;
            font-weight: 300 !important;
            text-decoration: none !important;
            flex-shrink: 0 !important;
            pointer-events: auto !important;
        }

        /* Datum – span s odkazem */
        .contentHeader span {
            flex: 1 !important;
            text-align: center !important;
            pointer-events: auto !important;
        }

        .contentHeader span a {
            color: white !important;
            font-size: 15px !important;
            font-weight: 700 !important;
            text-decoration: none !important;
            white-space: nowrap !important;
            pointer-events: auto !important;
        }

        /* Ikonka kalendáře */
        .contentHeader img[onclick] {
            width: 20px !important;
            height: 20px !important;
            filter: brightness(10) !important;
            opacity: 0.85 !important;
            cursor: pointer !important;
            pointer-events: auto !important;
            vertical-align: middle !important;
        }

        /* ═══════════════════════════════════════════
           DATEPICKER – KALENDÁŘ POPUP
           ═══════════════════════════════════════════ */

        /* Tmavý overlay pozadí - pouze když je aktivní */
        #blanket {
            position: fixed !important;
            top: 0 !important; left: 0 !important;
            width: 100% !important; height: 100% !important;
            background: rgba(0,0,0,0.5) !important;
            z-index: 9998 !important;
        }

        /* Hlavní popup box */
        #datepicker,
        .datepicker,
        [id*="datepicker"],
        [class*="datepicker"] {
            position: fixed !important;
            top: 50% !important;
            left: 50% !important;
            transform: translate(-50%, -50%) !important;
            width: 88% !important;
            max-width: 340px !important;
            background: white !important;
            border-radius: 20px !important;
            box-shadow: 0 20px 60px rgba(0,0,0,0.35) !important;
            z-index: 9999 !important;
            padding: 0 !important;
            overflow: hidden !important;
            border: none !important;
        }

        /* Záhlaví s měsícem a rokem */
        #datepicker .datepicker-header,
        [id*="datepicker"] thead tr:first-child,
        [id*="datepicker"] .month-header,
        #calendarDiv .header,
        .datepicker thead tr:first-child td,
        .datepicker thead tr:first-child th {
            background: linear-gradient(135deg, #1565C0 0%, #1976D2 100%) !important;
            color: white !important;
            font-weight: 700 !important;
            font-size: 15px !important;
            padding: 16px !important;
            text-align: center !important;
            border: none !important;
        }

        /* Dny v týdnu (po, út, st…) */
        .datepicker thead tr:last-child th,
        [id*="datepicker"] thead tr:last-child th,
        [id*="datepicker"] thead tr:last-child td {
            background: #f0f4ff !important;
            color: #1565C0 !important;
            font-size: 12px !important;
            font-weight: 600 !important;
            padding: 8px 4px !important;
            text-align: center !important;
            border: none !important;
        }

        /* Buňky s čísly dnů */
        .datepicker tbody td,
        [id*="datepicker"] tbody td,
        [id*="datepicker"] td {
            text-align: center !important;
            padding: 6px 2px !important;
            font-size: 14px !important;
            border: none !important;
            border-radius: 0 !important;
            cursor: pointer !important;
        }

        /* Odkaz uvnitř buňky */
        .datepicker tbody td a,
        [id*="datepicker"] tbody td a,
        [id*="datepicker"] td a {
            display: inline-flex !important;
            align-items: center !important;
            justify-content: center !important;
            width: 34px !important;
            height: 34px !important;
            border-radius: 50% !important;
            font-size: 14px !important;
            text-decoration: none !important;
            color: #333 !important;
            font-weight: 500 !important;
        }

        /* Hover na den */
        .datepicker tbody td a:hover,
        [id*="datepicker"] td a:hover {
            background: #e3f2fd !important;
            color: #1565C0 !important;
        }

        /* Aktuální / vybraný den */
        .datepicker tbody td.selected a,
        .datepicker tbody td.today a,
        [id*="datepicker"] td.selected a,
        [id*="datepicker"] td.today a,
        [id*="datepicker"] td.active a {
            background: #1565C0 !important;
            color: white !important;
            font-weight: 700 !important;
        }

        /* Neaktivní dny (jiný měsíc) */
        .datepicker tbody td.disabled a,
        .datepicker tbody td.other-month a,
        [id*="datepicker"] td.disabled a,
        [id*="datepicker"] td.muted a {
            color: #ccc !important;
        }

        /* Tlačítko "Zavřít" */
        #datepicker .close-btn,
        [id*="datepicker"] .btn,
        [id*="datepicker"] button,
        .datepicker .footer button,
        .datepicker .footer a {
            display: block !important;
            width: calc(100% - 32px) !important;
            margin: 12px 16px !important;
            padding: 12px !important;
            background: #1565C0 !important;
            color: white !important;
            border: none !important;
            border-radius: 12px !important;
            font-size: 15px !important;
            font-weight: 600 !important;
            text-align: center !important;
            cursor: pointer !important;
            text-decoration: none !important;
        }

        /* Celková tabulka uvnitř datepickeru */
        [id*="datepicker"] table,
        .datepicker table {
            width: 100% !important;
            border-collapse: collapse !important;
            margin: 0 !important;
        }

        /* ═══════════════════════════════════════════
           OBJEDNÁVKOVÝ MODAL – prepareCompoundOrderModal
           ═══════════════════════════════════════════ */

        #prepareCompoundOrderModal .modal-dialog,
        #preOrderCountModal .modal-dialog {
            width: 94% !important;
            max-width: 420px !important;
            margin: 5vh auto !important;
        }

        #prepareCompoundOrderModal .modal-content,
        #preOrderCountModal .modal-content {
            border-radius: 20px !important;
            border: none !important;
            box-shadow: 0 20px 60px rgba(0,0,0,0.35) !important;
            overflow: hidden !important;
        }

        #prepareCompoundOrderModal .modal-footer,
        #preOrderCountModal .modal-footer {
            display: flex !important;
            gap: 10px !important;
            padding: 12px 16px !important;
            background: white !important;
            border-top: 1px solid #e8edf8 !important;
        }

        #prepareCompoundOrderModal .modal-footer .btn,
        #preOrderCountModal .modal-footer .btn {
            flex: 1 !important;
            padding: 12px !important;
            border-radius: 12px !important;
            font-size: 15px !important;
            font-weight: 600 !important;
            border: none !important;
        }

        #prepareCompoundOrderModal .modal-footer .btn:first-child,
        #preOrderCountModal .modal-footer .btn:first-child {
            background: #1565C0 !important;
            color: white !important;
        }

        #prepareCompoundOrderModal .modal-footer .btn:last-child,
        #preOrderCountModal .modal-footer .btn:last-child {
            background: #f5f5f5 !important;
            color: #666 !important;
        }

        /* Vnitřní div – odstraníme původní margin */
        #prepareCompoundOrderModalBody > div {
            margin: 0 !important;
            padding: 8px !important;
            box-sizing: border-box !important;
            width: 100% !important;
        }

        /* Název jídla .mealName – modrý rámeček */
        #prepareCompoundOrderModalBody .mealName {
            background: linear-gradient(135deg, #1565C0 0%, #1976D2 100%) !important;
            color: white !important;
            margin: 0 0 10px 0 !important;
            padding: 12px 14px !important;
            font-size: 14px !important;
            font-weight: 700 !important;
            border-radius: 14px !important;
            display: block !important;
            width: 100% !important;
            box-sizing: border-box !important;
        }

        /* Radio button */
        #prepareCompoundOrderModalBody input[type="radio"] {
            width: 18px !important;
            height: 18px !important;
            accent-color: #1565C0 !important;
            vertical-align: middle !important;
            margin-right: 6px !important;
        }

        #prepareCompoundOrderModalBody label {
            font-size: 14px !important;
            font-weight: 600 !important;
            color: #1a237e !important;
            vertical-align: middle !important;
        }

        /* Tabulka #baseTable – zaoblený rámeček */
        #prepareCompoundOrderModalBody #baseTable {
            width: 100% !important;
            margin: 10px 0 0 0 !important;
            border-collapse: separate !important;
            border-spacing: 0 !important;
            border-radius: 14px !important;
            overflow: hidden !important;
            box-shadow: 0 2px 8px rgba(21,101,192,0.10) !important;
            border: 1px solid #e8edf8 !important;
            box-sizing: border-box !important;
            table-layout: fixed !important;
        }

        /* Skryjeme sloupec Alternativa – příliš málo místa */
        #prepareCompoundOrderModalBody #baseTable th:nth-child(3),
        #prepareCompoundOrderModalBody #baseTable td:nth-child(3) {
            display: none !important;
        }

        /* Záhlaví – th */
        #prepareCompoundOrderModalBody #baseTable th {
            background: #e8f0fe !important;
            color: #1565C0 !important;
            font-size: 10px !important;
            font-weight: 700 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.3px !important;
            padding: 8px 4px !important;
            border: none !important;
            border-bottom: 2px solid #c5d8fb !important;
            overflow: hidden !important;
            text-overflow: ellipsis !important;
            white-space: nowrap !important;
        }

        /* Šířky sloupců */
        #prepareCompoundOrderModalBody #baseTable th:nth-child(1),
        #prepareCompoundOrderModalBody #baseTable td:nth-child(1) { width: 36px !important; }
        #prepareCompoundOrderModalBody #baseTable th:nth-child(2),
        #prepareCompoundOrderModalBody #baseTable td:nth-child(2) { width: 50px !important; }
        #prepareCompoundOrderModalBody #baseTable th:nth-child(4),
        #prepareCompoundOrderModalBody #baseTable td:nth-child(4) { width: auto !important; }
        #prepareCompoundOrderModalBody #baseTable th:nth-child(5),
        #prepareCompoundOrderModalBody #baseTable td:nth-child(5) { width: 65px !important; }

        /* Řádky */
        #prepareCompoundOrderModalBody #baseTable td {
            padding: 8px 4px !important;
            border: none !important;
            border-bottom: 1px solid #f0f4ff !important;
            font-size: 11px !important;
            vertical-align: middle !important;
            color: #333 !important;
            overflow: hidden !important;
            word-break: break-word !important;
        }

        #prepareCompoundOrderModalBody #baseTable tr:last-child td {
            border-bottom: none !important;
        }

        #prepareCompoundOrderModalBody #baseTable tr:nth-child(even) td {
            background: #f8f9ff !important;
        }

        /* Checkbox */
        #prepareCompoundOrderModalBody input[type="checkbox"] {
            width: 18px !important;
            height: 18px !important;
            accent-color: #1565C0 !important;
        }

        /* Cena vpravo */
        #prepareCompoundOrderModalBody #baseTable td.r {
            text-align: right !important;
            font-weight: 700 !important;
            color: #1565C0 !important;
            white-space: nowrap !important;
            font-size: 11px !important;
        }

        #calendarModal .modal-dialog {
            width: 94% !important;
            max-width: 420px !important;
            margin: 5vh auto !important;
        }

        #calendarModal .modal-content {
            border-radius: 20px !important;
            border: none !important;
            box-shadow: 0 20px 60px rgba(0,0,0,0.35) !important;
            overflow: hidden !important;
        }

        #calendarModal .modal-body {
            padding: 12px 8px !important;
            background: #f8f9ff !important;
            display: block !important;
        }

        #calendarModal .modal-footer {
            padding: 10px 16px !important;
            background: white !important;
            border-top: 1px solid #e8edf8 !important;
        }

        #calendarModal .modal-footer .btn {
            background: #1565C0 !important;
            color: white !important;
            border: none !important;
            border-radius: 12px !important;
            padding: 10px 28px !important;
            font-size: 14px !important;
            font-weight: 600 !important;
            width: 100% !important;
        }

        /* Řádek týdne */
        .calendarRow {
            display: flex !important;
            flex-direction: row !important;
            gap: 4px !important;
            margin-bottom: 4px !important;
            justify-content: space-between !important;
        }

        /* Jeden den */
        .calendarDayContaner {
            flex: 1 !important;
            display: flex !important;
            flex-direction: column !important;
            align-items: center !important;
            justify-content: center !important;
            border-radius: 12px !important;
            padding: 6px 2px !important;
            background: white !important;
            box-shadow: 0 1px 4px rgba(0,0,0,0.08) !important;
            cursor: pointer !important;
            min-width: 0 !important;
            border: 2px solid transparent !important;
        }

        /* Den s objednávkou */
        .calendarDayHasOrder {
            background: #e3f2fd !important;
            border-color: #1565C0 !important;
        }

        /* Neaktivní den */
        .calendarDayDisabled {
            background: #f5f5f5 !important;
            opacity: 0.5 !important;
            cursor: default !important;
            box-shadow: none !important;
        }

        /* Název dne (Po, Út…) a měsíc */
        .calendarDaySmall {
            font-size: 10px !important;
            color: #90a4ae !important;
            font-weight: 600 !important;
            text-transform: uppercase !important;
            letter-spacing: 0.3px !important;
            line-height: 1.2 !important;
            overflow: hidden !important;
            white-space: nowrap !important;
            max-width: 100% !important;
            text-overflow: clip !important;
        }

        .calendarDayHasOrder .calendarDaySmall {
            color: #1565C0 !important;
        }

        /* Číslo dne */
        .calendarDayBig {
            font-size: 18px !important;
            font-weight: 700 !important;
            color: #1a237e !important;
            line-height: 1.2 !important;
            height: auto !important;
            padding-top: 2px !important;
        }

        .calendarDayDisabled .calendarDayBig {
            color: #aaa !important;
            font-weight: 400 !important;
        }
      `;
      document.head.appendChild(style);

      // Globální funkce pro otevření kalendáře - záloha
      window.ispOpenCalendar = function() {
          if (typeof showCalendar === 'function') showCalendar();
      };

      setTimeout(function() {
          // Skryjeme druhý div (showMess) v contentHeader
          var header = document.querySelector('.contentHeader');
          if (!header) return;
          var divs = header.querySelectorAll(':scope > div');
          if (divs.length > 1) divs[1].style.cssText = 'display:none!important';
          // Šipky – nahradíme obsah <a> za unicode znaky
          var prev = header.querySelector('a[href*="part=prev"]');
          var next = header.querySelector('a[href*="part=next"]');
          if (prev) prev.innerHTML = '&#8249;';
          if (next) next.innerHTML = '&#8250;';
          // Skryjeme ikonu šipky-obrázek (ne kalendář)
          var imgs = header.querySelectorAll('img:not([onclick])');
          imgs.forEach(function(img) { img.style.display = 'none'; });
      }, 500);

      // ── Výpočet a zobrazení limitu místo #money ──────────────────────
      function renderLimit(daysCount, totalSpent) {
          var moneyEl = document.getElementById('money');
          if (!moneyEl) return;
          var limitPerDay = 129.50;
          var entitlement = daysCount * limitPerDay;
          var remaining = entitlement - totalSpent;
          var isPositive = remaining >= 0;
          var color   = isPositive ? '#2E7D32' : '#C62828';
          var bgColor = isPositive ? '#E8F5E9' : '#FFEBEE';
          var sign    = isPositive ? '+' : '-';
          var formatted = Math.abs(remaining).toFixed(2).replace('.', ',') + '\u00a0K\u010d';
          moneyEl.innerHTML =
              '<span title="' + daysCount + ' dn\u00ed \u00d7 129,50 - ' + totalSpent.toFixed(2).replace('.', ',') + ' K\u010d" ' +
              'style="background:' + bgColor + ';color:' + color + ';font-weight:700;' +
              'font-size:13px;padding:3px 10px;border-radius:20px;white-space:nowrap;">' +
              sign + '\u00a0' + formatted + '</span>';
          moneyEl.setAttribute('data-limit-done', '1');
      }

      function updateLimitDisplay() {
          var moneyEl = document.getElementById('money');
          if (!moneyEl || moneyEl.getAttribute('data-limit-done')) return;

          var now = new Date();
          var currentMonth = now.getMonth() + 1;
          var currentYear  = now.getFullYear();
          var currentMonthYear = currentMonth + '.' + currentYear;
          var today = now.toDateString();

          // Okamžitě zobrazíme z cache pokud je z dnešního dne
          var cachedDay   = localStorage.getItem('isp_cached_day');
          var cachedDays  = parseInt(localStorage.getItem('isp_cached_days') || '0');
          var cachedSpent = parseFloat(localStorage.getItem('isp_cached_spent') || '0');
          var cachedMonth = localStorage.getItem('isp_cached_month');

          if (cachedDay === today && cachedMonth === currentMonthYear && cachedDays > 0) {
              renderLimit(cachedDays, cachedSpent);
              return; // Cache čerstvá, není třeba fetchovat
          }

          // Fetchujeme historii
          fetch('cateringoperations.htm')
              .then(function(r) { return r.text(); })
              .then(function(html) {
                  var parser = new DOMParser();
                  var doc = parser.parseFromString(html, 'text/html');
                  var totalSpent = 0;
                  var orderedDays = new Set();

                  doc.querySelectorAll('tr').forEach(function(row) {
                      var tds = row.querySelectorAll('td');
                      if (tds.length < 4) return;
                      var dateText  = tds[1].innerText.trim();
                      var dateMatch = dateText.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/);
                      if (!dateMatch) return;
                      if (parseInt(dateMatch[2]) !== currentMonth || parseInt(dateMatch[3]) !== currentYear) return;
                      var amountText  = tds[3] ? tds[3].innerText.trim() : '';
                      var amountMatch = amountText.match(/(-?\d+[\s,.]?\d*)/);
                      if (!amountMatch) return;
                      var amount   = parseFloat(amountMatch[1].replace(',', '.').replace(/\s/g, ''));
                      var typeText = tds[2] ? tds[2].innerText.trim() : '';
                      if (amount < 0 && typeText.includes('Objednávka')) {
                          totalSpent += Math.abs(amount);
                          orderedDays.add(dateMatch[1] + '.' + dateMatch[2] + '.' + dateMatch[3]);
                      }
                  });

                  var daysCount = orderedDays.size;
                  // Uložíme do cache s dnešním datem
                  localStorage.setItem('isp_cached_days', daysCount);
                  localStorage.setItem('isp_cached_spent', totalSpent.toFixed(2));
                  localStorage.setItem('isp_cached_month', currentMonthYear);
                  localStorage.setItem('isp_cached_day', today);

                  renderLimit(daysCount, totalSpent);
              })
              .catch(function() {});
      }

      setTimeout(updateLimitDisplay, 100);
      function addOrderedBadges() {
          document.querySelectorAll('.menuGridRowOrdered').forEach(function(row) {
              // Odstraníme červené inline styly
              row.style.removeProperty('background-color');
              row.style.removeProperty('border-color');
              row.style.backgroundColor = '#ffffff';
              row.style.borderColor = '#e8edf8';

              // Seskupíme tlačítka do sloupce
              var buttons = row.querySelectorAll('.menuGridRowButton');
              if (buttons.length >= 2 && !row.querySelector('.isp-btn-col')) {
                  var col = document.createElement('div');
                  col.className = 'isp-btn-col';
                  col.style.cssText = 'display:flex;flex-direction:column;align-items:center;justify-content:center;flex-shrink:0;';
                  buttons[0].parentNode.insertBefore(col, buttons[0]);
                  buttons.forEach(function(btn) { col.appendChild(btn); });
              }

              // Badge vpravo vedle kategorie
              if (!row.querySelector('.isp-ordered-badge')) {
                  var badge = document.createElement('span');
                  badge.className = 'isp-ordered-badge';
                  badge.innerText = '✓ Objednáno';
                  var course = row.querySelector('.menuGridRowCourse');
                  if (course) course.appendChild(badge);
              }
          });
      }

      // Spustíme po načtení stránky
      setTimeout(addOrderedBadges, 600);
      setTimeout(addOrderedBadges, 1500);

      // Zkrácení názvů měsíců v kalendáři na 3 písmena
      function shortenCalendarMonths() {
          document.querySelectorAll('#calendarModal .calendarDaySmall').forEach(function(el) {
              var text = el.innerText.trim();
              // Zkrátíme jen pokud je to název měsíce (více než 3 znaky a není to den)
              if (text.length > 3 && !['po','út','st','čt','pá','so','ne'].includes(text.toLowerCase())) {
                  el.innerText = text.substring(0, 3);
              }
          });
      }

      // Spustíme po otevření kalendáře
      var origShowCalendar = window.showCalendar;
      window.showCalendar = function() {
          if (origShowCalendar) origShowCalendar();
          setTimeout(shortenCalendarMonths, 600);
      };

      function getCurrentMonthYear() {
          var now = new Date();
          return (now.getMonth() + 1) + "." + now.getFullYear();
      }

      window.fetchHistoryAndCount = function() {
          if (window.ispFetchInProgress) return;
          window.ispFetchInProgress = true;
          fetch('cateringoperations.htm')
              .then(response => response.text())
              .then(html => {
                  var parser = new DOMParser();
                  var doc = parser.parseFromString(html, "text/html");
                  var uniqueDays = new Set();
                  var currentMonthYear = getCurrentMonthYear();
                  var rows = doc.querySelectorAll('tr');
                  rows.forEach(function(row) {
                      var text = row.innerText;
                      var match = text.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/);
                      if (match) {
                          var dayMonthYear = parseInt(match[2]) + "." + match[3];
                          if (dayMonthYear === currentMonthYear) {
                              if (text.includes('Objednávka') || (text.includes('Kč') && text.includes('-'))) {
                                  uniqueDays.add(match[1] + "." + match[2] + "." + match[3]);
                              }
                          }
                      }
                  });
                  var count = uniqueDays.size;
                  localStorage.setItem('isp_cached_days', count);
                  localStorage.setItem('isp_cached_month', currentMonthYear);
                  window.ispFetchInProgress = false;
              })
              .catch(err => { window.ispFetchInProgress = false; });
      };

      setInterval(function() {
          document.querySelectorAll('table').forEach(t => t.style.width = '100%');
          
          var balanceEl = null;
          var allTDs = document.querySelectorAll('td, span, div');
          for (var i = 0; i < allTDs.length; i++) {
              if (allTDs[i].innerText && allTDs[i].innerText.includes('Zůstatek:')) {
                  balanceEl = allTDs[i];
                  break;
              }
          }

          if (balanceEl) {
              if (!balanceEl.getAttribute('data-orig-val')) {
                  balanceEl.setAttribute('data-orig-val', balanceEl.innerText);
              }
              var rawText = balanceEl.getAttribute('data-orig-val');
              var priceMatch = rawText.match(/(-?\d+[\s,.]?\d*)/);
              var currentBalance = priceMatch ? parseFloat(priceMatch[1].replace(',', '.').replace(/\s/g, '')) : 0;
              var currentMonthYear = getCurrentMonthYear();
              var daysCount = 0;
              var isHistoryPage = window.location.href.includes('cateringoperations.htm');

              if (isHistoryPage) {
                  var uniqueDays = new Set();
                  document.querySelectorAll('tr').forEach(function(row) {
                      var text = row.innerText;
                      var match = text.match(/(\d{1,2})\.(\d{1,2})\.(\d{4})/);
                      if (match) {
                          var rowMonthYear = parseInt(match[2]) + "." + match[3];
                          if (rowMonthYear === currentMonthYear) {
                              if (text.includes('Objednávka') || (text.includes('Kč') && text.includes('-'))) {
                                  uniqueDays.add(match[1] + "." + match[2] + "." + match[3]);
                              }
                          }
                      }
                  });
                  daysCount = uniqueDays.size;
                  localStorage.setItem('isp_cached_days', daysCount);
                  localStorage.setItem('isp_cached_month', currentMonthYear);
              } else {
                  if (localStorage.getItem('isp_cached_month') === currentMonthYear) {
                      daysCount = parseInt(localStorage.getItem('isp_cached_days') || "0");
                  } else {
                      window.fetchHistoryAndCount();
                  }
              }

              var limitPerLunch = 129.50;
              var totalClaim = daysCount * limitPerLunch;
              var spent = Math.abs(currentBalance);
              var remaining = totalClaim - spent;
              var color = (remaining >= 0) ? '#4CAF50' : '#FF5252';
              var formatted = Math.abs(remaining).toFixed(2).replace('.', ',') + ' Kč';
              balanceEl.innerHTML = '<span style="color: ' + color + '; font-weight: bold;">Limit: ' + (remaining < 0 ? '-' : '') + formatted + '</span>';
          }
      }, 500);
    """);
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // ── AppBar ─────────────────────────────────────────────────────────
      appBar: isLoginPage
          ? null
          : AppBar(
              title: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _tabs[_selectedIndex].selectedIcon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(_tabs[_selectedIndex].label),
                ],
              ),
              actions: [
                if (userName != 'Uživatel')
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Center(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.logout_rounded),
                  tooltip: 'Odhlásit se',
                  onPressed: _handleLogout,
                ),
              ],
            ),

      // ── Bottom Navigation Bar ──────────────────────────────────────────
      bottomNavigationBar: isLoginPage
          ? null
          : Container(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: NavigationBar(
                selectedIndex: _selectedIndex,
                onDestinationSelected: _navigateToTab,
                animationDuration: const Duration(milliseconds: 300),
                destinations: _tabs
                    .map(
                      (tab) => NavigationDestination(
                        icon: Icon(tab.icon),
                        selectedIcon: Icon(tab.selectedIcon),
                        label: tab.label,
                      ),
                    )
                    .toList(),
              ),
            ),

      // ── Tělo ──────────────────────────────────────────────────────────
      body: SafeArea(
        child: Stack(
          children: [
            // WebView je vždy v DOM (zachovává stav stránky)
            WebViewWidget(controller: controller),

            // Offline stránka překryje WebView při chybě
            if (hasError) _buildOfflinePage(),

            // Loading overlay (nezobrazuje se zároveň s offline stránkou)
            if (isLoading && !hasError)
              Container(
                color: Colors.white,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        color: Color(0xFF1565C0),
                        strokeWidth: 3,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Načítám…',
                        style: TextStyle(
                          color: Color(0xFF1565C0),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}