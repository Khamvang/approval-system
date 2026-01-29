// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/session.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey _emailFieldKey = GlobalKey();
  bool _obscure = true;
  bool _loading = false;
  bool _rememberMe = false;
  // role/department selection moved to admin UI after login

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadSavedCredentials();
    _emailController.addListener(() {
      _onEmailChanged(_emailController.text.trim());
    });
  }

  Future<void> _loadSavedCredentials() async {
    try {
      final recent = await Session.getRecentUsers();
      if (recent.isNotEmpty) {
        final user = recent.first;
        final email = (user['email'] ?? '').toString();
        if (email.isNotEmpty) {
          final saved = await Session.getSavedPasswordForEmail(email);
          if (!mounted) return;
          setState(() {
            _emailController.text = email;
            if (saved != null && saved.isNotEmpty) {
              _passwordController.text = saved;
              _rememberMe = true;
            }
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _onEmailChanged(String email) async {
    if (email.isEmpty) {
      if (!mounted) return;
      setState(() => _passwordController.text = '');
      return;
    }
    try {
      final saved = await Session.getSavedPasswordForEmail(email);
      if (!mounted) return;
      if (saved != null && saved.isNotEmpty) {
        setState(() {
          _passwordController.text = saved;
          _rememberMe = true;
        });
      } else {
        setState(() {
          // do not clear if user typed password manually; only clear if currently matches a previous saved password
          if (_passwordController.text.isEmpty) {
            _rememberMe = false;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _loading = true);

    // choose host depending on platform (Android emulator needs 10.0.2.2)
    final host = kIsWeb
        ? 'http://localhost:5000'
        : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');

    final uri = Uri.parse('$host/api/login');
    try {
      final resp = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'email': _emailController.text.trim(),
            'password': _passwordController.text
          }));

      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        final user = body['user'] ?? {};
        // attempt to fetch full user record (includes staff_no, first_name, last_name, nickname)
        try {
          final id = user['id'];
          if (id != null) {
            final uresp = await http.get(Uri.parse('$host/api/users/$id'));
            if (uresp.statusCode == 200) {
              final ub = json.decode(uresp.body);
              // backend returns {'user': {...}}
              final full = ub['user'] ?? {};
              if (full is Map && full.isNotEmpty) {
                // overwrite user with full record
                user.addAll(Map<String, dynamic>.from(full));
              }
            }
          }
        } catch (_) {}
        final email = user['email'] ?? body['email'] ?? '';
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logged in as $email')));
        // navigate to home page via named route so web URL is friendly
        // persist session
        await Session.saveUser(Map<String, dynamic>.from(user));
        // add to recent users list
        await Session.addRecentUser({'email': user['email'] ?? '', 'first_name': user['first_name'] ?? '', 'last_name': user['last_name'] ?? '', 'staff_no': user['staff_no'] ?? '', 'nickname': user['nickname'] ?? '', 'department': user['department'] ?? ''});
        // if remember checked, save password for this email on this browser
        if (_rememberMe) {
          await Session.savePasswordForEmail(user['email'] ?? '', _passwordController.text);
        }
        await Session.updateLastActivity();
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/index.php', arguments: user);
        }
      } else {
        String msg = 'Login failed';
        try {
          final body = json.decode(resp.body);
          msg = body['error'] ?? msg;
        } catch (_) {}
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildForm(double width) {
    final fieldWidth = width > 420 ? 420.0 : width * 0.9;
    return SizedBox(
      width: fieldWidth,
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: Colors.white.withAlpha((0.95 * 255).round()),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18.0, horizontal: 20.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo at the top
                if (true) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0, bottom: 8.0),
                    child: Center(
                      child: Image.asset('assets/images/lalco_logo.png', height: 64, fit: BoxFit.contain),
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                const Text('Welcome back !!!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Sign in to continue', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 18),
                TextFormField(
                  key: _emailFieldKey,
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                  onTap: () async {
                    // show recent emails saved on this browser
                    try {
                      final renderCtx = _emailFieldKey.currentContext;
                      if (renderCtx == null) return;
                      final RenderBox box = renderCtx.findRenderObject() as RenderBox;
                      final pos = box.localToGlobal(Offset.zero);

                      final recent = await Session.getRecentUsers();
                      if (recent.isEmpty) return;

                      final items = recent.map((u) {
                        final map = Map<String, dynamic>.from(u as Map);
                        final email = (map['email'] ?? '').toString();
                        return PopupMenuItem<Map<String, dynamic>>(value: map, child: Text(email));
                      }).toList();

                      final sel = await showMenu<Map<String, dynamic>>(
                        context: renderCtx,
                        position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height, pos.dx + box.size.width, pos.dy),
                        items: items,
                      );
                      if (sel == null) return;
                      final email = (sel['email'] ?? '').toString();
                      if (!mounted) return;
                      setState(() {
                        _emailController.text = email;
                      });
                      final saved = await Session.getSavedPasswordForEmail(email);
                      if (!mounted) return;
                      if (saved != null && saved.isNotEmpty) {
                        setState(() {
                          _passwordController.text = saved;
                          _rememberMe = true;
                        });
                      } else {
                        setState(() {
                          _passwordController.text = '';
                          _rememberMe = false;
                        });
                      }
                    } catch (_) {}
                  },
                  onChanged: (v) => _onEmailChanged(v.trim()),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter password';
                    if (v.length < 6) return 'Password too short';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(value: _rememberMe, onChanged: (v) => setState(() => _rememberMe = v ?? false)),
                    const SizedBox(width: 4),
                    const Text('Remember me on this browser'),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Sign in'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: () {}, child: const Text('Forgot password?')),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        body: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth;
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: const AssetImage('assets/images/bg.jpg'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(Colors.black.withAlpha((0.25 * 255).round()), BlendMode.darken),
              ),
            ),
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 48),
                child: _buildForm(width),
              ),
            ),
          );
        }),
      ),
    );
  }
}
