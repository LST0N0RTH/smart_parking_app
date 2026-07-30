import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      // ตรวจสอบสิทธิ์จาก database
      try {
        final role = await ApiService.adminLogin(_usernameCtrl.text, _passwordCtrl.text);
        
        if (!mounted) return;
        setState(() => _isLoading = false);

        // เชื่อม API
        if (role == 'admin') {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminDashboardScreen()));
        } else {
          throw Exception('ไม่พบบัญชี กรุณาลองใหม่อีกครั้ง'); 
        }

      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
      
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ชื่อผู้ใช้งานหรือรหัสผ่านไม่ถูกต้อง กรุณาลองใหม่อีกครั้ง', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Color(0xFFCD2626), 
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } 
  }

 @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 400), 
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))],
                ),
            child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings, size: 64, color: primaryColor),
                        const SizedBox(height: 16),
                        const Text('Admin Portal', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                        const SizedBox(height: 8),
                        const Text('เข้าสู่ระบบสำหรับผู้ดูแลพื้นที่จอดรถ', style: TextStyle(color: Colors.black54)),
                        const SizedBox(height: 32),

                          // ช่องกรอก Username
                          TextFormField(
                            controller: _usernameCtrl,
                            decoration: const InputDecoration(
                              labelText: 'ชื่อผู้ใช้งาน (Username)',
                              prefixIcon: Icon(Icons.person, color: primaryColor),
                              border: OutlineInputBorder(),
                              focusedBorder: OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกชื่อผู้ใช้งาน' : null,
                          ),
                          const SizedBox(height: 16),

                          // ช่องกรอก Password
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'รหัสผ่าน (Password)',
                              prefixIcon: const Icon(Icons.lock, color: primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.black54,
                                ),
                                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              ),
                              border: const OutlineInputBorder(),
                              focusedBorder: const OutlineInputBorder(
                                borderSide: BorderSide(color: primaryColor, width: 2),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty ? 'กรุณากรอกรหัสผ่าน' : null,
                          ),
                          const SizedBox(height: 32),

                          // ปุ่ม Login
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: FilledButton(
                              style: FilledButton.styleFrom(
                                backgroundColor: primaryColor,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              onPressed: _isLoading ? null : _login,
                              child: const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ปุ่มกลับสู่หน้าหลัก
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            child: const Text('กลับสู่หน้าหลัก (สำหรับผู้ใช้งานทั่วไป)', style: TextStyle(color: Colors.black54)),
                          )
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Overlay Progress Bar
          if (_isLoading)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(color: primaryColor),
              ),
            ),
        ],
      ),
    );
  }
}