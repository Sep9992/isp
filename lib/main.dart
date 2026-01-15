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
      title: 'ISP',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue, brightness: Brightness.light),
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const IspWebScreen(),
    );
  }
}

class IspWebScreen extends StatefulWidget {
  const IspWebScreen({super.key});

  @override
  State<IspWebScreen> createState() => _IspWebScreenState();
}

class _IspWebScreenState extends State<IspWebScreen> {
  late final WebViewController controller;
  bool isLoading = true;
  bool isLoginPage = true;

  String currentTitle = "Jídelníček";
  String currentIconPath = "assets/icons/jidelnicek.png";
  String userName = "Uživatel"; 

  @override
  void initState() {
    super.initState();
    
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..addJavaScriptChannel(
        'IspChannel', 
        onMessageReceived: (JavaScriptMessage message) {
          String rawText = message.message;
          if (rawText.isEmpty || rawText == "Uživatel") return;

          String cleanName = rawText;
          if (cleanName.contains('-') && cleanName.contains('unid')) {
             var parts = cleanName.split('-');
             if (parts.length > 1) cleanName = parts.last.trim();
          }

          if (cleanName.length > 2 && cleanName != userName) {
             setState(() { userName = cleanName; });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) => setState(() => isLoading = true),
          onPageFinished: (String url) async {
            bool currentIsLogin = url.contains("login.htm");

            String newTitle = currentTitle;
            String newIcon = currentIconPath;

            if (url.contains("cateringmenu.htm")) {
              newTitle = "Jídelníček";
              newIcon = "assets/icons/jidelnicek.png";
            } else if (url.contains("cateringorders.htm")) {
              newTitle = "Objednávky";
              newIcon = "assets/icons/objednavky.png";
            } else if (url.contains("cateringexchange.htm")) {
              newTitle = "Burza jídel";
              newIcon = "assets/icons/burza.png";
            } else if (url.contains("cateringoperations.htm")) {
              newTitle = "Historie účtu";
              newIcon = "assets/icons/historie_uctu.png";
            } else if (url.contains("cateringmenuprint.htm")) {
              newTitle = "Tisk jídelníčku";
              newIcon = "assets/icons/tisk_jidelnicku.png";
            } else if (url.contains("profile.htm") || url.contains("cateringsettings.htm")) {
              newTitle = "Nastavení";
              newIcon = ""; 
            }

            _applyAllFixes();
            
            await Future.delayed(const Duration(milliseconds: 400));

            if (mounted) {
              setState(() {
                isLoading = false;
                isLoginPage = currentIsLogin;
                if (isLoginPage) {
                   currentTitle = "Jídelníček";
                   currentIconPath = "assets/icons/jidelnicek.png";
                   userName = "Uživatel"; 
                } else {
                   currentTitle = newTitle;
                   currentIconPath = newIcon;
                }
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse('https://isp.mlsoft.cz/web/login.htm'));
  }

  void loadPage(String url, String newTitle, String newIconPath) {
    setState(() {
      currentTitle = newTitle;
      currentIconPath = newIconPath;
    });
    controller.loadRequest(Uri.parse(url));
    Navigator.pop(context); 
  }

  void _applyAllFixes() {
    controller.runJavaScript("""
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
      `;
      document.head.appendChild(style);

      window.fetchHistoryAndCount = function() {
          if (window.ispFetchInProgress) return;
          window.ispFetchInProgress = true;

          fetch('cateringoperations.htm')
              .then(response => response.text())
              .then(html => {
                  var parser = new DOMParser();
                  var doc = parser.parseFromString(html, "text/html");
                  var uniqueDays = new Set();
                  
                  var rows = doc.querySelectorAll('tr');
                  rows.forEach(function(row) {
                      var text = row.innerText;
                      if (text.match(/\\d{1,2}\\.\\d{1,2}\\.\\d{4}/)) {
                          if (text.includes('Objednávka') || (text.includes('Kč') && text.includes('-'))) {
                              var match = text.match(/(\\d{1,2}\\.\\d{1,2}\\.\\d{4})/);
                              if(match) uniqueDays.add(match[1]);
                          }
                      }
                  });
                  
                  var count = uniqueDays.size;
                  localStorage.setItem('isp_cached_days', count);
                  window.ispFetchInProgress = false;
              })
              .catch(err => {
                  console.log("Chyba při načítání historie: " + err);
                  window.ispFetchInProgress = false;
              });
      };

      setInterval(function() {
          document.querySelectorAll('table').forEach(t => t.style.width = '100%');
          document.querySelectorAll('fieldset').forEach(fs => { fs.style.width='100%'; fs.style.border='none'; fs.style.padding='0'; fs.style.margin='0'; });
          var menuLinks = document.querySelectorAll('a[href*="cateringorders.htm"]');
          menuLinks.forEach(l => { var p = l.closest('td'); if(p) p.style.display='none'; });
          var annoying = document.querySelectorAll('.fa-cog, img[src*="logout"]');
          annoying.forEach(el => el.style.display = 'none');
          
          var headerLinks = document.querySelectorAll('.content-header a');
          headerLinks.forEach(function(link) {
              if (link.getAttribute('href') && link.getAttribute('href').includes('showMess')) link.style.display = 'none';
              if (link.innerText && link.innerText.includes('Laufen')) link.style.display = 'none';
          });

          var userDiv = document.getElementById('pageHeaderUser');
          if (userDiv) {
              var nameText = userDiv.innerText.trim();
              if (nameText.length > 1) { IspChannel.postMessage(nameText); }
          }
          
          var balanceEl = document.getElementById('pageHeaderCredit');
          if (!balanceEl) {
              var divs = document.querySelectorAll('.header div');
              for (var i=0; i<divs.length; i++) {
                 if (divs[i].innerText.includes('Kč') && !divs[i].innerText.includes('Limit') && !divs[i].id.includes('User')) {
                     balanceEl = divs[i];
                     break;
                 }
              }
          }

          if (balanceEl) {
              if (!balanceEl.getAttribute('data-orig-balance')) {
                   var rawVal = balanceEl.innerText.replace(/\\s/g, '').replace('Kč', '').replace(',', '.');
                   var rawClean = rawVal.replace(/[^0-9.-]/g, '');
                   var parsedVal = parseFloat(rawClean);
                   if (!isNaN(parsedVal)) {
                       balanceEl.setAttribute('data-orig-balance', parsedVal);
                   }
              }

              if (balanceEl.getAttribute('data-orig-balance')) {
                  var currentBalance = parseFloat(balanceEl.getAttribute('data-orig-balance'));
                  
                  var daysCount = 0;
                  var isHistoryPage = window.location.href.includes('cateringoperations.htm');
                  
                  if (isHistoryPage) {
                      var uniqueDays = new Set();
                      var rows = document.querySelectorAll('tr');
                      rows.forEach(function(row) {
                          var text = row.innerText;
                          if (text.match(/\\d{1,2}\\.\\d{1,2}\\.\\d{4}/)) {
                              if (text.includes('Objednávka') || (text.includes('Kč') && text.includes('-'))) {
                                  var match = text.match(/(\\d{1,2}\\.\\d{1,2}\\.\\d{4})/);
                                  if (match) uniqueDays.add(match[1]);
                              }
                          }
                      });
                      daysCount = uniqueDays.size;
                      localStorage.setItem('isp_cached_days', daysCount);
                  } else {
                      var cached = localStorage.getItem('isp_cached_days');
                      if (cached) {
                          daysCount = parseInt(cached);
                      } else {
                          window.fetchHistoryAndCount();
                          daysCount = 0;
                      }
                  }

                  if (daysCount > 0) {
                      var limitPerLunch = 129.50;
                      var theoretical = daysCount * limitPerLunch;
                      var actualSpending = Math.abs(currentBalance); 
                      var diff = theoretical - actualSpending;

                      var color = (diff >= 0) ? '#4CAF50' : '#FF5252'; 
                      var diffFormatted = Math.abs(diff).toFixed(2).replace('.', ',');
                      var label = (diff >= 0) ? 'Limit ' : 'Limit ';
                      
                      var newHtml = '<span style="color: ' + color + '; font-weight: bold; font-size: 14px; padding-right: 10px;">' + label + diffFormatted + ' Kč</span>';
                      
                      if (balanceEl.innerHTML !== newHtml) {
                          balanceEl.innerHTML = newHtml;
                      }
                  }
              }
          }

      }, 500);
    """);
  }

  Future<void> _handleLogout() async {
      final WebViewCookieManager cookieManager = WebViewCookieManager();
      await cookieManager.clearCookies();
      await controller.clearCache();
      if (mounted) {
        Navigator.pop(context); 
        setState(() { currentTitle = "Jídelníček"; userName = "Uživatel"; });
        controller.loadRequest(Uri.parse('https://isp.mlsoft.cz/web/login.htm'));
      }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: isLoginPage 
          ? null 
          : AppBar(
              title: Row(
                children: [
                  if (currentIconPath.isNotEmpty)
                    Image.asset(currentIconPath, width: 24, height: 24, color: Colors.white)
                  else
                    const Icon(Icons.settings, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(currentTitle),
                ],
              ),
              backgroundColor: Colors.blue, 
              foregroundColor: Colors.white,
            ),
      drawer: isLoginPage ? null : Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_circle, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: Text(
                      userName, 
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(leading: Image.asset('assets/icons/jidelnicek.png', width: 30), title: const Text('Jídelníček'), onTap: () => loadPage('https://isp.mlsoft.cz/web/cateringmenu.htm', 'Jídelníček', 'assets/icons/jidelnicek.png')),
            ListTile(leading: Image.asset('assets/icons/objednavky.png', width: 30), title: const Text('Objednávky'), onTap: () => loadPage('https://isp.mlsoft.cz/web/cateringorders.htm', 'Objednávky', 'assets/icons/objednavky.png')),
            ListTile(leading: Image.asset('assets/icons/burza.png', width: 30), title: const Text('Burza jídel'), onTap: () => loadPage('https://isp.mlsoft.cz/web/cateringexchange.htm', 'Burza jídel', 'assets/icons/burza.png')),
            ListTile(leading: Image.asset('assets/icons/historie_uctu.png', width: 30), title: const Text('Historie účtu'), onTap: () => loadPage('https://isp.mlsoft.cz/web/cateringoperations.htm', 'Historie účtu', 'assets/icons/historie_uctu.png')),
            ListTile(leading: Image.asset('assets/icons/tisk_jidelnicku.png', width: 30), title: const Text('Tisk jídelníčku'), onTap: () => loadPage('https://isp.mlsoft.cz/web/cateringmenuprint.htm', 'Tisk jídelníčku', 'assets/icons/tisk_jidelnicku.png')),
            ListTile(leading: const Icon(Icons.settings, color: Colors.grey), title: const Text('Nastavení'), onTap: () => loadPage('https://isp.mlsoft.cz/web/profile.htm', 'Nastavení', '')),
            const Divider(),
            ListTile(leading: const Icon(Icons.logout, color: Colors.red), title: const Text('Odhlásit se'), onTap: _handleLogout),
          ],
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: controller),
            if (isLoading) Container(color: Colors.white, child: const Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}