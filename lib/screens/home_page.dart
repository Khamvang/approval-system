// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/session.dart';
import 'admin_users_widget.dart';

String _apiHost() {
  return kIsWeb
      ? 'http://localhost:5000'
      : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
}

class HomePage extends StatefulWidget {
  final Map? user;
  final int? initialIndex;
  const HomePage({super.key, this.user, this.initialIndex});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  Timer? _inactivityTimer;
  int _timeoutMinutes = 30;
  String? _language;
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
    }
    _loadSettingsAndStartTimer();
  }

  @override
  void dispose() {
    _inactivityTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer(Duration(minutes: _timeoutMinutes), _handleAutoLogout);
  }

  void _resetTimer() {
    Session.updateLastActivity();
    _startTimer();
  }

  Future<void> _loadSettingsAndStartTimer() async {
    final t = await Session.getTimeoutMinutes();
    final lang = await Session.getLanguage();
    if (t != null && t > 0) _timeoutMinutes = t;
    _language = lang;
    if (mounted) setState(() {});
    _startTimer();
  }

  // language submenu handled by _showLanguageMenu

  Future<void> _chooseTimeout() async {
    final options = [1, 5, 15, 30];
    final selected = await showDialog<int?>(context: context, builder: (ctx) {
      return SimpleDialog(
        title: const Text('Session timeout (minutes)'),
        children: options.map((m) => SimpleDialogOption(child: Text('$m minutes'), onPressed: () => Navigator.pop(ctx, m))).toList(),
      );
    });
    if (selected != null) {
      await Session.setTimeoutMinutes(selected);
      _timeoutMinutes = selected;
      _startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Timeout set to $selected minutes')));
    }
  }

  Future<bool> _confirmLogout(String title) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: const Text('Are you sure?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes'))],
    ));
    return ok == true;
  }

  void _handleAutoLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text('Session expired. Redirecting...')))), (r) => false);
    // small delay to show message, then go to login
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  Future<void> _handleSwitchOrLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

  static const List<String> _titles = ['Overview', 'Approvals', 'Reports', 'Users'];

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Organization Overview', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(4, (i) {
              return SizedBox(
                width: 260,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Card ${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        const Text('Some summary info and metrics for this card.'),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovals() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Approvals', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Here is where approvals list and controls would appear.'),
          ],
        ),
      ),
    );
  }

  Widget _buildReports() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Text('Reports', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 12),
            Text('Reports and charts will be shown here.'),
          ],
        ),
      ),
    );
  }

  Widget _contentForIndex(int index) {
    switch (index) {
      case 1:
        return _buildApprovals();
      case 2:
        return _buildReports();
      case 3:
        return const AdminUsersWidget();
      case 0:
      default:
        return _buildOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    final userEmail = widget.user != null ? widget.user!['email'] ?? '' : '';
    // initial index is applied in initState; do not override on rebuild

    return Listener(
      onPointerDown: (_) => _resetTimer(),
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            if (isWide)
              Container(
                width: 240,
                color: Colors.white,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Image.asset('assets/images/lalco_logo.png', height: 36),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('LALCO', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const Divider(),
                      _navItem(Icons.dashboard, 'Overview', 0),
                      _navItem(Icons.check_circle_outline, 'Approvals', 1),
                      _navItem(Icons.bar_chart, 'Reports', 2),
                      _navItem(Icons.people, 'Users', 3),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text('Signed in as\n$userEmail', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ),
                    ],
                  ),
                ),
              ),
            // Main area
            Expanded(
              child: Column(
                children: [
                  // Topbar
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: Colors.white,
                    child: Row(
                      children: [
                        if (!isWide)
                          Builder(builder: (ctx) {
                            return IconButton(
                              icon: const Icon(Icons.menu),
                              onPressed: () {
                                Scaffold.of(ctx).openDrawer();
                              },
                            );
                          }),
                        const SizedBox(width: 8),
                        Text(_titles[_selectedIndex], style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        // Top-left sample buttons (three examples)
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Profile menu: custom anchored menu to allow submenus to the right
                        GestureDetector(
                          onTapDown: (details) => _showProfileMenu(details.globalPosition),
                          child: Row(
                            children: [
                              CircleAvatar(child: Text((userEmail.isNotEmpty ? userEmail[0] : 'U').toUpperCase())),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Container(
                      color: const Color(0xFFF6F7FB),
                      child: _contentForIndex(_selectedIndex),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        drawer: isWide
            ? null
            : Drawer(
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Image.asset('assets/images/lalco_logo.png', height: 32),
                            const SizedBox(width: 8),
                            const Expanded(child: Text('LALCO', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const Divider(),
                      ListTile(leading: const Icon(Icons.dashboard), title: const Text('Overview'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 0); Navigator.pushReplacementNamed(context, '/home_page.dart', arguments: widget.user); }),
                      ListTile(leading: const Icon(Icons.check_circle_outline), title: const Text('Approvals'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 1); Navigator.pushReplacementNamed(context, '/approvals_page.dart', arguments: widget.user); }),
                      ListTile(leading: const Icon(Icons.bar_chart), title: const Text('Reports'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 2); Navigator.pushReplacementNamed(context, '/reports_page.dart', arguments: widget.user); }),
                      ListTile(leading: const Icon(Icons.people), title: const Text('Users'), onTap: () { Navigator.pop(context); setState(() => _selectedIndex = 3); Navigator.pushReplacementNamed(context, '/admin_user_page.dart', arguments: widget.user); }),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  String _routeForIndex(int index) {
    switch (index) {
      case 1:
        return '/approvals_page.dart';
      case 2:
        return '/reports_page.dart';
      case 3:
        return '/admin_user_page.dart';
      case 0:
      default:
        return '/home_page.dart';
    }
  }

  Future<void> _showProfileMenu(Offset globalPos) async {
    final user = widget.user ?? {};
    final first = (user['first_name'] ?? '').toString();
    final last = (user['last_name'] ?? '').toString();
    final staffNo = (user['staff_no'] ?? '').toString();
    final nick = (user['nickname'] ?? '').toString();
    final dept = (user['department'] ?? '').toString();
    final displayName = (first.isNotEmpty || last.isNotEmpty) ? '$first $last' : (user['email'] ?? '');

    final selected = await showMenu<int>(
      context: context,
      position: RelativeRect.fromLTRB(globalPos.dx, globalPos.dy, globalPos.dx, globalPos.dy),
      items: [
        PopupMenuItem<int>(
          value: 0,
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text('$staffNo - $nick', style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Text(dept, style: const TextStyle(color: Colors.black87)),
              if (_language != null) Text(_language == 'th' ? 'ไทย' : 'English', style: const TextStyle(color: Colors.black54)),
              const Divider(),
            ],
          ),
        ),
        PopupMenuItem<int>(value: 10, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Language'), const Icon(Icons.chevron_right)])),
        PopupMenuItem<int>(value: 11, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Session timeout'), const Icon(Icons.chevron_right)])),
        PopupMenuItem<int>(value: 20, child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Switch Account'), const Icon(Icons.chevron_right)])),
        const PopupMenuItem<int>(value: 30, child: Text('Log Out')),
      ],
    );

    if (selected == 10) {
      // open language submenu to the right
      await _showLanguageMenu(globalPos);
    } else if (selected == 11) {
      await _chooseTimeout();
    } else if (selected == 20) {
      await _showSwitchAccountMenu(globalPos);
    } else if (selected == 30) {
      final ok = await _confirmLogout('Log Out');
      if (ok) _handleSwitchOrLogout();
    }
  }

  Future<void> _showLanguageMenu(Offset parentPos) async {
    final langs = {'en': 'English', 'th': 'ไทย'};
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(parentPos.dx + 200, parentPos.dy, parentPos.dx + 200, parentPos.dy),
      items: langs.entries.map((e) => PopupMenuItem<String>(value: e.key, child: Text(e.value))).toList(),
    );
    if (selected != null) {
      await Session.setLanguage(selected);
      if (!mounted) return;
      setState(() => _language = selected);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Language updated')));
    }
  }

  Future<void> _showSwitchAccountMenu(Offset parentPos) async {
    try {
      final recent = await Session.getRecentUsers();
      final items = <PopupMenuEntry<Map>>[];
      if (recent.isEmpty) {
        items.add(const PopupMenuItem<Map>(enabled: false, child: Text('No recent accounts on this browser')));
        items.add(PopupMenuItem<Map>(value: {}, child: Text('Sign in as different user')));
      } else {
        for (final u in recent) {
          final staff = (u['staff_no'] ?? '').toString();
          final nick = (u['nickname'] ?? '').toString().trim();
          final label = nick.isNotEmpty ? '$staff - $nick' : (u['email'] ?? staff).toString();
          items.add(PopupMenuItem<Map>(value: u, child: Text(label)));
        }
      }

      final sel = await showMenu<Map>(
        context: context,
        position: RelativeRect.fromLTRB(parentPos.dx + 200, parentPos.dy, parentPos.dx + 200, parentPos.dy),
        items: items,
      );

      if (!mounted) return;
      if (sel == null) return;

      // If user chose to sign in as different user (empty map), go to main login
      if (sel.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final email = (sel['email'] ?? '').toString();
      if (email.isEmpty) return;

      final saved = await Session.getSavedPasswordForEmail(email);
      String? password = saved;
      

      if (saved == null) {
        // prompt for password
        final pwController = TextEditingController();
        bool rememberChoice = false;
        if (!mounted) return;
        final ok = await showDialog<bool>(context: context, builder: (ctx) {
          return AlertDialog(
            title: Text('Enter password for $email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: pwController, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
                Row(children: [Checkbox(value: rememberChoice, onChanged: (v) { rememberChoice = v ?? false; (ctx as Element).markNeedsBuild(); }), const SizedBox(width: 6), const Text('Remember on this browser')]),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign In'))],
          );
        });
        if (ok != true) return;
        password = pwController.text;
        // can't remember choice here because closure mutated local var; ask again below via another dialog if needed
        // For simplicity, ask again whether to remember after successful login
      }

      // Attempt to authenticate using provided or saved password
      try {
        final loginResp = await http.post(Uri.parse('${_apiHost()}/api/login'), headers: {'Content-Type': 'application/json'}, body: json.encode({'email': email, 'password': password}));
        if (loginResp.statusCode != 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid credentials')));
          return;
        }
        final body = json.decode(loginResp.body) as Map<String, dynamic>;
        final id = body['id'] ?? body['user_id'] ?? body['user']?['id'];
        if (id == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login failed')));
          return;
        }

        // fetch full user record
        final detail = await http.get(Uri.parse('${_apiHost()}/api/users/$id'));
        if (detail.statusCode != 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load user details')));
          return;
        }
        final dbody = json.decode(detail.body) as Map<String, dynamic>;
        final user = (dbody['user'] ?? dbody) as Map<String, dynamic>;

        // save session and recent-user
        await Session.saveUser(user);
        await Session.addRecentUser(user);
        await Session.updateLastActivity();

        // if password wasn't saved, ask if user wants to remember now
        if (saved == null) {
          if (!mounted) return;
          final rememberNow = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
            title: const Text('Remember password?'),
            content: const Text('Save password for this browser to switch accounts without retyping?'),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes'))],
          ));
            if (rememberNow == true) {
            await Session.savePasswordForEmail(email, password ?? '');
          }
        }

          if (!mounted) return;
          Navigator.pushReplacementNamed(context, '/index.php', arguments: user);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error during sign in')));
      }
    } catch (_) {}
  }

  Widget _navItem(IconData icon, String label, int index) {
    final selected = index == _selectedIndex;
    return InkWell(
      onTap: () {
        final route = _routeForIndex(index);
        // Update state and push a named route so the browser URL reflects the active page
        setState(() => _selectedIndex = index);
        Navigator.pushReplacementNamed(context, route, arguments: widget.user);
      },
      child: Container(
        color: selected ? Colors.indigo.withAlpha((0.08 * 255).round()) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.indigo : Colors.grey[700]),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: selected ? Colors.indigo : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
