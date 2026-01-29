import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';
import 'screens/approvals_page.dart';
import 'services/session.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  Future<Map?>? _initialUserFuture;

  @override
  void initState() {
    super.initState();
    _initialUserFuture = _loadSession();
  }

  Future<Map?> _loadSession() async {
    final user = await Session.loadUser();
    if (user == null) return null;
    final last = await Session.getLastActivityMillis();
    if (last == null) return null;
    final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(last));
    // auto-logout after 30 minutes
    if (diff.inMinutes >= 30) {
      await Session.clear();
      return null;
    }
    // refresh last activity timestamp
    await Session.updateLastActivity();
    return user;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map?>(
      future: _initialUserFuture,
      builder: (context, snap) {
        // while loading, show a minimal splash
        if (snap.connectionState != ConnectionState.done) {
          return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
        }

        final user = snap.data;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Approval',
          theme: ThemeData(primarySwatch: Colors.indigo),
          // If user present, go to HomePage directly; otherwise show LoginPage
          home: user != null ? HomePage(user: user, initialIndex: 0) : const LoginPage(),
          onGenerateRoute: (settings) {
            final usr = settings.arguments as Map?;
            switch (settings.name) {
              case '/index.php':
              case '/home':
              case '/home_page.dart':
                return MaterialPageRoute(builder: (_) => HomePage(user: usr, initialIndex: 0));
              case '/approvals_page.dart':
                return MaterialPageRoute(builder: (_) => HomePage(user: usr, initialIndex: 1));
              case '/reports_page.dart':
                return MaterialPageRoute(builder: (_) => HomePage(user: usr, initialIndex: 2));
              case '/admin_user_page.dart':
              case '/users':
                return MaterialPageRoute(builder: (_) => HomePage(user: usr, initialIndex: 3));
              case '/approvals':
                return ApprovalsPage.route();
              default:
                return null;
            }
          },
        );
      },
    );
  }
}
