import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  String _currentView = 'overview'; 
  bool _isLoading = false;
  
  List<dynamic> _hardwareLogs = [];
  List<dynamic> _adminList = [];
  List<dynamic> _bookings = []; 
  Map<String, dynamic> _analytics = {}; 
  Map<String, dynamic> _cameraStatus = {}; 
  bool? _isBarrierOpen;

  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ดึงรายชื่อผู้ดูแลระบบ
  Future<void> _fetchAdminList() async {
    try {
      final list = await ApiService.getAdminList();
      if (mounted) {
        setState(() {
          _adminList = list;
        });
      }
    } catch (e) { // ดักจับ Error
    }
  }

  // ดึงประวัติการทำงานอุปกรณ์
  Future<void> _fetchHardwareLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await ApiService.getHardwareLogs();
      if (mounted) {
        setState(() {
          _hardwareLogs = logs;
          _cameraStatus = {};
        });
      }
    } catch (e) { // ดักจับ Error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ดึงข้อมูลสถิติ
  Future<void> _fetchAnalytics() async {
    setState(() => _isLoading = true);
    try {
      if (mounted) setState(() => _analytics = {});
    } catch (e) { // ดักจับ Error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ดึงประวัติการจอง
  Future<void> _fetchBookings() async {
    setState(() => _isLoading = true);
    try {
      if (mounted) setState(() => _bookings = []);
    } catch (e) { // ดักจับ Error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Admin Dashboard', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
      ),

      // Sidebar แบบ Drop-down
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(color: primaryColor),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
                  SizedBox(height: 12),
                  Text('ผู้ดูแลระบบ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  Text('จัดการพื้นที่จอดรถ', style: TextStyle(color: Colors.white70, fontSize: 14)),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard, color: primaryColor),
              title: const Text('ภาพรวมระบบ'),
              onTap: () {
                setState(() => _currentView = 'overview');
                Navigator.pop(context);
              },
            ),
    
            // เมนูจัดการฐานข้อมูล
            ExpansionTile(
              leading: const Icon(Icons.dns, color: primaryColor),
              title: const Text('จัดการพื้นที่จอดรถ'),
              children: [
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('ประวัติการจอดและการชำระเงิน'),
                  contentPadding: const EdgeInsets.only(left: 40),
                  onTap: () {
                    setState(() => _currentView = 'database_history');
                    _fetchBookings();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('สถิติ'),
                  contentPadding: const EdgeInsets.only(left: 40),
                  onTap: () {
                    setState(() => _currentView = 'analytics');
                    _fetchAnalytics();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            ExpansionTile(
              leading: const Icon(Icons.memory, color: primaryColor),
              title: const Text('ควบคุมการทำงานของอุปกรณ์'),
              children: [
                ListTile(
                  leading: const Icon(Icons.videocam),
                  title: const Text('สถานะอุปกรณ์'),
                  contentPadding: const EdgeInsets.only(left: 40),
                  onTap: () {
                    setState(() => _currentView = 'hardware_logs');
                    _fetchHardwareLogs();
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.warning),
                  title: const Text('ระบบแทรกแซงฉุกเฉิน'),
                  contentPadding: const EdgeInsets.only(left: 40),
                  onTap: () {
                    setState(() => _currentView = 'emergency_override');
                    _fetchHardwareLogs();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person_add, color: primaryColor),
              title: const Text('จัดการผู้ดูแลระบบ'),
              onTap: () {
                setState(() => _currentView = 'add_admin');
                _fetchAdminList();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
              },
            ),
          ],
        ),
      ),
      
      // หน้าแสดงผล
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator(color: primaryColor))
          : _buildBodyContent(),
    );
  }

  // สลับหน้าจอ
  Widget _buildBodyContent() {
    switch (_currentView) {
      case 'hardware_logs':
        return _buildHardwareLogsView();
      case 'add_admin':
        return _buildAddAdminView();
      case 'database_history':
        return _buildDatabaseHistoryView();
      case 'analytics':
      case 'overview':
        return _buildAnalyticsView();
      case 'emergency_override':
        return _buildEmergencyOverrideView();
      default:
        return const Center(child: Text('ยินดีต้อนรับสู่ระบบดูแลที่จอดรถ', style: TextStyle(fontSize: 18, color: Colors.black54)));
    }
  }

  // ==========================================
  // หน้าต่าง ๆ
  // ==========================================
  
  // Database History
  Widget _buildDatabaseHistoryView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประวัติการจอดและการชำระเงิน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0000CD))),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
            child: _bookings.isEmpty
                ? const Center(child: Text('ไม่พบข้อมูล)', style: TextStyle(color: Colors.black54, fontSize: 16)))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.resolveWith((states) => Colors.grey.shade100),
                      columns: const [
                        DataColumn(label: Text('รหัสการจอง', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ช่องจอด', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ทะเบียนรถ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('เวลาเข้า', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('เวลาออก', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('ยอดชำระ', style: TextStyle(fontWeight: FontWeight.bold))),
                        DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
                      ],
                      rows: const [],
                    ),
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // Analytics
  Widget _buildAnalyticsView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ข้อมูลการใช้งานพื้นที่จอดรถ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0000CD))),
          const SizedBox(height: 24),

          Row(
            children: [
              _buildStatCard('รายได้ประจำวัน', _analytics['daily_income']?.toString() ?? 'ไม่พบข้อมูล', Icons.attach_money, Colors.green),
              const SizedBox(width: 16),
              _buildStatCard('อัตราการใช้งานพื้นที่', _analytics['usage_percent']?.toString() ?? 'ไม่พบข้อมูล', Icons.pie_chart, Colors.blue),
              const SizedBox(width: 16),
              _buildStatCard('จำนวนรถเข้า/ออก', _analytics['in_out_count']?.toString() ?? 'ไม่พบข้อมูล', Icons.swap_horiz, Colors.orange),
            ],
          ),
          const SizedBox(height: 32),
  // สร้างกราฟแสดงผล
  Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('สถิติการใช้งานพื้นที่จอดรถ (รายสัปดาห์)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),

        if (_analytics['weekly_chart'] == null || (_analytics['weekly_chart'] as List).isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('ไมพบข้อมูล', style: TextStyle(color: Colors.black54))),
            )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: (_analytics['weekly_chart'] as List).map((data) => _buildBarChart(data['value'], data['label'])).toList(),
            )
      ],
    ),
          )
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)),
                Icon(icon, color: color),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBarChart(double height, String label) {
    return Column(
      children: [
        Container(
          width: 30, height: height,
          decoration: BoxDecoration(color: const Color(0xFF0000CD), borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }

  // ประวัติการทำงานฮาร์ดแวร์และสถานะอุปกรณ์
  Widget _buildHardwareLogsView() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('สถานะของอุปกรณ์', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0000CD))),
          const SizedBox(height: 24),
          
          Row(
            children: [
              _buildDeviceStatusCard('Webcam', _cameraStatus['webcam'] ?? 'ขาดการเชื่อมต่อ', Icons.videocam, _cameraStatus['webcam'] != null ? Colors.green : Colors.red),
              const SizedBox(width: 16),
              _buildDeviceStatusCard('ESP32-CAM', _cameraStatus['esp32_cam'] ?? 'ขาดการเชื่อมต่อ', Icons.camera, _cameraStatus['esp32_cam'] != null ? Colors.green : Colors.red),
              const SizedBox(width: 16),
              _buildDeviceStatusCard('ESP32-WROOM', _cameraStatus['esp32_wroom'] ?? 'ขาดการเชื่อมต่อ', Icons.camera, _cameraStatus['esp32_wroom'] != null ? Colors.green : Colors.red),
              const SizedBox(width: 16),
              _buildDeviceStatusCard('IR Sensor(1)', _cameraStatus['ir_sensor1'] ?? 'ขาดการเชื่อมต่อ', Icons.sensors, _cameraStatus['ir_sensor1'] != null ? Colors.green : Colors.red),
              const SizedBox(width: 16),
              _buildDeviceStatusCard('IR Sensor(2)', _cameraStatus['ir_sensor2'] ?? 'ขาดการเชื่อมต่อ', Icons.sensors, _cameraStatus['ir_sensor2'] != null ? Colors.green : Colors.red),
              const SizedBox(width: 16),
              _buildDeviceStatusCard('Servo Motor', _cameraStatus['servo_motor'] ?? 'ขาดการเชื่อมต่อ', Icons.toll, _cameraStatus['servo_motor'] != null ? Colors.green : Colors.red),
            ],
          ),
          const SizedBox(height: 24),

          const Text('ประวัติการทำงานของอุปกรณ์', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
              child: _hardwareLogs.isEmpty 
                  ? const Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.black54)))
                  : SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(label: Text('อุปกรณ์', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('สถานะการทำงาน', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('เวลาประมวลผล', style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text('รายละเอียด', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        rows: _hardwareLogs.map((log) => DataRow(cells: [
                          DataCell(Text(log['device'] ?? '')),
                          DataCell(Text(log['status'] ?? '')),
                          DataCell(Text(log['time'] ?? '')),
                          DataCell(Text(log['detail'] ?? '')),
                        ])).toList(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceStatusCard(String name, String status, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.black12)),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color.withValues(alpha: 0.1), child: Icon(icon, color: color)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  // แทรกแซงระบบฉุกเฉิน
  Widget _buildEmergencyOverrideView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.warning, color: Colors.orange, size: 32),
              SizedBox(width: 12),
              Text('ระบบแทรกแซงฉุกเฉิน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.orange)),
            ],
          ),
          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('ควบคุมไม้กั้นทางเข้า-ออก', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('สถานะปัจจุบัน: ${_isBarrierOpen == null ? "ขาดการเชื่อมต่อ" : _isBarrierOpen! ? "เปิด" : "ปิด"}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
                FilledButton.icon(
                  onPressed: _isBarrierOpen == null ? null : () async {
                    final action = _isBarrierOpen == true ? "close" : "open";
              
                    try {
                      await ApiService.overrideServo(action);

                    if (!mounted) return;
                      setState(() => _isBarrierOpen = !_isBarrierOpen!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เปลี่ยนสถานะไม้กั้นสำเร็จ!'), backgroundColor: Colors.green)
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'), backgroundColor: Colors.red)
                      );
                    }
                  },
                  icon: Icon(_isBarrierOpen == true ? Icons.lock : Icons.lock_open),
                  label: Text(_isBarrierOpen == true ? 'สั่งปิดไม้กั้น' : 'สั่งเปิดไม้กั้น'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _isBarrierOpen == true ? Colors.red : Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // แทรกแซงสถานะช่องจอด
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.black12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('จัดการสถานะช่องจอด', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('กรณีอุปกรณ์ขัดข้องหรือระบบทำงานผิดพลาดเท่านั้น!', style: TextStyle(color: Colors.black54)),
                SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // จัดการผู้ดูแลระบบ
  Widget _buildAddAdminView() {
    const primaryColor = Color(0xFF0000CD);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ข้อมูลผู้ดูแลระบบ
          const Text('จัดการผู้ดูแลระบบ', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white, 
              borderRadius: BorderRadius.circular(12), 
              border: Border.all(color: Colors.black12)
            ),
            child: _adminList.isEmpty 
                ? const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('ไม่พบข้อมูล', style: TextStyle(color: Colors.black54))),
                  )
                : DataTable(
                    columns: const [
                      DataColumn(label: Text('สถานะ', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ชื่อ-นามสกุล', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('ชื่อผู้ใช้งาน', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('เข้าใช้งานล่าสุด', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _adminList.map((adm) {
                      bool isActive = adm['is_active'] == true;
                      return DataRow(cells: [
                        DataCell(Row(children: [
                          Container(
                            width: 12, height: 12, 
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF228B22) : const Color(0xFFCD2626), 
                              shape: BoxShape.circle
                            )
                          ), 
                          const SizedBox(width: 8),
                          Text(isActive ? 'Active' : 'Offline', style: TextStyle(color: isActive ? const Color(0xFF228B22) : const Color(0xFFCD2626), fontWeight: FontWeight.bold))
                        ])),
                        DataCell(Text(adm['name'] ?? '-')),
                        DataCell(Text(adm['username'] ?? '-')),
                        DataCell(Text(adm['created_at'] ?? '-')),
                      ]);
                    }).toList(),
                  ),
          ),
          
          const SizedBox(height: 48),

          // การเพิ่มผู้ดูแลระบบ
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.person_add_alt_1, color: primaryColor, size: 32),
                            SizedBox(width: 12),
                            Text('ลงทะเบียนผู้ดูแลระบบใหม่', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('สร้างบัญชี', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 32),

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'ชื่อจริง (First Name)',
                                  prefixIcon: Icon(Icons.badge, color: primaryColor),
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อจริง' : null,
                              ),
                            ),
                            const SizedBox(width: 16),

                            Expanded(
                              child: TextFormField(
                                controller: _lastNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'นามสกุล (Last Name)',
                                  prefixIcon: Icon(Icons.badge, color: primaryColor),
                                  border: OutlineInputBorder(),
                                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                                ),
                                validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกนามสกุล' : null,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // username
                        TextFormField(
                          controller: _usernameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ชื่อผู้ใช้งาน (Username)',
                            prefixIcon: Icon(Icons.person, color: primaryColor),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อผู้ใช้งาน' : null,
                        ),
                        const SizedBox(height: 16),

                        // รหัสผ่าน
                        TextFormField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'รหัสผ่าน (Password)',
                            prefixIcon: Icon(Icons.lock, color: primaryColor),
                            border: OutlineInputBorder(),
                            focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: primaryColor, width: 2)),
                          ),
                          validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                        ),
                        const SizedBox(height: 32),

                        // ปุ่มยืนยัน
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                await ApiService.addAdmin(
                                  _firstNameCtrl.text,
                                  _lastNameCtrl.text,
                                  _usernameCtrl.text,
                                  _passwordCtrl.text,
                                );
                                if (!mounted) return; 
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('บันทึกข้อมูลสำเร็จ', style: TextStyle(fontWeight: FontWeight.bold)),
                                    backgroundColor: Color(0xFF228B22), 
                                    behavior: SnackBarBehavior.floating, 
                                    ),
                                  );
                                  _firstNameCtrl.clear();
                                  _lastNameCtrl.clear();
                                  _usernameCtrl.clear();
                                  _passwordCtrl.clear();
                                  _fetchAdminList();
                               }
                            },
                            child: const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
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