import 'package:flutter/material.dart';
import 'admin_users_widget.dart';

class HomePage extends StatefulWidget {
  final Map? user;
  final int? initialIndex;
  const HomePage({super.key, this.user, this.initialIndex});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null) {
      _selectedIndex = widget.initialIndex!;
    }
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

    return Scaffold(
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
                      CircleAvatar(child: Text((userEmail.isNotEmpty ? userEmail[0] : 'U').toUpperCase())),
                      const SizedBox(width: 8),
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
