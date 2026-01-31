// ignore_for_file: use_build_context_synchronously
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import '../services/close_contract_api.dart';
import '../services/session.dart';

const _steps = [
  {'key': 'submit', 'label': 'Submit', 'role': 'Submitter'},
  {'key': 'credit', 'label': 'Credit Approval', 'role': 'Credit Approval'},
  {'key': 'system', 'label': 'System Approval', 'role': 'System Approval'},
  {'key': 'coo', 'label': 'COO & Admin Approval', 'role': 'COO & Admin Approval'},
  {'key': 'lms', 'label': 'LMS Void Approval', 'role': 'LMS Void Approval'},
];

class CloseContractApprovalPage extends StatefulWidget {
  final Map<String, dynamic>? user;
  const CloseContractApprovalPage({super.key, this.user});

  @override
  State<CloseContractApprovalPage> createState() => _CloseContractApprovalPageState();
}

class _CloseContractApprovalPageState extends State<CloseContractApprovalPage> {
  final _formKey = GlobalKey<FormState>();
  final _ctrl = <String, TextEditingController>{};
  bool _submitting = false;
  PlatformFile? _attachment;
  Map<String, dynamic>? _currentRequest;
  Map<String, dynamic>? _user;
  List<Map<String, dynamic>> _todo = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final key in [
      'collection_type',
      'contract_no',
      'person_in_charge',
      'manager_in_charge',
      'last_contract_info',
      'paid_term',
      'total_term',
      'full_paid_date',
      's_count',
      'a_count',
      'b_count',
      'c_count',
      'f_count',
      'principal_remaining',
      'interest_remaining',
      'penalty_remaining',
      'others_remaining',
      'principal_willing',
      'interest_willing',
      'interest_months',
      'penalty_willing',
      'others_willing',
      'remark',
    ]) {
      _ctrl[key] = TextEditingController();
    }
    _ctrl['collection_type']!.text = 'This month';
    _loadUserAndData();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadUserAndData() async {
    final u = widget.user ?? await Session.loadUser();
    setState(() => _user = u?.map((key, value) => MapEntry(key.toString(), value)));
    await _refreshTodo();
  }

  Future<void> _refreshTodo() async {
    if (_user == null) return;
    try {
      final role = (_user!['role'] ?? '').toString();
      final items = await CloseContractApi.listRequests(role: role, includeActions: true);
      setState(() {
        _todo = items;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    if (result != null && result.files.isNotEmpty) {
      setState(() => _attachment = result.files.first);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });

    final payload = {
      'collection_type': _ctrl['collection_type']!.text.trim(),
      'contract_no': _ctrl['contract_no']!.text.trim(),
      'person_in_charge': _ctrl['person_in_charge']!.text.trim(),
      'manager_in_charge': _ctrl['manager_in_charge']!.text.trim(),
      'last_contract_info': _ctrl['last_contract_info']!.text.trim(),
      'paid_term': _ctrl['paid_term']!.text.trim(),
      'total_term': _ctrl['total_term']!.text.trim(),
      'full_paid_date': _ctrl['full_paid_date']!.text.trim(),
      's_count': _ctrl['s_count']!.text.trim(),
      'a_count': _ctrl['a_count']!.text.trim(),
      'b_count': _ctrl['b_count']!.text.trim(),
      'c_count': _ctrl['c_count']!.text.trim(),
      'f_count': _ctrl['f_count']!.text.trim(),
      'principal_remaining': _ctrl['principal_remaining']!.text.trim(),
      'interest_remaining': _ctrl['interest_remaining']!.text.trim(),
      'penalty_remaining': _ctrl['penalty_remaining']!.text.trim(),
      'others_remaining': _ctrl['others_remaining']!.text.trim(),
      'principal_willing': _ctrl['principal_willing']!.text.trim(),
      'interest_willing': _ctrl['interest_willing']!.text.trim(),
      'interest_months': _ctrl['interest_months']!.text.trim(),
      'penalty_willing': _ctrl['penalty_willing']!.text.trim(),
      'others_willing': _ctrl['others_willing']!.text.trim(),
      'remark': _ctrl['remark']!.text.trim(),
      'created_by_email': _user?['email'],
      'created_by_id': _user?['id'],
      'created_by_name': '${_user?['first_name'] ?? ''} ${_user?['last_name'] ?? ''}'.trim(),
    };

    try {
      final item = await CloseContractApi.createRequest(payload: payload, attachment: _attachment);
      setState(() => _currentRequest = item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted for Credit Approval')));
      await _refreshTodo();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  bool _canActOnCurrent() {
    if (_currentRequest == null || _user == null) return false;
    final currentStep = (_currentRequest!['current_step'] ?? '').toString();
    final role = (_user!['role'] ?? '').toString();
    final step = _steps.firstWhere((s) => s['key'] == currentStep, orElse: () => {});
    return step['role'] == role && (_currentRequest!['status'] != 'approved' && _currentRequest!['status'] != 'rejected');
  }

  Future<void> _act(String result) async {
    if (_currentRequest == null) return;
    setState(() => _submitting = true);
    try {
      final updated = await CloseContractApi.actOnRequest(
        _currentRequest!['id'] as int,
        result: result,
        comment: _ctrl['remark']!.text.trim().isNotEmpty ? _ctrl['remark']!.text.trim() : null,
        actorEmail: _user?['email']?.toString(),
        actorId: (_user?['id'] is int) ? (_user?['id'] as int) : int.tryParse(_user?['id']?.toString() ?? ''),
        actorName: "${_user?['first_name'] ?? ''} ${_user?['last_name'] ?? ''}".trim(),
        actorRole: _user?['role']?.toString(),
      );
      setState(() => _currentRequest = updated);
      await _refreshTodo();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action saved: $result')));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _handlePrint() async {
    if (_currentRequest == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submit or load a request before printing.')));
      return;
    }
    final item = _currentRequest!;
    final doc = pw.Document();
    final fmt = NumberFormat('#,##0.00');
    pw.Widget moneyRow(String label, dynamic value) => pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [pw.Text(label), pw.Text(value == null ? '-' : fmt.format(value))],
    );
    doc.addPage(
      pw.Page(
        build: (context) => pw.Padding(
          padding: const pw.EdgeInsets.all(24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Close Contract Approval Ringi', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              pw.Text('Contract No: ${item['contract_no'] ?? ''}'),
              pw.Text('Collection type: ${item['collection_type'] ?? ''}'),
              pw.Text('Person in Charge: ${item['person_in_charge'] ?? ''}'),
              pw.Text('Manager of Person in Charge: ${item['manager_in_charge'] ?? ''}'),
              pw.SizedBox(height: 12),
              pw.Text('Payment history'),
              pw.Text('S at 5th: ${item['s_count'] ?? '-'} | A at 10th: ${item['a_count'] ?? '-'} | B at 20th: ${item['b_count'] ?? '-'} | C at 31st: ${item['c_count'] ?? '-'} | F after 1 month: ${item['f_count'] ?? '-'}'),
              pw.SizedBox(height: 12),
              pw.Text('Remaining Amount'),
              moneyRow('Principal remaining', item['principal_remaining']),
              moneyRow('Interest remaining', item['interest_remaining']),
              moneyRow('Penalty remaining', item['penalty_remaining']),
              moneyRow('Others remaining', item['others_remaining']),
              pw.SizedBox(height: 12),
              pw.Text('Willing to pay'),
              moneyRow('Principal willing to pay', item['principal_willing']),
              moneyRow('Interest willing to pay', item['interest_willing']),
              moneyRow('Penalty willing to pay', item['penalty_willing']),
              moneyRow('Others willing to pay', item['others_willing']),
              pw.Text('Interest willing to pay (months): ${item['interest_months'] ?? '-'}'),
              pw.SizedBox(height: 12),
              pw.Text('Remark: ${item['remark'] ?? '-'}'),
              pw.SizedBox(height: 12),
              pw.Text('Approval Record'),
              ...(_steps.map((s) {
                final actions = (item['actions'] as List?) ?? [];
                final matched = actions.where((a) => a['step_key'] == s['key']).toList();
                final latest = matched.isNotEmpty ? matched.last : null;
                final result = latest != null ? (latest['result'] ?? 'pending') : 'pending';
                final time = latest != null ? (latest['acted_at'] ?? '') : '';
                final comment = latest != null ? (latest['comment'] ?? '') : '';
                return pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${s['label']}: $result ($time)'),
                    if (comment.isNotEmpty) pw.Text('Comment: $comment', style: pw.TextStyle(color: PdfColors.grey)),
                    pw.SizedBox(height: 4),
                  ],
                );
              }))
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Close Contract Approval Ringi'),
        actions: [
          IconButton(onPressed: _handlePrint, icon: const Icon(Icons.print)),
          const SizedBox(width: 8),
        ],
      ),
      body: Row(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFF6F7FB), Color(0xFFFFFFFF)], begin: Alignment.topCenter, end: Alignment.bottomCenter),
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              FilledButton.icon(onPressed: _submitting ? null : _submit, icon: const Icon(Icons.send), label: Text(_submitting ? 'Submitting...' : 'Submit')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _field('Collection type', 'collection_type'),
                              _field('Contract No', 'contract_no', requiredField: true),
                              _field('Person in Charge', 'person_in_charge'),
                              _field('Manager of Person in Charge', 'manager_in_charge'),
                              _field('Lasted contract information ຂໍ້ມູນສັນຍາຫຼ້າສຸດ', 'last_contract_info', maxLines: 2),
                              _field('Paid Term', 'paid_term'),
                              _field('Total Term', 'total_term'),
                              _field('Full paid date (or first due date if unpaid)', 'full_paid_date'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Payment history'),
                          _paymentHistoryRow(),
                          const SizedBox(height: 16),
                          _sectionTitle('Remaining Amount'),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _field('Principal remaining', 'principal_remaining'),
                              _field('Interest remaining', 'interest_remaining'),
                              _field('Penalty remaining', 'penalty_remaining'),
                              _field('Others remaining', 'others_remaining'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Willing to pay amount'),
                          Wrap(
                            spacing: 16,
                            runSpacing: 12,
                            children: [
                              _field('Principal willing to pay', 'principal_willing'),
                              _field('Interest willing to pay', 'interest_willing'),
                              _field('Interest willing to pay (months)', 'interest_months'),
                              _field('Penalty willing to pay', 'penalty_willing'),
                              _field('Others willing to pay', 'others_willing'),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _sectionTitle('Remark & Attachment'),
                          _field('Remark', 'remark', maxLines: 3),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              OutlinedButton.icon(onPressed: _pickAttachment, icon: const Icon(Icons.attach_file), label: Text(_attachment == null ? 'Add attachment' : _attachment!.name)),
                              const SizedBox(width: 12),
                              if (_attachment != null) Text('${(_attachment!.size / 1024).toStringAsFixed(1)} KB'),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Text(_error!, style: const TextStyle(color: Colors.red)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Container(width: 1, color: Colors.grey.shade200),
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _currentRequest == null
                      ? _emptyState(theme)
                      : _detailCard(theme),
                  const SizedBox(height: 16),
                  _todoCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Approval Record', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Fill in the form and submit to start the approval. Pending items for your role will appear here.', style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _detailCard(ThemeData theme) {
    final item = _currentRequest!;
    final status = (item['status'] ?? '').toString();
    final actions = (item['actions'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('Approval Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: status == 'approved' ? Colors.green.shade50 : Colors.indigo.shade50, borderRadius: BorderRadius.circular(20)),
                  child: Text(status, style: TextStyle(color: status == 'approved' ? Colors.green : Colors.indigo, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._steps.map((step) {
              final matches = actions.where((a) => a['step_key'] == step['key']).toList();
              final latest = matches.isNotEmpty ? matches.last : null;
              final result = latest != null ? (latest['result'] ?? 'pending') : 'pending';
              final comment = latest != null ? (latest['comment'] ?? '') : '';
              final actedAt = latest != null ? (latest['acted_at'] ?? '') : '';
                final color = (result == 'approve' || result == 'approved')
                  ? Colors.green
                  : ((result == 'reject' || result == 'rejected') ? Colors.red : Colors.indigo);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(step['label'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Result: $result'),
                  if (comment.isNotEmpty) Text('Comment: $comment'),
                  if (actedAt.isNotEmpty) Text(actedAt, style: const TextStyle(color: Colors.grey)),
                ]),
                trailing: Icon(Icons.circle, size: 14, color: color),
              );
            }),
            if (_canActOnCurrent()) ...[
              const Divider(),
              Wrap(
                spacing: 8,
                children: [
                  ElevatedButton.icon(onPressed: _submitting ? null : () => _act('approve'), icon: const Icon(Icons.check), label: const Text('Approve')),
                  OutlinedButton.icon(
                    onPressed: _submitting ? null : () => _act('reject'),
                    icon: const Icon(Icons.close, color: Colors.red),
                    label: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                  TextButton.icon(onPressed: _submitting ? null : () => _act('send_back'), icon: const Icon(Icons.reply), label: const Text('Send Back')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _todoCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('My To-do (current step matches my role)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (_todo.isEmpty) const Text('No pending items right now.'),
            ..._todo.map((t) {
              final step = (t['current_step'] ?? '').toString();
              final label = _steps.firstWhere((s) => s['key'] == step, orElse: () => {'label': step})['label'];
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(t['contract_no']?.toString() ?? ''),
                subtitle: Text('Step: $label | Person: ${t['person_in_charge'] ?? '-'}'),
                trailing: Text(t['status']?.toString() ?? ''),
                onTap: () async {
                  final id = t['id'];
                  final reqId = id is int ? id : int.tryParse(id.toString());
                  if (reqId == null) return;
                  final detailed = await CloseContractApi.getRequest(reqId);
                  setState(() => _currentRequest = detailed);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, String key, {int maxLines = 1, bool requiredField = false}) {
    return SizedBox(
      width: 320,
      child: TextFormField(
        controller: _ctrl[key],
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: requiredField
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _paymentHistoryRow() {
    return Card(
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _miniNumber('S at 5th(time)', 's_count'),
              _miniNumber('A at 10th(time)', 'a_count'),
              _miniNumber('B at 20th(time)', 'b_count'),
              _miniNumber('C at 31st(time)', 'c_count'),
              _miniNumber('F after 1 month(time)', 'f_count'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _miniNumber(String label, String key) {
    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: SizedBox(
        width: 150,
        child: TextFormField(
          controller: _ctrl[key],
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
          keyboardType: TextInputType.number,
        ),
      ),
    );
  }
}
