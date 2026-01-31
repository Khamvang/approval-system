// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import '../services/session.dart';
import 'close_contract_approval_page.dart';
import '../services/close_contract_api.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({super.key});

  static Route<void> route() => MaterialPageRoute<void>(builder: (context) => const ApprovalsPage());

  @override
  State<ApprovalsPage> createState() => _ApprovalsPageState();
}

class _ApprovalsPageState extends State<ApprovalsPage> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, String>> _recommended = [
    {'title': 'System Modification Ringi'},
    {'title': 'Expense Approval Ringi'},
    {'title': 'Open Contract Approval Ringi'},
    {'title': 'Close Contract Approval Ringi'},
  ];

  final List<Map<String, String>> _allApps = [
    {'title': 'System Modification Ringi'},
    {'title': 'Expense Approval Ringi'},
    {'title': 'Open Contract Approval Ringi'},
    {'title': 'Close Contract Approval Ringi'},
    {'title': 'Clock-in/out Correction'},
  ];

  String _leftMenuSelected = 'Provided by other service providers';
  int _selectedIndex = 1;
  String? _language;
  int _timeoutMinutes = 30;
  // Approval Center state and sample data
  final Map<String, List<String>> _centerSections = {
    'To-do': ['System Modification Ringi', 'Expense Approval Ringi', 'Close Contract Approval Ringi'],
    'Done': ['Open Contract Approval Ringi'],
    'CC': ['Clock-in/out Correction'],
    'Submitted': ['System Modification Ringi'],
  };

  final Map<String, List<Map<String, String>>> _sampleCases = {
    'System Modification Ringi': List.generate(6, (i) => {
      'id': 'SMR-${1000 + i}',
      'title': 'System Modification Request #${i + 1}',
      'subtitle': 'Requester ${i + 1}',
      'status': i % 3 == 0 ? 'Under Review' : (i % 3 == 1 ? 'Pending' : 'Completed'),
      'time': '${i + 1}h ago'
    }),
    'Expense Approval Ringi': List.generate(4, (i) => {
      'id': 'EAR-${2000 + i}',
      'title': 'Expense Approval #${i + 1}',
      'subtitle': 'Employee ${i + 1}',
      'status': 'Pending',
      'time': '${i + 2}h ago'
    }),
    'Close Contract Approval Ringi': List.generate(5, (i) => {
      'id': 'CCR-${3000 + i}',
      'title': 'Close Contract #${i + 1}',
      'subtitle': 'Person ${i + 1}',
      'status': 'Pending',
      'time': '${i + 3}h ago'
    }),
    'Open Contract Approval Ringi': List.generate(2, (i) => {
      'id': 'OCR-${4000 + i}',
      'title': 'Open Contract #${i + 1}',
      'subtitle': 'Requester ${i + 1}',
      'status': 'Completed',
      'time': '${i + 4}h ago'
    }),
    'Clock-in/out Correction': List.generate(3, (i) => {
      'id': 'CIC-${5000 + i}',
      'title': 'Clock Correction #${i + 1}',
      'subtitle': 'Staff ${i + 1}',
      'status': 'CC',
      'time': '${i + 1}d ago'
    }),
  };

  // cache for cases loaded from backend keyed by app title
  final Map<String, List<Map<String, dynamic>>> _loadedCases = {};

  String _selectedCenterSection = 'To-do';
  String _selectedCenterApp = 'System Modification Ringi';
  Map<String, dynamic>? _selectedCase;
  bool _loadingCase = false;
  bool _acting = false;
  final TextEditingController _commentController = TextEditingController();
  bool _postingComment = false;
  // resizable panels with default widths: left 250px, middle 350px; right auto-fills remainder ..
  double _leftPanelWidth = 250;
  double _middlePanelWidth = 350;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadCloseContractCases() async {
    try {
      final items = await CloseContractApi.listRequests(includeActions: true);
      if (!mounted) {
        return;
      }
      setState(() {
        // store items as-case list; normalize some display fields
        _loadedCases['Close Contract Approval Ringi'] = items.map((it) {
          final m = Map<String, dynamic>.from(it);
          m['title'] = m['contract_no'] ?? m['title'] ?? '';
          m['subtitle'] = m['person_in_charge'] ?? m['created_by_name'] ?? '';
          m['status'] = m['status'] ?? '';
          // prefer the last update datetime for listing and relative time calculations
          m['time'] = m['updated_at'] ?? m['created_at'] ?? '';
          return m;
        }).toList();
      });
    } catch (e) {
      // ignore load errors for now; keep sample data
    }
  }

  Future<void> _loadPrefs() async {
    final lang = await Session.getLanguage();
    final t = await Session.getTimeoutMinutes();
    if (!mounted) return;
    setState(() {
      _language = lang;
      if (t != null) _timeoutMinutes = t;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 900;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Row(
          children: [
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
                            Expanded(child: SelectableText('LALCO', style: const TextStyle(fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ),
                      const Divider(),
                      _navItem(Icons.dashboard, 'Overview', 0, '/home_page.dart'),
                      _navItem(Icons.check_circle_outline, 'Approvals', 1, '/approvals'),
                      _navItem(Icons.bar_chart, 'Reports', 2, '/reports_page.dart'),
                      _navItem(Icons.people, 'Users', 3, '/admin_user_page.dart'),
                      const Spacer(),
                    ],
                  ),
                ),
              ),
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
                        const SizedBox(width: 8),
                        SelectableText('Approvals', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Row(
                          children: [
                            IconButton(icon: const Icon(Icons.search), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
                            IconButton(icon: const Icon(Icons.settings), onPressed: () {}),
                          ],
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTapDown: (details) => _showProfileMenu(details.globalPosition),
                          child: Row(
                            children: [
                              CircleAvatar(child: Text('A')),
                              if (_language != null) ...[
                                const SizedBox(width: 8),
                                Text(_language ?? '', style: const TextStyle(color: Colors.black54)),
                                const SizedBox(width: 8),
                                Text('$_timeoutMinutes min', style: const TextStyle(color: Colors.black54, fontSize: 12)),
                              ]
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                  ),
                  // Tabs
                  Material(
                    color: Colors.white,
                        child: TabBar(
                      tabs: const [
                        Tab(text: 'Submit Request'),
                        Tab(text: 'Approval Center'),
                        Tab(text: 'Data Management'),
                      ],
                      labelColor: Colors.indigo,
                      unselectedLabelColor: Colors.black87,
                      indicatorColor: Colors.indigo,
                      isScrollable: true,
                    ),
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildMainContent(context),
                        _buildApprovalCenter(),
                        Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [SelectableText('Data Management', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 12), SelectableText('Data management tools and imports/exports will appear here.')] ))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalCenter() {
    // Approval Center: three-column layout (sections/apps list / cases list / details)
    final sectionList = _centerSections.keys.toList();
    // ensure selected app exists for selected section
    final appsForSection = _centerSections[_selectedCenterSection] ?? [];
    if (!appsForSection.contains(_selectedCenterApp) && appsForSection.isNotEmpty) {
      _selectedCenterApp = appsForSection.first;
      _selectedCase = null;
    }

    // prefer backend-loaded cases for Close Contract app if available
    List<Map<String, dynamic>> cases = [];
    if (_selectedCenterApp == 'Close Contract Approval Ringi') {
      if (_loadedCases.containsKey(_selectedCenterApp)) {
        cases = _loadedCases[_selectedCenterApp]!;
      } else {
        // fallback to sample data shaped as dynamic maps
        cases = (_sampleCases[_selectedCenterApp] ?? []).map((m) => m.map((k, v) => MapEntry(k, v))).toList();
        // trigger async load
        _loadCloseContractCases();
      }
    } else {
      cases = (_sampleCases[_selectedCenterApp] ?? []).map((m) => m.map((k, v) => MapEntry(k, v))).toList();
    }

    return LayoutBuilder(builder: (context, constraints) {
      final total = constraints.maxWidth;
      const minLeft = 200.0;
      const minMiddle = 260.0;
      const minRight = 240.0;
      const gutter = 16.0; // two 8px drag handles

      // Clamp widths to keep panels visible and leave room for the right pane.
      _leftPanelWidth = _leftPanelWidth.clamp(minLeft, total - _middlePanelWidth - minRight - gutter);
      _middlePanelWidth = _middlePanelWidth.clamp(minMiddle, total - _leftPanelWidth - minRight - gutter);

      // rightWidth is no longer used (right panel is Expanded)

      // Left panel
      final leftPanel = Container(
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.all(12.0), child: TextField(decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Search', border: OutlineInputBorder(borderRadius: BorderRadius.circular(6.0))))),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(8),
                itemCount: sectionList.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, si) {
                  final section = sectionList[si];
                  final apps = _centerSections[section] ?? [];
                  final expanded = section == _selectedCenterSection;
                  return Material(
                    color: expanded ? Colors.indigo.withAlpha(20) : Colors.transparent,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        InkWell(
                          onTap: () async {
                            setState(() {
                              _selectedCenterSection = section;
                              _selectedCenterApp = apps.isNotEmpty ? apps.first : '';
                              _selectedCase = null;
                            });
                            if (_selectedCenterApp == 'Close Contract Approval Ringi') await _loadCloseContractCases();
                          },
                            child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
                            child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [SelectableText(section, style: TextStyle(fontWeight: FontWeight.bold, color: expanded ? Colors.indigo : Colors.black87)), Text('${apps.length}')]),
                          ),
                        ),
                        if (expanded)
                          Column(
                            children: apps.map((a) {
                              final sel = a == _selectedCenterApp;
                                return ListTile(
                                dense: true,
                                title: SelectableText(a, style: TextStyle(color: sel ? Colors.indigo : Colors.black87)),
                                onTap: () async {
                                  setState(() {
                                    _selectedCenterApp = a;
                                    _selectedCase = null;
                                  });
                                  if (a == 'Close Contract Approval Ringi') {
                                    await _loadCloseContractCases();
                                  }
                                },
                                selected: sel,
                                selectedTileColor: Colors.indigo.withAlpha(30),
                              );
                            }).toList(),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

      // Middle panel
      final middlePanel = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [SelectableText(_selectedCenterApp, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), DropdownButton<String>(value: 'All Time', items: const [DropdownMenuItem(value: 'All Time', child: Text('All Time'))], onChanged: (_) {}), const SizedBox(width: 8), IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh', onPressed: _selectedCenterApp == 'Close Contract Approval Ringi' ? () => _loadCloseContractCases() : null)])),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F7FB),
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                itemCount: cases.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = cases[i];
                  final selected = _selectedCase != null && _selectedCase!['id'] == c['id'];
                  return GestureDetector(
                    onTap: () async {
                      // if item has numeric id, fetch full details from backend
                      final id = c['id'];
                      int? reqId;
                      if (id is int) {
                        reqId = id;
                      } else if (id is String) {
                        reqId = int.tryParse(id);
                      }
                      if (reqId != null) {
                        setState(() { _loadingCase = true; _selectedCase = null; });
                        try {
                          final detailed = await CloseContractApi.getRequest(reqId);
                          // fetch comments separately to keep payload small
                          List<Map<String, dynamic>> comments = [];
                          try {
                            final cm = await CloseContractApi.listComments(reqId);
                            comments = cm;
                          } catch (_) {
                            comments = [];
                          }
                          if (!mounted) {
                            return;
                          }
                          final map = Map<String, dynamic>.from(detailed);
                          map['comments'] = comments;
                          setState(() { _selectedCase = map; });
                        } catch (e) {
                          // fallback to shallow case
                          if (!mounted) {
                            return;
                          }
                          setState(() { _selectedCase = Map<String, dynamic>.from(c); });
                        } finally {
                          if (mounted) setState(() { _loadingCase = false; });
                        }
                      } else {
                        setState(() { _selectedCase = Map<String, dynamic>.from(c); });
                      }
                    },
                          child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: selected ? Colors.white : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: selected ? Colors.indigo : Colors.grey.shade300)),
                      child: Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.pink.shade400, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SelectableText(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), SelectableText(c['subtitle'] ?? '', style: const TextStyle(color: Colors.grey))])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(c['status'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(_relativeTime(c['updated_at'] ?? c['created_at'] ?? c['time']), style: const TextStyle(color: Colors.grey, fontSize: 12))]),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      );

      // Right panel: scrollable detailed view for selected case
      Widget rightPanel;
      if (_loadingCase) {
        rightPanel = Container(color: Colors.white, child: const Center(child: Padding(padding: EdgeInsets.all(24.0), child: CircularProgressIndicator())));
      } else if (_selectedCase == null) {
        rightPanel = Container(
          color: Colors.white,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [SelectableText('Select a case to view details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SelectableText('Case details will appear here.')]),
            ),
          ),
        );
      } else {
        // Right panel with internal TabBar (Details / Approval Record / Comments)
        rightPanel = Container(
          color: Colors.white,
          child: DefaultTabController(
            length: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: SelectableText(_selectedCenterApp, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
                          if ((_selectedCase!['status'] ?? '').toString().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(color: Colors.indigo.withAlpha(30), borderRadius: BorderRadius.circular(12)),
                              child: Text((_selectedCase!['status'] ?? '').toString(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // show submitted timestamp only in header; person in charge and manager are shown in the Details table
                      Row(children: [
                        SelectableText('Submitted: ${_formatDateTime(_selectedCase!['created_at'])}', style: const TextStyle(color: Colors.grey)),
                      ]),
                      if ((_selectedCase!['updated_at'] ?? '').toString().isNotEmpty && (_selectedCase!['updated_at']?.toString() != _selectedCase!['created_at']?.toString()))
                        Row(children: [SelectableText('Updated: ${_formatDateTime(_selectedCase!['updated_at'])}', style: const TextStyle(color: Colors.grey))]),
                      const SizedBox(height: 8),
                      TabBar(
                        tabs: const [Tab(text: 'Details'), Tab(text: 'Approval Record'), Tab(text: 'Comments')],
                        labelColor: Colors.indigo,
                        unselectedLabelColor: Colors.black54,
                        indicatorColor: Colors.indigo,
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Tab content
                Expanded(
                  child: TabBarView(
                    children: [
                      // Details tab: two-column key/value table + payment history DataTable
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            Table(
                              columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                              children: [
                                _buildKeyValueRow('Collection type', '${_selectedCase!['collection_type'] ?? ''}'),
                                _buildKeyValueRow('Contract No', '${_selectedCase!['contract_no'] ?? _selectedCase!['id'] ?? ''}'),
                                _buildKeyValueRow('Person in Charge', '${_selectedCase!['person_in_charge'] ?? ''}'),
                                _buildKeyValueRow('Manager', '${_selectedCase!['manager_in_charge'] ?? ''}'),
                                _buildKeyValueRow('Lasted contract information', '${_selectedCase!['last_contract_info'] ?? ''}'),
                                if (_paidTermRatio(_selectedCase!).isNotEmpty) _buildKeyValueRow('Paid Term / Total Term', _paidTermRatio(_selectedCase!)),
                                _buildKeyValueRow('Full paid date (or first due date if unpaid)', '${_selectedCase!['full_paid_date'] ?? ''}'),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // render schedule-style payment history from DB fields when available
                            if ((_selectedCase!['s_count'] != null) || (_selectedCase!['a_count'] != null) || (_selectedCase!['b_count'] != null) || (_selectedCase!['c_count'] != null) || (_selectedCase!['f_count'] != null)) ...[
                              const Text('Payment history', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  headingRowHeight: 28,
                                  dataRowMinHeight: 28,
                                  dataRowMaxHeight: 28,
                                  horizontalMargin: 28,
                                  columnSpacing: 28,
                                  columns: const [
                                    DataColumn(label: Text('S at 5th(time)')),
                                    DataColumn(label: Text('A at 10th(time)')),
                                    DataColumn(label: Text('B at 20th(time)')),
                                    DataColumn(label: Text('C at 31st(time)')),
                                    DataColumn(label: Text('F after 1 month(time)')),
                                  ],
                                  rows: [
                                    DataRow(cells: [
                                      DataCell(Text('${_selectedCase!['s_count'] ?? ''}')),
                                      DataCell(Text('${_selectedCase!['a_count'] ?? ''}')),
                                      DataCell(Text('${_selectedCase!['b_count'] ?? ''}')),
                                      DataCell(Text('${_selectedCase!['c_count'] ?? ''}')),
                                      DataCell(Text('${_selectedCase!['f_count'] ?? ''}')),
                                    ])
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            // Remaining Amount (from DB)
                            if ((_selectedCase!['principal_remaining'] != null) || (_selectedCase!['interest_remaining'] != null) || (_selectedCase!['penalty_remaining'] != null) || (_selectedCase!['others_remaining'] != null)) ...[
                              const SizedBox(height: 6),
                              const SelectableText('Remaining Amount', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Table(
                                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  _buildKeyValueRow('Principal remaining', _formatAmount(_selectedCase!['principal_remaining'] ?? '')),
                                  _buildKeyValueRow('Interest remaining', _formatAmount(_selectedCase!['interest_remaining'] ?? '')),
                                  _buildKeyValueRow('Penalty remaining', _formatAmount(_selectedCase!['penalty_remaining'] ?? '')),
                                  _buildKeyValueRow('Other remaining', _formatAmount(_selectedCase!['others_remaining'] ?? '')),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Willing to pay amount (from DB)
                            if ((_selectedCase!['principal_willing'] != null) || (_selectedCase!['interest_willing'] != null) || (_selectedCase!['interest_months'] != null) || (_selectedCase!['penalty_willing'] != null) || (_selectedCase!['others_willing'] != null)) ...[
                              const SelectableText('Willing to pay amount', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 6),
                              Table(
                                columnWidths: const {0: IntrinsicColumnWidth(), 1: FlexColumnWidth()},
                                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                                children: [
                                  _buildKeyValueRow('Principal (willing)', _formatAmount(_selectedCase!['principal_willing'] ?? '')),
                                  _buildKeyValueRow('Interest (willing)', _formatAmount(_selectedCase!['interest_willing'] ?? '')),
                                  _buildKeyValueRow('Interest months', '${_selectedCase!['interest_months'] ?? ''}'),
                                  _buildKeyValueRow('Penalty (willing)', _formatAmount(_selectedCase!['penalty_willing'] ?? '')),
                                  _buildKeyValueRow('Other (willing)', _formatAmount(_selectedCase!['others_willing'] ?? '')),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Remark after payment history — render as larger readable block
                            if ((_selectedCase!['remark'] ?? '').toString().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SelectableText('Remark', style: TextStyle(color: Colors.grey)),
                                    const SizedBox(height: 6),
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12.0),
                                      decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(6)),
                                      child: SelectableText('${_selectedCase!['remark']}', style: const TextStyle(height: 1.4)),
                                    ),
                                  ],
                                ),
                              ),

                            // Attachments (from DB: attachment_url)
                            // Attachments (flexible extraction from multiple DB fields)
                            if ((_selectedCase!['remark'] ?? '').toString().isNotEmpty)
                              Builder(builder: (ctx) {
                                final urls = _extractAttachmentUrls(_selectedCase!);
                                if (urls.isEmpty) return const SizedBox.shrink();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    const SelectableText('Attachment', style: TextStyle(fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 6),
                                    for (final u in urls)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 6.0),
                                        child: Row(children: [
                                          Expanded(child: SelectableText(_attachmentLabel(u), maxLines: 2, style: const TextStyle(color: Colors.blue))),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            tooltip: 'Open',
                                            onPressed: () async {
                                              await _showAttachmentPreview(u);
                                            },
                                            icon: const Icon(Icons.open_in_new, size: 18),
                                          ),
                                          IconButton(
                                            tooltip: 'Copy URL',
                                            onPressed: () async {
                                              final full = _normalizeAttachmentUrl(u);
                                              await Clipboard.setData(ClipboardData(text: full));
                                              if (!mounted) return;
                                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Attachment URL copied')));
                                            },
                                            icon: const Icon(Icons.copy, size: 18),
                                          ),
                                        ]),
                                      ),
                                    const SizedBox(height: 12),
                                  ],
                                );
                              }),
                          ],
                        ),
                      ),

                      // Approval Record tab: render a table with Step Name, Approver, Result, Comments, Time
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            _buildApprovalRecordTable(((_selectedCase!['actions'] ?? _selectedCase!['approval_records']) ?? []) as List),
                          ],
                        ),
                      ),

                      // Comments tab
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 4),
                            // input area
                            Row(children: [
                              Expanded(child: TextField(controller: _commentController, maxLines: 3, decoration: const InputDecoration(hintText: 'Add a comment', border: UnderlineInputBorder()))),
                              const SizedBox(width: 8),
                              ElevatedButton(onPressed: _postingComment ? null : _postComment, style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))), child: _postingComment ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send')),
                            ]),
                            const SizedBox(height: 12),
                            if (((_selectedCase!['comments'] ?? []) as List).isEmpty)
                              const Text('No comments', style: TextStyle(color: Colors.grey))
                            else
                              for (final c in (_selectedCase!['comments'] as List))
                                Card(
                                  margin: const EdgeInsets.symmetric(vertical: 6),
                                  child: ListTile(
                                    title: Text(c is Map ? (c['user_name'] ?? c['user_email'] ?? '').toString() : ''),
                                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(c is Map ? (c['text'] ?? c['comment'] ?? c.toString()).toString() : c.toString())]),
                                    trailing: Builder(builder: (ctx) {
                                      final created = c is Map ? (c['created_at'] ?? c['at'] ?? null) : null;
                                      final abs = _formatDateTime(created);
                                      final rel = _relativeTime(created);
                                      return Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(abs, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                          const SizedBox(height: 4),
                                          Text(rel, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                                        ],
                                      );
                                    }),
                                  ),
                                ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Fixed bottom action bar
                const Divider(height: 1),
                Container(
                  height: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.white,
                  child: Row(
                    children: [
                      Expanded(child: OutlinedButton(onPressed: _acting ? null : _openResubmit, child: const Text('Resubmit'))),
                      const SizedBox(width: 8),
                      Builder(builder: (ctx) {
                        final status = (_selectedCase?['status'] ?? '').toString().toLowerCase();
                        final finalized = (status == 'approved' || status == 'rejected');
                        return Expanded(child: ElevatedButton(onPressed: (_acting || finalized) ? null : () => _confirmAndPerform('approve'), child: _acting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Approve')));
                      }),
                      const SizedBox(width: 8),
                      Builder(builder: (ctx) {
                        final status = (_selectedCase?['status'] ?? '').toString().toLowerCase();
                        final finalized = (status == 'approved' || status == 'rejected');
                        return Expanded(child: ElevatedButton(onPressed: (_acting || finalized) ? null : () => _confirmAndPerform('send_back'), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange), child: _acting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Send Back')));
                      }),
                      const SizedBox(width: 8),
                      Builder(builder: (ctx) {
                        final status = (_selectedCase?['status'] ?? '').toString().toLowerCase();
                        final finalized = (status == 'approved' || status == 'rejected');
                        return Expanded(child: ElevatedButton(onPressed: (_acting || finalized) ? null : () => _confirmAndPerform('reject'), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: _acting ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Reject')));
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return Row(
        children: [
          SizedBox(width: _leftPanelWidth, child: leftPanel),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => setState(() {
                _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(minLeft, total - _middlePanelWidth - minRight - gutter);
              }),
              child: Container(width: 8, color: Colors.transparent, child: Center(child: Container(width: 2, height: double.infinity, color: Colors.grey.shade300))),
            ),
          ),
          SizedBox(width: _middlePanelWidth, child: middlePanel),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => setState(() {
                _middlePanelWidth = (_middlePanelWidth + d.delta.dx).clamp(minMiddle, total - _leftPanelWidth - minRight - gutter);
              }),
              child: Container(width: 8, color: Colors.transparent, child: Center(child: Container(width: 2, height: double.infinity, color: Colors.grey.shade300))),
            ),
          ),
          Expanded(child: rightPanel),
        ],
      );
    });
  }

  Widget _buildMainContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearch(),
          const SizedBox(height: 18),
          _buildRecommended(),
          const SizedBox(height: 18),
          Expanded(child: _buildAllApplications(context)),
        ],
      ),
    );
  }

  Widget _buildSearch() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search),
        hintText: 'Please enter the name of the application',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
      ),
      onChanged: (v) => setState(() {}),
    );
  }

  Widget _buildRecommended() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText('Recommended', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        SizedBox(
          height: 84,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _recommended.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final title = _recommended[index]['title']!;
              return GestureDetector(
                onTap: () => _openApp(title),
                child: Container(
                  width: 260,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 1))],
                  ),
                      child: Row(
                    children: [
                      _pinkAvatar(),
                      const SizedBox(width: 12),
                      Expanded(child: SelectableText(title, style: const TextStyle(fontSize: 14))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllApplications(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(6),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _leftMenuButton('Provided by other service providers'),
              const SizedBox(height: 8),
              _leftMenuButton('Provided by our company'),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SelectableText('Provided by other service providers', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(builder: (context, constraints) {
                  final crossAxisCount = (constraints.maxWidth / 300).floor().clamp(1, 4);
                  return GridView.builder(
                    itemCount: _filteredApps().length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 3.6,
                    ),
                    itemBuilder: (context, index) {
                      final title = _filteredApps()[index]['title']!;
                      return GestureDetector(
                        onTap: () => _openApp(title),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              _pinkAvatar(),
                              const SizedBox(width: 12),
                              Expanded(child: SelectableText(title)),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              const SizedBox(height: 8),
              Center(child: SelectableText('All applications have been displayed', style: TextStyle(color: Colors.grey.shade600))),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, String>> _filteredApps() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _allApps;
    return _allApps.where((a) => a['title']!.toLowerCase().contains(q)).toList();
  }

  Widget _leftMenuButton(String title) {
    final selected = _leftMenuSelected == title;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.blue.shade50 : Colors.transparent,
        foregroundColor: Colors.black87,
        elevation: 0,
        alignment: Alignment.centerLeft,
      ),
      onPressed: () => setState(() {
        _leftMenuSelected = title;
      }),
      child: SelectableText(title, style: TextStyle(color: selected ? Colors.blue : Colors.black87)),
    );
  }

  Widget _pinkAvatar() {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: Colors.pink.shade400, borderRadius: BorderRadius.circular(6)),
      child: const Icon(Icons.person, color: Colors.white, size: 22),
    );
  }

  TableRow _buildKeyValueRow(String key, String value) {
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: SelectableText(key, style: const TextStyle(color: Colors.grey)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: SelectableText(value),
        ),
      ],
    );
  }

  String _formatDateTime(dynamic src) {
    if (src == null) {
      return '';
    }
    try {
      DateTime dt;
      if (src is DateTime) {
        dt = src;
      } else {
        dt = DateTime.tryParse(src.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
      final l = dt.toLocal();
      String two(int n) => n.toString().padLeft(2, '0');
      return '${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}:${two(l.second)}';
    } catch (_) {
      return src.toString();
    }
  }

  String _relativeTime(dynamic src) {
    if (src == null) return '';
    DateTime dt;
    try {
      if (src is DateTime) {
        dt = src.toLocal();
      } else {
        dt = DateTime.tryParse(src.toString())?.toLocal() ?? DateTime.fromMillisecondsSinceEpoch(0);
      }
    } catch (_) {
      return src.toString();
    }

    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} minute${diff.inMinutes == 1 ? '' : 's'} ago';
    if (diff.inHours < 24) return '${diff.inHours} hour${diff.inHours == 1 ? '' : 's'} ago';
    if (diff.inDays < 30) return '${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    // fallback to short date
    try {
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
    } catch (_) {
      return src.toString();
    }
  }

  // Format numeric amounts with thousand separators while preserving decimals.
  String _formatAmount(dynamic v) {
    if (v == null) return '';
    final s = v.toString().trim();
    if (s.isEmpty) return '';
    final cleaned = s.replaceAll(',', '');
    // accept integers or decimals, optionally negative
    final m = RegExp(r'^-?\d+(?:\.\d+)?$').firstMatch(cleaned);
    if (m == null) return s; // not a plain number, return original
    final negative = cleaned.startsWith('-');
    final parts = cleaned.replaceFirst('-', '').split('.');
    final intPart = parts[0];
    final intFormatted = intPart.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
    if (parts.length > 1) {
      return (negative ? '-' : '') + '$intFormatted.${parts[1]}';
    }
    return (negative ? '-' : '') + intFormatted;
  }

  // Normalize attachment URL to an absolute URL using the same host logic as the API.
  String _normalizeAttachmentUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return s;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    if (s.startsWith('//')) return 'https:$s';
    final host = kIsWeb
        ? 'http://localhost:5000'
        : (defaultTargetPlatform == TargetPlatform.android ? 'http://10.0.2.2:5000' : 'http://localhost:5000');
    if (s.startsWith('/')) return '$host$s';
    return '$host/${s}';
  }

  // removed legacy fallbacks for paid_term_total/paid_term_display — use DB fields only

  String _paidTermRatio(Map<String, dynamic> c) {
    final paid = (c['paid_term']?.toString().trim() ?? '');
    final total = (c['total_term']?.toString().trim() ?? '');
    if (paid.isEmpty && total.isEmpty) {
      return '';
    }
    if (paid.isEmpty) {
      return '/ $total';
    }
    if (total.isEmpty) {
      return paid;
    }
    return '$paid / $total';
  }

  // Extract attachment URLs from a selected case record. Supports multiple field names and formats.
  List<String> _extractAttachmentUrls(Map<String, dynamic> c) {
    final candidates = ['attachment_url', 'attachment', 'attachments', 'attachment_urls', 'files', 'file_urls'];
    dynamic raw;
    for (final k in candidates) {
      if (c.containsKey(k) && c[k] != null) {
        raw = c[k];
        break;
      }
    }
    if (raw == null) return [];

    final List<String> urls = [];
    if (raw is List) {
      for (final e in raw) {
        if (e == null) continue;
        if (e is Map && (e['url'] ?? e['attachment_url'] ?? e['path']) != null) {
          urls.add((e['url'] ?? e['attachment_url'] ?? e['path']).toString());
        } else {
          urls.add(e.toString());
        }
      }
      return urls.where((s) => s.trim().isNotEmpty).toList();
    }

    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return [];
      // try JSON array
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          for (final e in decoded) {
            if (e == null) continue;
            if (e is Map && (e['url'] ?? e['attachment_url'] ?? e['path']) != null) {
              urls.add((e['url'] ?? e['attachment_url'] ?? e['path']).toString());
            } else {
              urls.add(e.toString());
            }
          }
          return urls.where((s) => s.trim().isNotEmpty).toList();
        }
      } catch (_) {}

      // comma-separated fallback
      if (s.contains(',')) {
        urls.addAll(s.split(',').map((p) => p.trim()).where((p) => p.isNotEmpty));
        return urls;
      }

      // single url
      return [s];
    }

    // Map-like fallback
    if (raw is Map) {
      if ((raw['url'] ?? raw['attachment_url'] ?? raw['path']) != null) {
        return [(raw['url'] ?? raw['attachment_url'] ?? raw['path']).toString()];
      }
    }

    return [];
  }

  String _attachmentLabel(String url) {
    try {
      final u = Uri.tryParse(url);
      if (u != null && u.pathSegments.isNotEmpty) return u.pathSegments.last;
    } catch (_) {}
    return url;
  }

  Widget _buildApprovalRecordTable(List actions) {
    if (actions.isEmpty) {
      return const Text('No approval records available', style: TextStyle(color: Colors.grey));
    }

    List<Widget> cards = [];
    int ri = 0;
    for (final aRaw in actions) {
      final a = aRaw is Map ? Map<String, dynamic>.from(aRaw) : {'result': aRaw.toString()};
      final stepName = (a['step_label'] ?? a['step'] ?? a['action'] ?? a['type'] ?? '').toString();
      final approverName = (a['actor_name'] ?? a['actor'] ?? a['by'] ?? a['actor_email'] ?? '').toString();
      final approverRole = (a['role'] ?? '').toString();
      final result = (a['result'] ?? '').toString();
      final comment = (a['comment'] ?? a['comments'] ?? a['remark'] ?? '').toString();
      final actedAt = (a['acted_at'] ?? a['at'] ?? a['timestamp'] ?? a['created_at'] ?? '').toString();

      // color accent
      final rl = result.toLowerCase();
      Color accent;
      if (rl.contains('approve')) {
        accent = Colors.green.shade400;
      } else if (rl.contains('submitted')) {
        accent = Colors.blue.shade400;
      } else if (rl.contains('reject')) {
        accent = Colors.red.shade400;
      } else if (rl.contains('send') || rl.contains('sent_back')) {
        accent = Colors.orange.shade400;
      } else if (rl.contains('review') || rl.contains('under_review') || rl.contains('under review')) {
        accent = Colors.indigo.shade400;
      } else {
        accent = ri % 2 == 0 ? Colors.grey.shade200 : Colors.grey.shade100;
      }

      cards.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6.0),
        child: Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))]),
          child: Row(children: [
            Container(width: 6, height: 86, decoration: BoxDecoration(color: accent, borderRadius: const BorderRadius.only(topLeft: Radius.circular(8), bottomLeft: Radius.circular(8)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12.0),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _approverAvatar(approverName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(stepName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 6),
                      Text(approverName.isNotEmpty ? approverName : (approverRole.isNotEmpty ? approverRole : '-'), style: const TextStyle(color: Colors.grey)),
                      if (comment.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(comment, style: const TextStyle(), maxLines: 3, overflow: TextOverflow.ellipsis),
                      ],
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    _resultBadge(result),
                    const SizedBox(height: 8),
                    Text(_relativeTime(actedAt), style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(_formatDateTime(actedAt), style: const TextStyle(color: Colors.grey, fontSize: 11)),
                  ])
                ]),
              ),
            ),
          ]),
        ),
      ));

      ri++;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: cards);
  }

  Widget _approverAvatar(String nameOrEmail) {
    final s = (nameOrEmail ?? '').toString();
    String initials = '';
    if (s.isNotEmpty) {
      final parts = s.split(RegExp(r'[\s@._-]+')).where((p) => p.isNotEmpty).toList();
      if (parts.length >= 2) {
        initials = '${parts[0][0].toUpperCase()}${parts[1][0].toUpperCase()}';
      } else if (parts.isNotEmpty) {
        initials = parts[0].substring(0, 1).toUpperCase();
      }
    }
    return CircleAvatar(radius: 16, backgroundColor: Colors.pink.shade400, child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 12)));
  }

  Widget _resultBadge(String result) {
    final r = (result ?? '').toString().toLowerCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.black87;
    if (r.contains('approve') || r == 'approved') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade800;
    } else if (r.contains('submitted') || r == 'submitted') {
      bg = Colors.green.shade50;
      fg = Colors.green.shade800;
    } else if (r.contains('review') || r.contains('under_review') || r.contains('under review')) {
      bg = Colors.blue.shade50;
      fg = Colors.blue.shade800;
    } else if (r.contains('send') || r.contains('sent_back') || r.contains('send_back')) {
      bg = Colors.orange.shade100;
      fg = Colors.orange.shade800;
    } else if (r.contains('reject') || r == 'rejected') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade800;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(result.isNotEmpty ? result[0].toUpperCase() + result.substring(1) : '-', style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }

  Future<void> _showAttachmentPreview(String rawUrl) async {
    final full = _normalizeAttachmentUrl(rawUrl);
    final low = rawUrl.split('?').first.split('/').last.toLowerCase();
    final ext = low.contains('.') ? low.split('.').last : '';

    // Image preview
    if (['png', 'jpg', 'jpeg', 'gif', 'bmp', 'webp'].contains(ext)) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: InteractiveViewer(
            child: Image.network(
              full,
              fit: BoxFit.contain,
              errorBuilder: (c, e, s) => const Padding(padding: EdgeInsets.all(16), child: Text('Failed to load image')),
            ),
          ),
        ),
      );
      return;
    }

    // PDF preview
    if (ext == 'pdf') {
      // On web, open externally
      if (kIsWeb) {
        final uri = Uri.tryParse(full);
        if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }

      try {
        final resp = await http.get(Uri.parse(full));
        if (resp.statusCode != 200) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to fetch PDF')));
          return;
        }
        final bytes = resp.bodyBytes;
        final dir = await getTemporaryDirectory();
        final file = File('${dir.path}/attachment_${DateTime.now().millisecondsSinceEpoch}.pdf');
        await file.writeAsBytes(bytes);
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (ctx) => Dialog(
            insetPadding: const EdgeInsets.all(12),
            child: SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              height: MediaQuery.of(context).size.height * 0.8,
              child: PDFView(filePath: file.path),
            ),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading PDF: $e')));
      }
      return;
    }

    // fallback: open externally
    final uri = Uri.tryParse(full);
    if (uri != null) {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open URL')));
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
    }
  }

  Future<void> _confirmAndPerform(String result) async {
    if (_selectedCase == null) {
      return;
    }
    final commentController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result == 'approve' ? 'Approve' : (result == 'reject' ? 'Reject' : 'Send Back')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Optional comment:'),
            TextField(controller: commentController, maxLines: 3),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) {
      return;
    }
    await _performAction(result, comment: commentController.text.trim());
  }

  Future<void> _performAction(String result, {String? comment}) async {
    if (_selectedCase == null) {
      return;
    }
    int? reqId;
    final id = _selectedCase!['id'];
    if (id is int) {
      reqId = id;
    } else if (id is String) {
      reqId = int.tryParse(id);
    }
    if (reqId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot perform action: invalid request id')));
      return;
    }

    setState(() { _acting = true; });
    try {
      final user = await Session.loadUser() ?? {};
      final actorEmail = (user['email'] ?? '').toString();
      final actorName = ('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}').trim();
      int? actorId;
      try { actorId = int.tryParse((user['id'] ?? user['actor_id'] ?? '').toString()); } catch (_) {}

      final updated = await CloseContractApi.actOnRequest(reqId, result: result, comment: comment?.isEmpty ?? true ? null : comment, actorEmail: actorEmail.isEmpty ? null : actorEmail, actorId: actorId, actorName: actorName.isEmpty ? null : actorName);
                        if (!mounted) {
                          return;
                        }
      setState(() { _selectedCase = Map<String, dynamic>.from(updated); });
      // refresh list
      if (_selectedCenterApp == 'Close Contract Approval Ringi') await _loadCloseContractCases();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Action applied')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) setState(() { _acting = false; });
    }
  }

  void _openResubmit() async {
    if (_selectedCase == null) return;
    int? reqId;
    final id = _selectedCase!['id'];
    if (id is int) reqId = id; else if (id is String) reqId = int.tryParse(id);
    if (reqId == null) return;
    await Navigator.of(context).push(MaterialPageRoute(builder: (ctx) => CloseContractApprovalPage(initialData: _selectedCase)));
    // after return, refresh the detailed case from backend to get updated actions
    try {
      final detailed = await CloseContractApi.getRequest(reqId);
      if (!mounted) return;
      final map = Map<String, dynamic>.from(detailed);
      // fetch comments too
      List<Map<String, dynamic>> comments = [];
      try { comments = await CloseContractApi.listComments(reqId); } catch (_) { comments = []; }
      map['comments'] = comments;
      setState(() { _selectedCase = map; });
      // refresh center list
      if (_selectedCenterApp == 'Close Contract Approval Ringi') await _loadCloseContractCases();
    } catch (e) {
      // ignore refresh errors
    }
  }

  Future<void> _postComment() async {
    if (_selectedCase == null) return;
    final id = _selectedCase!['id'];
    int? reqId;
    if (id is int) reqId = id;
    else if (id is String) reqId = int.tryParse(id);
    if (reqId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid request id')));
      return;
    }
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() { _postingComment = true; });
    try {
      final user = await Session.loadUser();
      final created = await CloseContractApi.createComment(reqId, text: text, userEmail: user?['email'], userId: user?['id'] is int ? user!['id'] as int : (user?['id'] is String ? int.tryParse(user!['id'].toString()) : null), userName: user == null ? null : ('${user['first_name'] ?? ''} ${user['last_name'] ?? ''}').trim());
      // append to local comments list
      final cur = List<Map<String, dynamic>>.from((_selectedCase!['comments'] ?? []) as List);
      cur.add(created);
      setState(() {
        _selectedCase!['comments'] = cur;
        _commentController.clear();
      });
      // refresh list view in center
      if (_selectedCenterApp == 'Close Contract Approval Ringi') await _loadCloseContractCases();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to post comment: $e')));
    } finally {
      if (mounted) setState(() { _postingComment = false; });
    }
  }

  Future<void> _openApp(String title) async {
    if (title == 'Close Contract Approval Ringi') {
      final user = await Session.loadUser();
      if (!mounted) {
        return;
      }
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CloseContractApprovalPage(user: user)));
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: SelectableText(title),
        content: SelectableText('This is a placeholder for the approval application. Implement specific flows here.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
          ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Open')),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, String route) {
    final selected = _selectedIndex == index;
    return InkWell(
      onTap: () async {
        setState(() => _selectedIndex = index);
        final user = await Session.loadUser();
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(context, route, arguments: user);
      },
      child: Container(
        color: selected ? Colors.indigo.withAlpha((0.08 * 255).round()) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: selected ? Colors.indigo : Colors.grey[700]),
            const SizedBox(width: 12),
            SelectableText(label, style: TextStyle(color: selected ? Colors.indigo : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Future<void> _showProfileMenu(Offset globalPos) async {
    try {
      final user = await Session.loadUser() ?? {};
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
        await _showLanguageMenu(globalPos);
      } else if (selected == 11) {
        await _chooseTimeout();
      } else if (selected == 20) {
        await _showSwitchAccountMenu(globalPos);
      } else if (selected == 30) {
        final ok = await _confirmLogout('Log Out');
        if (ok) _handleSwitchOrLogout();
      }
    } catch (_) {}
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

      if (!mounted) {
        return;
      }
      if (sel == null) {
        return;
      }

      if (sel.isEmpty) {
        if (!mounted) {
          return;
        }
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final email = (sel['email'] ?? '').toString();
      if (email.isEmpty) {
        return;
      }

      final saved = await Session.getSavedPasswordForEmail(email);
      if (saved == null) {
        final pwController = TextEditingController();
        bool rememberChoice = false;
        if (!mounted) {
          return;
        }
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
        if (ok != true) {
          return;
        }
      }

      try {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
      } catch (e) {
        if (!mounted) return;
      }
    } catch (_) {}
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

  void _handleSwitchOrLogout() async {
    await Session.clear();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, '/');
  }

}
