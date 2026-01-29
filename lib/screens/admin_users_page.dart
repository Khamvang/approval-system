import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

String _apiHost() {
  return kIsWeb
      ? 'http://localhost:5000'
      : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
}

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  List<dynamic> _users = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final resp = await http.get(Uri.parse('${_apiHost()}/api/users'));
      if (resp.statusCode == 200) {
        final body = json.decode(resp.body);
        if (!mounted) return;
        setState(() => _users = body['users'] ?? []);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load users')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _editUser(Map user) async {
    final roleController = TextEditingController(text: user['role'] ?? 'User');
    final deptController = TextEditingController(text: user['department'] ?? '');

    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Edit user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(user['email'] ?? ''),
            const SizedBox(height: 8),
            TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
            TextField(controller: deptController, decoration: const InputDecoration(labelText: 'Department')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      );
    });

    if (res != true) return;

    final payload = {'role': roleController.text.trim(), 'department': deptController.text.trim()};
    try {
      final resp = await http.patch(Uri.parse('${_apiHost()}/api/users/${user['id']}'), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      if (resp.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User updated')));
        await _loadUsers();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Update failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    }
  }

  Future<void> _createUser() async {
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final roleController = TextEditingController(text: 'User');

    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return AlertDialog(
        title: const Text('Create user'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: passController, decoration: const InputDecoration(labelText: 'Password')),
            TextField(controller: roleController, decoration: const InputDecoration(labelText: 'Role')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
        ],
      );
    });

    if (res != true) return;

    final payload = {'email': emailController.text.trim(), 'password': passController.text, 'role': roleController.text.trim()};
    try {
      final resp = await http.post(Uri.parse('${_apiHost()}/api/users'), headers: {'Content-Type': 'application/json'}, body: json.encode(payload));
      if (resp.statusCode == 201) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User created')));
        await _loadUsers();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Create failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers), IconButton(icon: const Icon(Icons.add), onPressed: _createUser)],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _users.length,
              itemBuilder: (ctx, i) {
                final u = _users[i];
                return ListTile(
                  title: Text(u['email'] ?? ''),
                  subtitle: Text('${u['role'] ?? ''}${u['department'] != null ? ' • ${u['department']}' : ''}'),
                  trailing: IconButton(icon: const Icon(Icons.edit), onPressed: () => _editUser(u)),
                );
              },
            ),
    );
  }
}
