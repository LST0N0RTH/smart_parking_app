import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/slot.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const _primaryColor = Color(0xFF0000CD);
  static const _successColor = Color(0xFF228B22);
  static const _reservedColor = Color(0xFFFFC107);
  static const _warningColor = Color(0xFFE65100);
  static const _dangerColor = Color(0xFFCD2626);

  String _currentView = 'overview';
  bool _isLoading = false;
  bool _isGateCommandPending = false;
  bool _isReplying = false;
  bool _isAddingAdmin = false;
  bool _isRefreshingInbox = false;
  String? _viewError;
  Timer? _inboxTimer;
  final Set<String> _pendingRgbSlots = <String>{};

  Map<String, dynamic> _analytics = {};
  Map<String, dynamic> _hardwareErrorAnalytics = {};
  List<Slot> _slots = [];
  List<dynamic> _bookings = [];
  List<dynamic> _deviceStatuses = [];
  List<dynamic> _hardwareLogs = [];
  List<dynamic> _adminList = [];
  List<dynamic> _adminActivity = [];
  List<dynamic> _inbox = [];
  List<dynamic> _conversation = [];
  int? _selectedConversationUserId;
  String _selectedConversationName = '';
  String _analyticsPeriod = 'daily';
  DateTime _analyticsAnchorDate = DateTime.now();
  String? _gateAction;
  String? _gateSource;
  DateTime? _gateUpdatedAt;

  final _adminFormKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordConfirmationController = TextEditingController();
  final _replyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_loadOverview());
    });
    _inboxTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => unawaited(_refreshInboxNotification()),
    );
  }

  @override
  void dispose() {
    _inboxTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmationController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  String _formatDateTime(dynamic rawValue) {
    final raw = rawValue?.toString();
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return '-';
    return DateFormat('dd/MM/yyyy HH:mm', 'th').format(parsed.toLocal());
  }

  String _formatDate(DateTime value) {
    return DateFormat('dd/MM/yyyy', 'th').format(value);
  }

  String _formatMoney(dynamic value) {
    final amount = value is num ? value : num.tryParse(value?.toString() ?? '');
    if (amount == null) return '-';
    return '฿${NumberFormat('#,##0').format(amount)}';
  }

  String _periodLabel(String period) {
    switch (period) {
      case 'weekly':
        return 'รายสัปดาห์';
      case 'monthly':
        return 'รายเดือน';
      default:
        return 'รายวัน';
    }
  }

  String _slotStatusLabel(String status) {
    switch (status) {
      case 'available':
        return 'ว่าง';
      case 'reserved':
        return 'จองแล้ว';
      case 'occupied':
        return 'ไม่ว่าง';
      default:
        return status;
    }
  }

  Color _slotStatusColor(String status) {
    switch (status) {
      case 'available':
        return _successColor;
      case 'reserved':
        return _reservedColor;
      case 'occupied':
        return _dangerColor;
      default:
        return Colors.grey;
    }
  }

  String _paymentMethodLabel(dynamic value) {
    final method = value?.toString();
    if (method == null || method.isEmpty) return '-';
    if (method == 'promptpay') return 'PromptPay QR';
    if (method == 'card') return 'บัตรเครดิต/เดบิต';
    if (method.startsWith('mobile_banking_')) {
      return method.replaceFirst('mobile_banking_', 'Mobile Banking: ');
    }
    return method;
  }

  String _activityLabel(dynamic rawAction) {
    switch (rawAction?.toString()) {
      case 'admin_created':
        return 'เพิ่มบัญชีผู้ดูแล';
      case 'admin_deactivated':
        return 'ลบบัญชีผู้ดูแล';
      case 'login':
        return 'เข้าสู่ระบบ';
      case 'logout':
        return 'ออกจากระบบ';
      case 'admin_override':
        return 'แทรกแซงอุปกรณ์';
      default:
        return rawAction?.toString() ?? '-';
    }
  }

  String _sourceLabel(dynamic rawSource) {
    final source = rawSource?.toString();
    switch (source) {
      case 'admin':
        return 'ผู้ดูแลพื้นที่จอดรถ';
      case 'authentication':
        return 'เข้าสู่ระบบ';
      case 'admin_account':
        return 'บัญชีผู้ดูแลพื้นที่จอดรถ';
      case 'entry_ir_pair':
        return 'IR1 + IR2';
      case 'exit_ir_pair':
        return 'IR4 + IR5';
      case 'entry_ir3':
        return 'IR3';
      case 'exit_ir6':
        return 'IR6';
      default:
        return source ?? '-';
    }
  }

  int get _unreadCount {
    return _inbox.fold<int>(
      0,
      (total, item) {
        final value = item is Map ? item['unread_count'] : null;
        return total + (value is num ? value.toInt() : 0);
      },
    );
  }

  Future<void> _runLoad(Future<void> Function() operation) async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _viewError = null;
      });
    }
    try {
      await operation();
    } on ApiRequestException catch (error) {
      if (mounted) setState(() => _viewError = error.message);
    } catch (error) {
      debugPrint('Admin dashboard load error: $error');
      if (mounted) {
        setState(() => _viewError = 'ไม่สามารถดึงข้อมูลจากฐานระบบได้');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadOverview() {
    return _runLoad(() async {
      final analyticsFuture = ApiService.getAdminAnalytics(
        period: 'daily',
        anchorDate: DateTime.now(),
      );
      final slotsFuture = ApiService.getSlots();
      final bookingsFuture = ApiService.getAllBookingsAdmin();
      final activityFuture = ApiService.getAdminActivity(limit: 20);
      final inboxFuture = ApiService.getAdminInbox();
      final gateFuture = ApiService.getGateState();
      final analytics = await analyticsFuture;
      final slots = await slotsFuture;
      final bookings = await bookingsFuture;
      final activity = await activityFuture;
      final inbox = await inboxFuture;
      final gate = await gateFuture;
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _slots = slots;
        _bookings = bookings;
        _adminActivity = activity;
        _inbox = inbox;
        _applyGateState(gate);
      });
    });
  }

  Future<void> _loadAnalytics() {
    return _runLoad(() async {
      final analyticsFuture = ApiService.getAdminAnalytics(
        period: _analyticsPeriod,
        anchorDate: _analyticsAnchorDate,
      );
      final hardwareFuture = ApiService.getHardwareErrorAnalytics(
        period: _analyticsPeriod,
        anchorDate: _analyticsAnchorDate,
      );
      final slotsFuture = ApiService.getSlots();
      final bookingsFuture = ApiService.getAllBookingsAdmin();
      final analytics = await analyticsFuture;
      final hardware = await hardwareFuture;
      final slots = await slotsFuture;
      final bookings = await bookingsFuture;
      if (!mounted) return;
      setState(() {
        _analytics = analytics;
        _hardwareErrorAnalytics = hardware;
        _slots = slots;
        _bookings = bookings;
      });
    });
  }

  Future<void> _loadBookings() {
    return _runLoad(() async {
      final bookings = await ApiService.getAllBookingsAdmin();
      if (mounted) setState(() => _bookings = bookings);
    });
  }

  Future<void> _loadHardware() {
    return _runLoad(() async {
      final logsFuture = ApiService.getHardwareLogs();
      final devicesFuture = ApiService.getDeviceStatuses();
      final logs = await logsFuture;
      final devices = await devicesFuture;
      if (!mounted) return;
      setState(() {
        _hardwareLogs = logs;
        _deviceStatuses = devices;
      });
    });
  }

  Future<void> _loadAdminList() {
    return _runLoad(() async {
      final admins = await ApiService.getAdminList();
      if (mounted) setState(() => _adminList = admins);
    });
  }

  Future<void> _loadInbox() {
    return _runLoad(() async {
      final inbox = await ApiService.getAdminInbox();
      if (mounted) setState(() => _inbox = inbox);
    });
  }

  Future<void> _refreshInboxNotification() async {
    if (_isRefreshingInbox) return;
    _isRefreshingInbox = true;
    try {
      final oldUnread = _unreadCount;
      final inbox = await ApiService.getAdminInbox();
      if (!mounted) return;
      setState(() => _inbox = inbox);
      final newUnread = _unreadCount;
      if (newUnread > oldUnread) {
        _showMessage(
            'ข้อความใหม่จากผู้ใช้งาน ${newUnread - oldUnread} ข้อความ');
      }
    } catch (error) {
      debugPrint('Refresh admin inbox error: $error');
    } finally {
      _isRefreshingInbox = false;
    }
  }

  Future<void> _loadEmergencyOverride() {
    return _runLoad(() async {
      final gateFuture = ApiService.getGateState();
      final slotsFuture = ApiService.getSlots();
      final gate = await gateFuture;
      final slots = await slotsFuture;
      if (!mounted) return;
      setState(() {
        _applyGateState(gate);
        _slots = slots;
      });
    });
  }

  void _applyGateState(Map<String, dynamic> gate) {
    _gateAction = gate['last_action']?.toString();
    _gateSource = gate['source']?.toString();
    final rawUpdatedAt = gate['updated_at']?.toString();
    _gateUpdatedAt =
        rawUpdatedAt == null ? null : DateTime.tryParse(rawUpdatedAt);
  }

  void _selectView(String view) {
    Navigator.of(context).pop();
    setState(() {
      _currentView = view;
      _viewError = null;
    });
    switch (view) {
      case 'overview':
        unawaited(_loadOverview());
        break;
      case 'analytics':
        unawaited(_loadAnalytics());
        break;
      case 'history':
        unawaited(_loadBookings());
        break;
      case 'hardware':
        unawaited(_loadHardware());
        break;
      case 'override':
        unawaited(_loadEmergencyOverride());
        break;
      case 'admins':
        unawaited(_loadAdminList());
        break;
      case 'inbox':
        unawaited(_loadInbox());
        break;
    }
  }

  Future<void> _pickAnalyticsDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _analyticsAnchorDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('th', 'TH'),
    );
    if (selected == null || !mounted) return;
    setState(() => _analyticsAnchorDate = selected);
    await _loadAnalytics();
  }

  Future<bool> _confirm(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('ยกเลิก'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: FilledButton.styleFrom(backgroundColor: _primaryColor),
                child: const Text('ยืนยัน'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? _dangerColor : _successColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

Future<Map<String, dynamic>> _waitForHardwareCommand(
  String commandId,
) async {
  var command = <String, dynamic>{
    'status': 'queued',
  };
  for (var attempt = 0; attempt < 6; attempt++) {
    await Future<void>.delayed(
      const Duration(seconds: 1),
    );
    command = await ApiService.getHardwareCommand(
      commandId,
    );
    if (command['status']?.toString() != 'queued') {
      return command;
    }
  }
  return command;
}
bool _commandWillContinue(
  Map<String, dynamic> command,
) {
  final status = command['status']?.toString();
  return status == 'queued' ||
      status == 'no_response' ||
      (
        status == 'failed' &&
        command['published_at'] == null
      );
}

  Future<void> _sendGateAction(String action) async {
    if (_isGateCommandPending) return;
    final label = action == 'open' ? 'เปิด' : 'ปิด';
    final confirmed = await _confirm(
      'ยืนยันการควบคุมไม้กั้น',
      'ต้องการสั่ง$labelไม้กั้นใช่หรือไม่?',
    );
    if (!confirmed || !mounted) return;

    setState(() => _isGateCommandPending = true);
    try {
      final response = await ApiService.overrideServo(action);
      final commandId = response['command_id']?.toString();
      if (commandId == null || commandId.isEmpty) {
        throw const ApiRequestException('Backend ไม่ส่งรหัสคำสั่งอุปกรณ์');
      }
      final command = await _waitForHardwareCommand(
        commandId,
      );
      final status =
          command['status']?.toString() ?? 'unknown';
      final gate = await ApiService.getGateState();

      if (!mounted) return;
      setState(() => _applyGateState(gate));

      if (status == 'acknowledged') {
        _showMessage(
          'อุปกรณ์ยืนยันคำสั่ง$labelไม้กั้นแล้ว',
        );
      } else if (_commandWillContinue(command)) {
        _showMessage  (
          'ระบบบันทึกคำสั่งแล้ว และจะดำเนินการต่อ  อัตโนมัติเมื่ออุปกรณ์ตอบกลับหรือการเชื่อมต่อกลับมา',
        );
      } else {
        _showMessage(
          'อุปกรณ์ยืนยันคำสั่งไม่สำเร็จ: $status',
          isError: true,
        );
      }
    } on ApiRequestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      debugPrint('Gate override error: $error');
      _showMessage('ไม่สามารถส่งคำสั่งไปยังไม้กั้นได้', isError: true);
    } finally {
      if (mounted) setState(() => _isGateCommandPending = false);
    }
  }

  Future<void> _sendRgbAction(String slotName, String status) async {
    if (_pendingRgbSlots.contains(slotName)) return;
    final confirmed = await _confirm(
      'ยืนยันการเปลี่ยนสถานะช่องจอด',
      'ต้องการเปลี่ยนช่อง $slotName เป็น “${_slotStatusLabel(status)}” ใช่หรือไม่?',
    );
    if (!confirmed) return;
    setState(() => _pendingRgbSlots.add(slotName));
    try {
      final response = await ApiService.overrideRgb(slotName, status);
      final commandId = response['command_id']?.toString();
      if (commandId == null || commandId.isEmpty) {
        throw const ApiRequestException('Backend ไม่ส่งรหัสคำสั่งอุปกรณ์');
      }
      final command = await _waitForHardwareCommand(
        commandId,
      );
      final commandStatus =
          command['status']?.toString() ?? 'unknown';
      if (commandStatus == 'acknowledged') {
        _showMessage(
          'อุปกรณ์ยืนยันสถานะช่อง $slotName แล้ว',
        );
      } else if (_commandWillContinue(command)) {
        _showMessage(
          'ระบบบันทึกคำสั่งของช่อง $slotName แล้ว และจะดำเนินการต่ออัตโนมัติเมื่ออุปกรณ์ตอบกลับหรือการเชื่อมต่อกลับมา',
        );
      } else {
        _showMessage(
          'อุปกรณ์ยืนยันสถานะช่อง $slotName ไม่สำเร็จ: $commandStatus',
          isError: true,
        );
      }
      final slots = await ApiService.getSlots();
      if (mounted) setState(() => _slots = slots);
    } on ApiRequestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      debugPrint('RGB override error: $error');
      _showMessage('ไม่สามารถควบคุมสถานะช่องจอดได้', isError: true);
    } finally {
      if (mounted) setState(() => _pendingRgbSlots.remove(slotName));
    }
  }

  Future<void> _addAdmin() async {
    if (_isAddingAdmin || !(_adminFormKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _isAddingAdmin = true);
    try {
      await ApiService.addAdmin(
        firstName: _firstNameController.text,
        lastName: _lastNameController.text,
        username: _usernameController.text,
        email: _emailController.text,
        password: _passwordController.text,
        passwordConfirmation: _passwordConfirmationController.text,
      );
      _firstNameController.clear();
      _lastNameController.clear();
      _usernameController.clear();
      _emailController.clear();
      _passwordController.clear();
      _passwordConfirmationController.clear();
      await _loadAdminList();
      _showMessage('เพิ่มบัญชีผู้ดูแลพื้นที่แล้ว');
    } on ApiRequestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      debugPrint('Add admin error: $error');
      _showMessage('ไม่สามารถเพิ่มผู้ดูแลพื้นที่ได้', isError: true);
    } finally {
      if (mounted) setState(() => _isAddingAdmin = false);
    }
  }

  Future<void> _deleteAdmin(Map<dynamic, dynamic> admin) async {
    final id = admin['id'];
    if (id is! int) {
      _showMessage('รหัสบัญชีผู้ดูแลไม่ถูกต้อง', isError: true);
      return;
    }
    final confirmed = await _confirm(
      'ยืนยันการลบบัญชีผู้ดูแล',
      'ต้องการลบบัญชี “${admin['name'] ?? admin['username'] ?? id}” ใช่หรือไม่? บัญชีนี้จะหมดสิทธิ์ในการดูแลพื้นที่จอดรถทันที',
    );
    if (!confirmed) return;
    try {
      await ApiService.deactivateAdmin(id);
      await _loadAdminList();
      _showMessage('ลบบัญชีผู้ดูแลแล้ว');
    } on ApiRequestException catch (error) {
      _showMessage(error.message, isError: true);
    } catch (error) {
      debugPrint('Delete admin error: $error');
      _showMessage('ไม่สามารถลบบัญชีผู้ดูแลได้', isError: true);
    }
  }

  Future<void> _openConversation(Map<dynamic, dynamic> conversation) async {
    final userId = conversation['user_id'];
    if (userId is! int) return;
    setState(() {
      _selectedConversationUserId = userId;
      _selectedConversationName = conversation['user_name']?.toString() ?? '-';
      _conversation = [];
      _viewError = null;
    });
    try {
      final messages = await ApiService.getAdminConversation(userId);
      final inbox = await ApiService.getAdminInbox();
      if (!mounted || _selectedConversationUserId != userId) return;
      setState(() {
        _conversation = messages;
        _inbox = inbox;
      });
    } on ApiRequestException catch (error) {
      if (mounted) setState(() => _viewError = error.message);
    }
  }

  Future<void> _replyToConversation() async {
    final userId = _selectedConversationUserId;
    final body = _replyController.text.trim();
    if (userId == null || body.isEmpty || _isReplying) return;
    setState(() => _isReplying = true);
    try {
      await ApiService.replyToSupportMessage(userId, body);
      _replyController.clear();
      final messages = await ApiService.getAdminConversation(userId);
      final inbox = await ApiService.getAdminInbox();
      if (!mounted) return;
      setState(() {
        _conversation = messages;
        _inbox = inbox;
      });
    } on ApiRequestException catch (error) {
      _showMessage(error.message, isError: true);
    } finally {
      if (mounted) setState(() => _isReplying = false);
    }
  }

  Future<void> _logout() async {
    final loggedOut = await context.read<ParkingProvider>().logout();
    if (!mounted) return;
    if (!loggedOut) {
      _showMessage('ไม่สามารถลงทะเบียนออกได้ กรุณาลองใหม่อีกครั้ง', isError: true);
      return;
    }
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'Admin Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'โหลดข้อมูลล่าสุด',
            onPressed: _isLoading ? null : _reloadCurrentView,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          Positioned.fill(child: _buildBody()),
          if (_isLoading) ...[
            const ModalBarrier(color: Color(0x33000000), dismissible: false),
            const Center(
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('กำลังโหลดข้อมูลจริงจากระบบ...'),
                        SizedBox(height: 16),
                        LinearProgressIndicator(color: _primaryColor),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: _primaryColor),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                SizedBox(height: 12),
                Text(
                  'ผู้ดูแลระบบ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text('จัดการพื้นที่จอดรถ',
                    style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          _drawerTile('overview', Icons.dashboard, 'ภาพรวมระบบ'),
          _drawerTile('analytics', Icons.analytics, 'สถิติ'),
          _drawerTile('history', Icons.history, 'ประวัติการจอดและการชำระเงิน'),
          _drawerTile('hardware', Icons.memory, 'สถานะและประวัติอุปกรณ์'),
          _drawerTile('override', Icons.warning, 'ระบบแทรกแซงฉุกเฉิน'),
          _drawerTile('admins', Icons.manage_accounts, 'จัดการผู้ดูแลระบบ'),
          ListTile(
            selected: _currentView == 'inbox',
            leading: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.inbox, color: _primaryColor),
            ),
            title: const Text('Inbox'),
            onTap: () => _selectView('inbox'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: _dangerColor),
            title:
                const Text('ออกจากระบบ', style: TextStyle(color: _dangerColor)),
            onTap: _logout,
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(String view, IconData icon, String title) {
    return ListTile(
      selected: _currentView == view,
      leading: Icon(icon, color: _primaryColor),
      title: Text(title),
      onTap: () => _selectView(view),
    );
  }

  void _reloadCurrentView() {
    switch (_currentView) {
      case 'overview':
        unawaited(_loadOverview());
        break;
      case 'analytics':
        unawaited(_loadAnalytics());
        break;
      case 'history':
        unawaited(_loadBookings());
        break;
      case 'hardware':
        unawaited(_loadHardware());
        break;
      case 'override':
        unawaited(_loadEmergencyOverride());
        break;
      case 'admins':
        unawaited(_loadAdminList());
        break;
      case 'inbox':
        unawaited(_loadInbox());
        break;
    }
  }

  Widget _buildBody() {
    if (_viewError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: _dangerColor, size: 48),
              const SizedBox(height: 12),
              Text(_viewError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _reloadCurrentView,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่'),
              ),
            ],
          ),
        ),
      );
    }
    switch (_currentView) {
      case 'analytics':
        return _buildAnalyticsView();
      case 'history':
        return _buildHistoryView();
      case 'hardware':
        return _buildHardwareView();
      case 'override':
        return _buildOverrideView();
      case 'admins':
        return _buildAdminView();
      case 'inbox':
        return _buildInboxView();
      default:
        return _buildOverview();
    }
  }

  Widget _buildOverview() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ภาพรวมระบบ',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _primaryColor),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard(
                  'รายได้วันนี้',
                  _formatMoney(_analytics['income_total']),
                  Icons.payments,
                  _successColor),
              _statCard(
                  'อัตราการใช้งาน',
                  '${_analytics['usage_percent'] ?? '-'}%',
                  Icons.pie_chart,
                  Colors.blue),
              _statCard('รถเข้า', '${_analytics['cars_in'] ?? '-'} คัน',
                  Icons.login, _warningColor),
              _statCard('รถออก', '${_analytics['cars_out'] ?? '-'} คัน',
                  Icons.logout, Colors.purple),
            ],
          ),
          const SizedBox(height: 28),
          const Text('สถานะช่องจอด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSlotCards(),
          const SizedBox(height: 28),
          Row(
            children: [
              const Expanded(
                child: Text('กิจกรรมล่าสุด',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              if (_unreadCount > 0)
                Chip(
                  avatar: const Icon(Icons.notifications, size: 18),
                  label: Text('ข้อความใหม่ $_unreadCount'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActivityList(),
        ],
      ),
    );
  }

  Widget _statCard(String title, String value, IconData icon, Color color) {
    return SizedBox(
      width: 240,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(value,
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: color)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

Widget _buildSlotCards() {
  final liveSlots =
      context.watch<ParkingProvider>().slots;

  final displayedSlots =
      liveSlots.isEmpty ? _slots : liveSlots;

  if (displayedSlots.isEmpty) {
    return const Text(
      'ไม่พบข้อมูลสถานะช่องจอด',
    );
  }
  return Wrap(
    spacing: 16,
    runSpacing: 16,
    children: displayedSlots.map((slot) {
        final color = _slotStatusColor(slot.status);
        final currentBooking = _currentBookingForSlot(slot.name);
        final plate = currentBooking == null
            ? null
            : currentBooking['vehicle_plate_number'] ??
                currentBooking['license_plate'];
        return SizedBox(
          width: 250,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Icon(Icons.local_parking, size: 42, color: color),
                  const SizedBox(height: 8),
                  Text('ช่อง ${slot.name}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(_slotStatusLabel(slot.status),
                      style:
                          TextStyle(color: color, fontWeight: FontWeight.bold)),
                  if (currentBooking != null) ...[
                    const Divider(height: 20),
                    Text('ทะเบียนรถ: ${plate ?? '-'}'),
                    Text(
                      'เวลาเริ่มจอด: ${_formatDateTime(currentBooking['entry_time'])}',
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      'ช่วงเวลาจอง: ${_formatDateTime(currentBooking['start_time'])}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic>? _currentBookingForSlot(String slotName) {
    for (final raw in _bookings) {
      if (raw is! Map) continue;
      final booking = Map<String, dynamic>.from(raw);
      final status = booking['booking_status']?.toString();
      if (booking['slot_name'] == slotName &&
          (status == 'active' || status == 'ready_to_exit')) {
        return booking;
      }
    }
    return null;
  }

  Widget _buildActivityList() {
    if (_adminActivity.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(24), child: Text('ยังไม่มีกิจกรรม')));
    }
    return Card(
      child: Column(
        children: _adminActivity.map((raw) {
          final item = Map<String, dynamic>.from(raw as Map);
          return ListTile(
            leading: const CircleAvatar(child: Icon(Icons.history)),
            title: Text(_activityLabel(item['action'])),
            subtitle: Text(
                '${item['actor_name'] ?? 'ระบบ'} • ${_sourceLabel(item['source'])}'),
            trailing: Text(_formatDateTime(item['occurred_at'])),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildAnalyticsView() {
    final periodLabel = _periodLabel(_analyticsPeriod);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สถิติพื้นที่จอดรถ',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'daily', label: Text('รายวัน')),
                  ButtonSegment(value: 'weekly', label: Text('รายสัปดาห์')),
                  ButtonSegment(value: 'monthly', label: Text('รายเดือน')),
                ],
                selected: {_analyticsPeriod},
                onSelectionChanged: (selection) {
                  setState(() => _analyticsPeriod = selection.first);
                  unawaited(_loadAnalytics());
                },
              ),
              OutlinedButton.icon(
                onPressed: _pickAnalyticsDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(_formatDate(_analyticsAnchorDate)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: [
              _statCard(
                  'รายได้$periodLabel',
                  _formatMoney(_analytics['income_total']),
                  Icons.payments,
                  _successColor),
              _statCard(
                  'อัตราการใช้งาน$periodLabel',
                  '${_analytics['usage_percent'] ?? '-'}%',
                  Icons.pie_chart,
                  Colors.blue),
              _statCard(
                  'รถเข้า$periodLabel',
                  '${_analytics['cars_in'] ?? '-'} คัน',
                  Icons.login,
                  _warningColor),
              _statCard(
                  'รถออก$periodLabel',
                  '${_analytics['cars_out'] ?? '-'} คัน',
                  Icons.logout,
                  Colors.purple),
              _statCard(
                  'อุปกรณ์ผิดพลาด',
                  '${_hardwareErrorAnalytics['total_errors'] ?? 0} ครั้ง',
                  Icons.warning,
                  _dangerColor),
            ],
          ),
          const SizedBox(height: 24),
          _buildChartPanel('รายได้$periodLabel', _analytics['chart'],
              valueSuffix: ' บาท'),
          const SizedBox(height: 16),
          _buildChartPanel(
              'อัตราการใช้งาน$periodLabel', _analytics['usage_chart'],
              valueSuffix: '%'),
          const SizedBox(height: 16),
          _buildChartPanel(
              'จำนวนรถเข้า$periodLabel', _analytics['cars_in_chart'],
              valueSuffix: ' คัน'),
          const SizedBox(height: 16),
          _buildChartPanel(
              'จำนวนรถออก$periodLabel', _analytics['cars_out_chart'],
              valueSuffix: ' คัน'),
          const SizedBox(height: 16),
          _buildChartPanel('ความผิดพลาดของอุปกรณ์$periodLabel',
              _hardwareErrorAnalytics['chart'],
              valueSuffix: ' ครั้ง'),
          const SizedBox(height: 24),
          const Text('ความผิดพลาดของอุปกรณ์',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildDeviceErrorSummary(),
          const SizedBox(height: 16),
          _buildHardwareErrorHistory(),
          const SizedBox(height: 24),
          const Text('สถานะช่องจอดล่าสุด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _buildSlotCards(),
        ],
      ),
    );
  }

  Widget _buildChartPanel(String title, dynamic rawItems,
      {String valueSuffix = ''}) {
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    final values =
        items.map((item) => (item['value'] as num?)?.toDouble() ?? 0).toList();
    final maxValue =
        values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const SizedBox(
                  height: 120, child: Center(child: Text('ไม่พบข้อมูล')))
            else
              SizedBox(
                height: 220,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(items.length, (index) {
                      final value = values[index];
                      final height =
                          maxValue <= 0 ? 2.0 : 140 * value / maxValue;
                      return SizedBox(
                        width: 72,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                                '${NumberFormat('#,##0.#').format(value)}$valueSuffix',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11)),
                            const SizedBox(height: 6),
                            Container(
                              width: 34,
                              height: height,
                              decoration: BoxDecoration(
                                  color: _primaryColor,
                                  borderRadius: BorderRadius.circular(6)),
                            ),
                            const SizedBox(height: 8),
                            Text(items[index]['label']?.toString() ?? '-',
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceErrorSummary() {
    final raw = _hardwareErrorAnalytics['by_device'];
    final items = raw is List ? raw : const [];
    if (items.isEmpty) {
      return const Text('ไม่พบข้อมูลในช่วงระยะเวลาที่เลือก');
    }
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items.map<Widget>((item) {
        final map = Map<String, dynamic>.from(item as Map);
        return Chip(
          avatar: const Icon(Icons.memory, size: 18),
          label:
              Text('${map['device_name'] ?? '-'}: ${map['count'] ?? 0} ครั้ง'),
        );
      }).toList(),
    );
  }

  Widget _buildHardwareErrorHistory() {
    final raw = _hardwareErrorAnalytics['history'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList()
        : <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('อุปกรณ์ที่ผิดพลาด')),
            DataColumn(label: Text('สถานะ')),
            DataColumn(label: Text('เวลา')),
            DataColumn(label: Text('รายละเอียด')),
          ],
          rows: items.map((item) {
            return DataRow(cells: [
              DataCell(Text(item['device_name']?.toString() ?? '-')),
              DataCell(Text(item['status']?.toString() ?? '-')),
              DataCell(Text(_formatDateTime(item['created_at']))),
              DataCell(Text(item['detail']?.toString() ?? '-')),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildHistoryView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประวัติการจองและการชำระเงิน',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor)),
          const SizedBox(height: 16),
          if (_bookings.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text('ยังไม่มีประวัติจากฐานข้อมูล')))
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('รหัสการจอง')),
                    DataColumn(label: Text('ชื่อ-นามสกุล')),
                    DataColumn(label: Text('ชื่อผู้ใช้งาน')),
                    DataColumn(label: Text('ช่องจอด')),
                    DataColumn(label: Text('ทะเบียนรถ')),
                    DataColumn(label: Text('จังหวัด')),
                    DataColumn(label: Text('เวลาทำรายการ')),
                    DataColumn(label: Text('ช่วงเวลาที่จอง')),
                    DataColumn(label: Text('เวลาเข้า')),
                    DataColumn(label: Text('เวลาออก')),
                    DataColumn(label: Text('สถานะการจอง')),
                    DataColumn(label: Text('สถานะชำระเงิน')),
                    DataColumn(label: Text('วิธีชำระเงิน')),
                    DataColumn(label: Text('เวลาชำระเงิน')),
                    DataColumn(label: Text('ยอดชำระ')),
                  ],
                  rows: _bookings.map((raw) {
                    final booking = Map<String, dynamic>.from(raw as Map);
                    final plate = booking['vehicle_plate_number'] ??
                        booking['license_plate'] ??
                        '-';
                    return DataRow(cells: [
                      DataCell(
                          Text(booking['booking_code']?.toString() ?? '-')),
                      DataCell(Text(booking['user_name']?.toString() ?? '-')),
                      DataCell(Text(booking['username']?.toString() ?? '-')),
                      DataCell(Text(booking['slot_name']?.toString() ?? '-')),
                      DataCell(Text(plate.toString())),
                      DataCell(
                          Text(booking['vehicle_province']?.toString() ?? '-')),
                      DataCell(
                          Text(_formatDateTime(booking['booking_created_at']))),
                      DataCell(Text(
                          '${_formatDateTime(booking['start_time'])}\nถึง ${_formatDateTime(booking['end_time'])}')),
                      DataCell(Text(_formatDateTime(booking['entry_time']))),
                      DataCell(Text(_formatDateTime(booking['exited_at']))),
                      DataCell(
                        Text(booking['booking_status']?.toString() ?? '-'),
                      ),
                      DataCell(
                        Text(booking['payment_status']?.toString() ?? '-'),
                      ),
                      DataCell(
                        Text(_paymentMethodLabel(booking['payment_method'])),
                      ),
                      DataCell(
                        Text(_formatDateTime(booking['payment_paid_at'])),
                      ),
                      DataCell(Text(_formatMoney(booking['amount']))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHardwareView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สถานะอุปกรณ์',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor)),
          const SizedBox(height: 16),
          if (_deviceStatuses.isEmpty)
            const Text('ไม่พบข้อมูลสถานะอุปกรณ์')
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('อุปกรณ์')),
                    DataColumn(label: Text('สถานะปัจจุบัน')),
                    DataColumn(label: Text('พบสัญญาณล่าสุด')),
                    DataColumn(label: Text('ประมวลผลล่าสุด')),
                  ],
                  rows: _deviceStatuses.map((raw) {
                    final device = Map<String, dynamic>.from(raw as Map);
                    final status = device['status']?.toString() ?? 'unknown';
                    final color = _deviceStatusColor(status);
                    return DataRow(cells: [
                      DataCell(Text(device['device_name']?.toString() ?? '-')),
                      DataCell(Row(children: [
                        Icon(Icons.circle, size: 12, color: color),
                        const SizedBox(width: 6),
                        Text(status),
                      ])),
                      DataCell(Text(_formatDateTime(
                          device['last_seen_at'] ?? device['last_updated']))),
                      DataCell(
                          Text(_formatDateTime(device['last_processed_at']))),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 28),
          const Text('ประวัติการทำงานของอุปกรณ์',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          if (_hardwareLogs.isEmpty)
            const Text('ไม่พบประวัติการทำงานของอุปกรณ์')
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('อุปกรณ์')),
                    DataColumn(label: Text('สถานะ')),
                    DataColumn(label: Text('เวลา')),
                    DataColumn(label: Text('แหล่งข้อมูล')),
                    DataColumn(label: Text('รายละเอียด')),
                    DataColumn(label: Text('Command ID')),
                  ],
                  rows: _hardwareLogs.map((raw) {
                    final log = Map<String, dynamic>.from(raw as Map);
                    return DataRow(cells: [
                      DataCell(Text(log['device_name']?.toString() ?? '-')),
                      DataCell(Text(log['status']?.toString() ?? '-')),
                      DataCell(Text(_formatDateTime(log['created_at']))),
                      DataCell(Text(_sourceLabel(log['source']))),
                      DataCell(Text(log['detail']?.toString() ?? '-')),
                      DataCell(Text(log['command_id']?.toString() ?? '-')),
                    ]);
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
  Color _deviceStatusColor(String status) {
    return status == 'online'
        ? _successColor
        : status == 'offline' || status == 'failed' || status == 'no_response'
            ? _dangerColor
            : _warningColor;
  }

  Widget _buildOverrideView() {
    final liveSlots =
    context.watch<ParkingProvider>().slots;
    final displayedSlots =
        liveSlots.isEmpty ? _slots : liveSlots;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ระบบแทรกแซงฉุกเฉิน',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _warningColor)),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ควบคุมไม้กั้น',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(
                      'การกระทำล่าสุด: ${_gateAction ?? '-'} (${_sourceLabel(_gateSource)})'),
                  Text(
                      'เวลา: ${_gateUpdatedAt == null ? '-' : _formatDateTime(_gateUpdatedAt!.toIso8601String())}'),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      FilledButton.icon(
                        onPressed: _isGateCommandPending
                            ? null
                            : () => _sendGateAction('open'),
                        icon: const Icon(Icons.lock_open),
                        label: const Text('เปิดไม้กั้น'),
                      ),
                      FilledButton.icon(
                        onPressed: _isGateCommandPending
                            ? null
                            : () => _sendGateAction('close'),
                        style: FilledButton.styleFrom(
                            backgroundColor: _dangerColor),
                        icon: const Icon(Icons.lock),
                        label: const Text('ปิดไม้กั้น'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('ควบคุมสถานะช่องจอด',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          ...['M', 'N', 'O'].map((slotName) {
            final matching = displayedSlots.where(
              (slot) => slot.name == slotName,
            );
            final current = matching.isEmpty ? null : matching.first;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    SizedBox(
                      width: 120,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('ช่อง $slotName',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.bold)),
                          Text(current == null
                              ? '-'
                              : _slotStatusLabel(current.status)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _rgbButton(slotName, 'available'),
                          _rgbButton(slotName, 'reserved'),
                          _rgbButton(slotName, 'occupied'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _rgbButton(String slotName, String status) {
    final color = _slotStatusColor(status);
    return OutlinedButton(
      onPressed: _pendingRgbSlots.contains(slotName)
          ? null
          : () => _sendRgbAction(slotName, status),
      style: OutlinedButton.styleFrom(
          foregroundColor: color, side: BorderSide(color: color)),
      child: Text(_slotStatusLabel(status)),
    );
  }

  Widget _buildAdminView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('จัดการผู้ดูแลระบบ',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor)),
          const SizedBox(height: 16),
          if (_adminList.isEmpty)
            const Card(
                child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('ไม่พบข้อมูลผู้ดูแลระบบ')))
          else
            Card(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('สถานะ')),
                    DataColumn(label: Text('ชื่อ-นามสกุล')),
                    DataColumn(label: Text('Username')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('เข้าสู่ระบบล่าสุด')),
                    DataColumn(label: Text('ออกจากระบบล่าสุด')),
                    DataColumn(label: Text('จัดการ')),
                  ],
                  rows: _adminList.map((raw) {
                    final admin = Map<String, dynamic>.from(raw as Map);
                    final online = admin['is_online'] == true;
                    return DataRow(cells: [
                      DataCell(Row(children: [
                        Icon(Icons.circle,
                            size: 12,
                            color: online ? _successColor : _dangerColor),
                        const SizedBox(width: 6),
                        Text(online ? 'Online' : 'Offline'),
                      ])),
                      DataCell(Text(admin['name']?.toString() ?? '-')),
                      DataCell(Text(admin['username']?.toString() ?? '-')),
                      DataCell(Text(admin['email']?.toString() ?? '-')),
                      DataCell(Text(_formatDateTime(admin['last_login_at']))),
                      DataCell(Text(_formatDateTime(admin['last_logout_at']))),
                      DataCell(IconButton(
                        tooltip: 'ลบบัญชีผู้ดูแล',
                        onPressed: () => _deleteAdmin(admin),
                        icon: const Icon(Icons.delete, color: _dangerColor),
                      )),
                    ]);
                  }).toList(),
                ),
              ),
            ),
          const SizedBox(height: 28),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _adminFormKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('เพิ่มผู้ดูแลพื้นที่ที่จอดรถ',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 16,
                      runSpacing: 16,
                      children: [
                        _adminField(
                            _firstNameController, 'ชื่อจริง', Icons.badge),
                        _adminField(
                            _lastNameController, 'นามสกุล', Icons.badge),
                        _adminField(
                            _usernameController, 'ชื่อผู้ใช้งาน', Icons.person),
                        _adminField(
                          _emailController,
                          'Email',
                          Icons.email,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final text = value?.trim() ?? '';
                            if (text.isEmpty) return 'กรุณากรอก Email';
                            if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(text)) {
                              return 'รูปแบบไม่ถูกต้อง';
                            }
                            return null;
                          },
                        ),
                        _adminField(
                          _passwordController,
                          'รหัสผ่าน',
                          Icons.lock,
                          obscureText: true,
                          validator: (value) {
                            final text = value ?? '';
                            if (text.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                            if (text.length < 8) {
                              return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                            }
                            return null;
                          },
                        ),
                        _adminField(
                          _passwordConfirmationController,
                          'ยืนยันรหัสผ่าน',
                          Icons.lock_outline,
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'กรุณายืนยันรหัสผ่าน';
                            }
                            if (value != _passwordController.text) {
                              return 'รหัสผ่านไม่ตรงกัน';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _isAddingAdmin ? null : _addAdmin,
                      icon: const Icon(Icons.person_add),
                      label: Text(_isAddingAdmin
                          ? 'กำลังบันทึก...'
                          : 'เพิ่มผู้ดูแลพื้นที่'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adminField(
    TextEditingController controller,
    String label,
    IconData icon, {
    bool obscureText = false,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return SizedBox(
      width: 320,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
            labelText: label,
            prefixIcon: Icon(icon),
            border: const OutlineInputBorder()),
        validator: validator ??
            (value) => value == null || value.trim().isEmpty
                ? 'กรุณากรอก$label'
                : null,
      ),
    );
  }

  Widget _buildInboxView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Inbox',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: _primaryColor)),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 850;
                final conversations = _buildConversationList();
                final messages = _buildConversationPanel();
                return narrow
                    ? Column(children: [
                        SizedBox(height: 220, child: conversations),
                        const SizedBox(height: 12),
                        Expanded(child: messages)
                      ])
                    : Row(children: [
                        SizedBox(width: 320, child: conversations),
                        const SizedBox(width: 16),
                        Expanded(child: messages)
                      ]);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList() {
    return Card(
      child: _inbox.isEmpty
          ? const Center(child: Text('ยังไม่มีข้อความจากผู้ใช้งาน'))
          : ListView.separated(
              itemCount: _inbox.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = Map<String, dynamic>.from(_inbox[index] as Map);
                final unread = item['unread_count'] as int? ?? 0;
                final selected = item['user_id'] == _selectedConversationUserId;
                return ListTile(
                  selected: selected,
                  leading: Badge(
                    isLabelVisible: unread > 0,
                    label: Text('$unread'),
                    child: const CircleAvatar(child: Icon(Icons.person)),
                  ),
                  title: Text(item['user_name']?.toString() ?? '-'),
                  subtitle: Text(
                    item['last_message']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(_formatDateTime(item['updated_at']),
                      style: const TextStyle(fontSize: 11)),
                  onTap: () => _openConversation(item),
                );
              },
            ),
    );
  }

  Widget _buildConversationPanel() {
    if (_selectedConversationUserId == null) {
      return const Card(child: Center(child: Text('เลือกรายการสนทนา')));
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.support_agent, color: _primaryColor),
            title: Text(_selectedConversationName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(height: 1),
          Expanded(
            child: _conversation.isEmpty
                ? const Center(child: Text('ไม่พบข้อความ'))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _conversation.length,
                    itemBuilder: (context, index) {
                      final message = Map<String, dynamic>.from(
                          _conversation[index] as Map);
                      final fromAdmin = message['sender_role'] == 'admin';
                      return Align(
                        alignment: fromAdmin
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 520),
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: fromAdmin
                                ? const Color(0xFFE8E8FF)
                                : const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: fromAdmin
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              Text(message['body']?.toString() ?? ''),
                              const SizedBox(height: 4),
                              Text(_formatDateTime(message['created_at']),
                                  style: const TextStyle(
                                      fontSize: 11, color: Colors.black54)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _replyController,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                        hintText: 'พิมพ์ข้อความ...',
                        border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _isReplying ? null : _replyToConversation,
                  icon: const Icon(Icons.send),
                  tooltip: 'ส่งข้อความ',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
