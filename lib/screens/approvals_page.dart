import 'package:flutter/material.dart';
import '../services/session.dart';

class ApprovalsPage extends StatefulWidget {
  const ApprovalsPage({Key? key}) : super(key: key);

  static Route route() => MaterialPageRoute(builder: (_) => const ApprovalsPage());

  @override
  _ApprovalsPageState createState() => _ApprovalsPageState();
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

  String _selectedCenterSection = 'To-do';
  String _selectedCenterApp = 'System Modification Ringi';
  Map<String, String>? _selectedCase;
  // resizable panels
  double _leftPanelWidth = 260;
  double _rightPanelWidth = 520;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
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

    final cases = _sampleCases[_selectedCenterApp] ?? [];

    return LayoutBuilder(builder: (context, constraints) {
      final total = constraints.maxWidth;
      const minMiddle = 220.0;
      const minLeft = 180.0;
      const minRight = 200.0;

      // clamp widths to sensible ranges so panels never overlap
      _leftPanelWidth = _leftPanelWidth.clamp(minLeft, total - _rightPanelWidth - minMiddle - 16);
      _rightPanelWidth = _rightPanelWidth.clamp(minRight, total - _leftPanelWidth - minMiddle - 16);

      final middleWidth = (total - _leftPanelWidth - _rightPanelWidth - 16).clamp(minMiddle, double.infinity);

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
                separatorBuilder: (_, __) => const SizedBox(height: 8),
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
                          onTap: () => setState(() {
                            _selectedCenterSection = section;
                            _selectedCenterApp = apps.isNotEmpty ? apps.first : '';
                            _selectedCase = null;
                          }),
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
                                onTap: () => setState(() {
                                  _selectedCenterApp = a;
                                  _selectedCase = null;
                                }),
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
          Container(padding: const EdgeInsets.all(12), color: Colors.white, child: Row(children: [SelectableText(_selectedCenterApp, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(), DropdownButton<String>(value: 'All Time', items: const [DropdownMenuItem(value: 'All Time', child: Text('All Time'))], onChanged: (_) {})])),
          Expanded(
            child: Container(
              color: const Color(0xFFF6F7FB),
              padding: const EdgeInsets.all(12),
              child: ListView.separated(
                itemCount: cases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final c = cases[i];
                  final selected = _selectedCase != null && _selectedCase!['id'] == c['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedCase = c),
                          child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: selected ? Colors.white : Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: selected ? Colors.indigo : Colors.grey.shade300)),
                      child: Row(
                        children: [
                          Container(width: 44, height: 44, decoration: BoxDecoration(color: Colors.pink.shade400, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.person, color: Colors.white)),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [SelectableText(c['title'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 4), SelectableText(c['subtitle'] ?? '', style: const TextStyle(color: Colors.grey))])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(c['status'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 6), Text(c['time'] ?? '', style: const TextStyle(color: Colors.grey, fontSize: 12))]),
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

      // Right panel
      final rightPanel = Container(
        color: Colors.white,
        child: _selectedCase == null
            ? Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(mainAxisSize: MainAxisSize.min, children: [SelectableText('Select a case to view details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8), SelectableText('Case details will appear here.')])) )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SelectableText(_selectedCase!['title'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: Colors.pink.shade400, borderRadius: BorderRadius.circular(6)), child: const Icon(Icons.person, color: Colors.white)), const SizedBox(width: 8), SelectableText(_selectedCase!['subtitle'] ?? '')]),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  SelectableText('Details', style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SelectableText('ID: ${'' /* placeholder for id */}${_selectedCase!['id'] ?? ''}'),
                  const SizedBox(height: 8),
                  SelectableText('Status: ${_selectedCase!['status'] ?? ''}'),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 12),
                  Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                    ElevatedButton.icon(onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approve clicked')));
                    }, icon: const Icon(Icons.check), label: const Text('Approve')),

                    OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reject clicked')));
                      },
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject', style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200)),
                    ),

                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Group Chat'))),
                      icon: const Icon(Icons.chat_bubble_outline, size: 18),
                      label: const Text('Group Chat'),
                    ),

                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CC'))),
                      icon: const Icon(Icons.alternate_email, size: 18),
                      label: const Text('CC'),
                    ),

                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Transfer'))),
                      icon: const Icon(Icons.swap_horiz, size: 18),
                      label: const Text('Transfer'),
                    ),

                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add Approver'))),
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add Approver'),
                    ),

                    TextButton.icon(
                      onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Send Back'))),
                      icon: const Icon(Icons.reply, size: 18),
                      label: const Text('Send Back'),
                    ),
                  ]),
                ]),
              ),
      );

      return Row(
        children: [
          SizedBox(width: _leftPanelWidth, child: leftPanel),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => setState(() {
                _leftPanelWidth = (_leftPanelWidth + d.delta.dx).clamp(minLeft, total - _rightPanelWidth - minMiddle - 16);
              }),
              child: Container(width: 8, color: Colors.transparent, child: Center(child: Container(width: 2, height: double.infinity, color: Colors.grey.shade300))),
            ),
          ),
          SizedBox(width: middleWidth, child: middlePanel),
          MouseRegion(
            cursor: SystemMouseCursors.resizeLeftRight,
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanUpdate: (d) => setState(() {
                _rightPanelWidth = (_rightPanelWidth - d.delta.dx).clamp(minRight, total - _leftPanelWidth - minMiddle - 16);
              }),
              child: Container(width: 8, color: Colors.transparent, child: Center(child: Container(width: 2, height: double.infinity, color: Colors.grey.shade300))),
            ),
          ),
          SizedBox(width: _rightPanelWidth, child: rightPanel),
        ],
      );
    });
  }

  Widget _buildApprovalListPlaceholder(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SelectableText(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SelectableText('This is the $title list placeholder. Implement list and controls here.'),
          ],
        ),
      ),
    );
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
            separatorBuilder: (_, __) => const SizedBox(width: 12),
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

  void _openApp(String title) {
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

      if (!mounted) return;
      if (sel == null) return;

      if (sel.isEmpty) {
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/');
        return;
      }

      final email = (sel['email'] ?? '').toString();
      if (email.isEmpty) return;

      final saved = await Session.getSavedPasswordForEmail(email);
      if (saved == null) {
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
