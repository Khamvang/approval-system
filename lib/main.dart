import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/home_page.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Approval',
      theme: ThemeData(primarySwatch: Colors.indigo),
      initialRoute: '/',
      routes: {
        '/': (ctx) => const LoginPage(),
      },
      onGenerateRoute: (settings) {
        // Support friendly paths for web like /index.php and file-like names
        final user = settings.arguments as Map?;
        switch (settings.name) {
          case '/index.php':
          case '/home':
          case '/home_page.dart':
            return MaterialPageRoute(builder: (_) => HomePage(user: user, initialIndex: 0));
          case '/approvals_page.dart':
            return MaterialPageRoute(builder: (_) => HomePage(user: user, initialIndex: 1));
          case '/reports_page.dart':
            return MaterialPageRoute(builder: (_) => HomePage(user: user, initialIndex: 2));
          case '/admin_user_page.dart':
          case '/users':
            return MaterialPageRoute(builder: (_) => HomePage(user: user, initialIndex: 3));
          default:
            return null;
        }
      },
    );
  }
}
