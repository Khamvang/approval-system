import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;

String _apiHost() {
  return kIsWeb
      ? 'http://localhost:5000'
      : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
}

class AdminUsersWidget extends StatefulWidget {
  const AdminUsersWidget({super.key});

  @override
  State<AdminUsersWidget> createState() => _AdminUsersWidgetState();
}

class _AdminUsersWidgetState extends State<AdminUsersWidget> {
  List<dynamic> _users = [];
  bool _loading = false;
  final TextEditingController _searchController = TextEditingController();
  String? _departmentFilter;

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
        setState(() => _users = body['users'] ?? []);
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to load users')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editUser(Map user) async {
    final staffController = TextEditingController(text: user['staff_no'] ?? '');
    final emailController = TextEditingController(text: user['email'] ?? '');
    final roleVal = user['role'] ?? 'User';
    String selectedRole = roleVal;
    final deptVal = user['department'] ?? '';
    String selectedDept = deptVal;
    final deptOptions = ['Sales', 'Collection', 'Credit', 'Contract', 'Accounting', 'HR', 'IT'];
    final underController = TextEditingController(text: user['under_manager'] ?? '');
    final statusRaw = (user['status'] ?? '').toString();
    final statusController = TextEditingController(text: statusRaw.isNotEmpty ? (statusRaw[0].toUpperCase() + statusRaw.substring(1)) : '');
    final nicknameController = TextEditingController(text: user['nickname'] ?? '');
    // use separate first_name / last_name fields only
    final firstController = TextEditingController(text: (user['first_name'] ?? '').toString());
    final lastController = TextEditingController(text: (user['last_name'] ?? '').toString());
    final passController = TextEditingController();

    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        // build manager list for selectedDept and show nickname or fallback
        final managers = _users.where((u) => (u['role'] ?? '') == 'Manager' && (u['department'] ?? '') == selectedDept).toList();
        final managerItems = [null, ...managers].map<DropdownMenuItem<String?>>((m) {
          if (m == null) return DropdownMenuItem<String?>(value: null, child: const Text(''));
          final staff = (m['staff_no'] ?? '').toString();
          final nickRaw = (m['nickname'] ?? '').toString().trim();
          final nick = nickRaw.isNotEmpty ? nickRaw : '(no nickname)';
          return DropdownMenuItem<String?>(value: staff, child: Text('$staff - $nick'));
        }).toList();
        return AlertDialog(
          title: const Text('Edit user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: staffController, decoration: const InputDecoration(labelText: 'Staff No')),
                Row(children: [Expanded(child: TextField(controller: firstController, decoration: const InputDecoration(labelText: 'First Name'))), const SizedBox(width: 8), Expanded(child: TextField(controller: lastController, decoration: const InputDecoration(labelText: 'Last Name')))]),
                TextField(controller: nicknameController, decoration: const InputDecoration(labelText: 'Nickname')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: passController, decoration: const InputDecoration(labelText: 'Password (leave blank to keep)')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: selectedRole, items: ['User', 'Manager', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setState(() => selectedRole = v ?? 'User'), decoration: const InputDecoration(labelText: 'Role')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: selectedDept.isEmpty ? null : selectedDept, items: deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), onChanged: (v) => setState(() => selectedDept = v ?? ''), decoration: const InputDecoration(labelText: 'Department')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(initialValue: underController.text.isEmpty ? null : underController.text, items: managerItems, onChanged: (v) => setState(() => underController.text = v ?? ''), decoration: const InputDecoration(labelText: 'Under Manager')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: statusController.text.isNotEmpty ? statusController.text : 'Active', items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => statusController.text = v ?? 'Active'), decoration: const InputDecoration(labelText: 'Status')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () {
              // validate role and department selections
              if (!['User', 'Manager', 'Admin'].contains(selectedRole)) return; 
              Navigator.pop(ctx, true);
            }, child: const Text('Save')),
          ],
        );
      });
    });

    if (res != true) return;

    final payload = {
      'role': selectedRole.trim(),
      'department': selectedDept.trim(),
      'staff_no': staffController.text.trim(),
      'first_name': firstController.text.trim(),
      'last_name': lastController.text.trim(),
      'nickname': nicknameController.text.trim(),
      'under_manager': underController.text.trim(),
      'status': statusController.text.trim(),
    };
    if (passController.text.isNotEmpty) payload['password'] = passController.text;
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
    final staffController = TextEditingController();
    final firstController = TextEditingController();
    final lastController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();
    final underController = TextEditingController();
    final statusController = TextEditingController(text: 'Active');

    String selectedRole = 'User';
    String selectedDept = '';
    final deptOptions = ['Sales', 'Collection', 'Credit', 'Contract', 'Accounting', 'HR', 'IT'];
    final nicknameController = TextEditingController();
    final res = await showDialog<bool>(context: context, builder: (ctx) {
      return StatefulBuilder(builder: (ctx, setState) {
        final managers = _users.where((u) => (u['role'] ?? '') == 'Manager' && (u['department'] ?? '') == selectedDept).toList();
        final managerItems = [null, ...managers].map<DropdownMenuItem<String?>>((m) {
          if (m == null) return DropdownMenuItem<String?>(value: null, child: const Text(''));
          final staff = (m['staff_no'] ?? '').toString();
          final nickRaw = (m['nickname'] ?? '').toString().trim();
          final nick = nickRaw.isNotEmpty ? nickRaw : '(no nickname)';
          return DropdownMenuItem<String?>(value: staff, child: Text('$staff - $nick'));
        }).toList();
        return AlertDialog(
          title: const Text('Create user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: staffController, decoration: const InputDecoration(labelText: 'Staff No')),
                Row(children: [Expanded(child: TextField(controller: firstController, decoration: const InputDecoration(labelText: 'First Name'))), const SizedBox(width: 8), Expanded(child: TextField(controller: lastController, decoration: const InputDecoration(labelText: 'Last Name')))]),
                TextField(controller: nicknameController, decoration: const InputDecoration(labelText: 'Nickname')),
                TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
                TextField(controller: passController, decoration: const InputDecoration(labelText: 'Password')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: selectedRole, items: ['User', 'Manager', 'Admin'].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(), onChanged: (v) => setState(() => selectedRole = v ?? 'User'), decoration: const InputDecoration(labelText: 'Role')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: selectedDept.isEmpty ? null : selectedDept, items: deptOptions.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(), onChanged: (v) => setState(() => selectedDept = v ?? ''), decoration: const InputDecoration(labelText: 'Department')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(initialValue: underController.text.isEmpty ? null : underController.text, items: managerItems, onChanged: (v) => setState(() => underController.text = v ?? ''), decoration: const InputDecoration(labelText: 'Under Manager')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(initialValue: statusController.text.isNotEmpty ? statusController.text : 'Active', items: ['Active', 'Inactive'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(), onChanged: (v) => setState(() => statusController.text = v ?? 'Active'), decoration: const InputDecoration(labelText: 'Status')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create')),
          ],
        );
      });
    });

    if (res != true) return;

    final payload = {
      'staff_no': staffController.text.trim(),
      'first_name': firstController.text.trim(),
      'last_name': lastController.text.trim(),
      'nickname': nicknameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passController.text,
      'role': selectedRole.trim(),
      'department': selectedDept.trim(),
      'under_manager': underController.text.trim(),
      'status': statusController.text.trim().toLowerCase(),
    };
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

  Future<void> _deleteUser(Map u) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Delete user'),
      content: Text('Delete ${u['email']}?'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete'))],
    ));
    if (ok != true) return;
    try {
      final resp = await http.delete(Uri.parse('${_apiHost()}/api/users/${u['id']}'));
      if (resp.statusCode == 200) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
        await _loadUsers();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Delete failed')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not reach API')));
    }
  }

  void _exportCsv() {
    final rows = _filteredUsers;
    final buffer = StringBuffer();
    buffer.writeln('staff_no,first_name,last_name,nickname,email,department,role,under_manager,last_login,status');
    for (final u in rows) {
      final first = (u['first_name'] ?? '').toString();
      final last = (u['last_name'] ?? '').toString();
      final nick = (u['nickname'] ?? '').toString();
      buffer.writeln('"${u['staff_no'] ?? ''}","$first","$last","$nick","${u['email'] ?? ''}","${u['department'] ?? ''}","${u['role'] ?? ''}","${u['under_manager'] ?? ''}","${u['last_login'] ?? ''}","${u['status'] ?? ''}"');
    }
    showDialog(context: context, builder: (ctx) => AlertDialog(title: const Text('CSV Export'), content: SingleChildScrollView(child: SelectableText(buffer.toString())), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))]));
  }

  List<dynamic> get _filteredUsers {
    final q = _searchController.text.trim().toLowerCase();
    return _users.where((u) {
      if (_departmentFilter != null && _departmentFilter!.isNotEmpty) {
        if ((u['department'] ?? '') != _departmentFilter) return false;
      }
      if (q.isEmpty) return true;
      final email = (u['email'] ?? '').toString().toLowerCase();
      final name = '${(u['first_name'] ?? '').toString().toLowerCase()} ${(u['last_name'] ?? '').toString().toLowerCase()}';
      final staff = (u['staff_no'] ?? '').toString().toLowerCase();
      return email.contains(q) || name.contains(q) || staff.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final deptOptions = ['Sales', 'Collection', 'Credit', 'Contract', 'Accounting', 'HR', 'IT'];
    final deptItems = [null, ...deptOptions].map<DropdownMenuItem<String?>>((d) => DropdownMenuItem<String?>(value: d, child: Text(d ?? 'All'))).toList();
    final rows = _filteredUsers.map<DataRow>((u) {
      final first = (u['first_name'] ?? '').toString();
      final last = (u['last_name'] ?? '').toString();
      // compute under manager label: find manager by staff_no and show StaffNo - Nickname (fallback)
      final underVal = (u['under_manager'] ?? '').toString();
      String underLabel = '';
      if (underVal.isNotEmpty) {
        final mgrList = _users.where((x) => (x['staff_no'] ?? '').toString() == underVal).toList();
        if (mgrList.isNotEmpty) {
          final m = mgrList.first;
          final mStaff = (m['staff_no'] ?? '').toString();
          final mNickRaw = (m['nickname'] ?? '').toString().trim();
          final mNick = mNickRaw.isNotEmpty ? mNickRaw : '(no nickname)';
          underLabel = '$mStaff - $mNick';
        } else {
          underLabel = underVal;
        }
      }
      return DataRow(cells: [
        DataCell(Text(u['staff_no'] ?? '')),
        DataCell(Text(first)),
        DataCell(Text(last)),
        DataCell(Text(u['nickname'] ?? '')),
        DataCell(Text(u['email'] ?? '')),
        DataCell(Text(u['department'] ?? '')),
        DataCell(Text(u['role'] ?? '')),
        DataCell(Text(underLabel)),
        DataCell(Text(u['last_login'] ?? '')),
        DataCell(Text(u['status'] ?? '')),
        DataCell(Row(children: [IconButton(icon: const Icon(Icons.edit), onPressed: () => _editUser(u)), IconButton(icon: const Icon(Icons.delete), onPressed: () => _deleteUser(u))])),
      ]);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('User List', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              Row(children: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadUsers), ElevatedButton.icon(onPressed: _createUser, icon: const Icon(Icons.add), label: const Text('Create'))])
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search email, name, staff no'),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String?>(value: _departmentFilter, hint: const Text('Department'), items: deptItems, onChanged: (String? v) => setState(() => _departmentFilter = v)),
              const SizedBox(width: 12),
              ElevatedButton.icon(onPressed: _exportCsv, icon: const Icon(Icons.download), label: const Text('Export')),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Card(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: DataTable(
                          columns: [
                            const DataColumn(label: Text('Staff No')),
                            const DataColumn(label: Text('First Name')),
                            const DataColumn(label: Text('Last Name')),
                            const DataColumn(label: Text('Nickname')),
                            const DataColumn(label: Text('Email')),
                            const DataColumn(label: Text('Department')),
                            const DataColumn(label: Text('Role')),
                            const DataColumn(label: Text('Under Manager')),
                            const DataColumn(label: Text('Last Login')),
                            const DataColumn(label: Text('Status')),
                            const DataColumn(label: Text('Action')),
                          ],
                          rows: rows,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
