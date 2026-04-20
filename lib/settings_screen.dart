import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notifications.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notificationsEnabled = true;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 10, minute: 0);
  bool _loading = true;
  bool _testSent = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      final hour = prefs.getInt('notification_hour') ?? 10;
      final minute = prefs.getInt('notification_minute') ?? 0;
      _notificationTime = TimeOfDay(hour: hour, minute: minute);
      _loading = false;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _notificationsEnabled);
    await prefs.setInt('notification_hour', _notificationTime.hour);
    await prefs.setInt('notification_minute', _notificationTime.minute);
    // Přeplánujeme WorkManager task
    await NotificationService().scheduleDailyCheck();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _notificationTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1565C0),
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _notificationTime) {
      setState(() => _notificationTime = picked);
      await _saveSettings();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Čas notifikace nastaven na ${picked.format(context)}',
            ),
            backgroundColor: const Color(0xFF1565C0),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _sendTest() async {
    await NotificationService().sendTestNotification();
    setState(() => _testSent = true);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _testSent = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FF),
      appBar: AppBar(
        title: const Text('Nastavení'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Sekce: Notifikace ──────────────────────────────────────
          _sectionHeader('Notifikace'),
          _card([
            // Přepínač zapnout/vypnout
            SwitchListTile(
              title: const Text(
                'Denní připomenutí oběda',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Každý pracovní den dostaneš připomenutí s dnešním obědem',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              value: _notificationsEnabled,
              activeColor: const Color(0xFF1565C0),
              onChanged: (val) async {
                setState(() => _notificationsEnabled = val);
                await _saveSettings();
              },
            ),

            if (_notificationsEnabled) ...[
              const Divider(height: 1, indent: 16, endIndent: 16),

              // Výběr času
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF1565C0),
                    size: 22,
                  ),
                ),
                title: const Text(
                  'Čas notifikace',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                subtitle: Text(
                  _notificationTime.format(context),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1565C0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: _pickTime,
              ),

              const Divider(height: 1, indent: 16, endIndent: 16),

              // Co notifikace obsahuje
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Notifikace obsahuje:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _infoRow('🍽️', 'Dnešní objednané jídlo'),
                    _infoRow('⚠️', 'Upozornění pokud zítra (pondělí) nemáš objednáno'),
                  ],
                ),
              ),
            ],
          ]),

          const SizedBox(height: 16),

          // ── Sekce: Test ───────────────────────────────────────────
          if (_notificationsEnabled) ...[
            _sectionHeader('Test'),
            _card([
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _testSent
                        ? Colors.green.withValues(alpha: 0.1)
                        : const Color(0xFF1565C0).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    _testSent
                        ? Icons.check_circle_rounded
                        : Icons.notifications_rounded,
                    color: _testSent ? Colors.green : const Color(0xFF1565C0),
                    size: 22,
                  ),
                ),
                title: Text(
                  _testSent ? 'Notifikace odeslána!' : 'Odeslat testovací notifikaci',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: _testSent ? Colors.green : Colors.black87,
                  ),
                ),
                subtitle: const Text(
                  'Ověří že notifikace fungují správně',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                onTap: _testSent ? null : _sendTest,
              ),
            ]),
            const SizedBox(height: 16),
          ],

          // ── Sekce: O aplikaci ─────────────────────────────────────
          _sectionHeader('O aplikaci'),
          _card([
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF1565C0).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.restaurant_rounded,
                  color: Color(0xFF1565C0),
                  size: 22,
                ),
              ),
              title: const Text(
                'ISP Obědy',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              subtitle: const Text(
                'Verze 1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1565C0),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _card(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}