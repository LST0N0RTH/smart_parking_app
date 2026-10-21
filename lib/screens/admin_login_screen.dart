import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';

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
  int _failedAttempts = 0;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final provider = context.read<ParkingProvider>();
        final loggedIn = await provider.loginAdmin(
          _usernameCtrl.text.trim(),
          _passwordCtrl.text,
        );
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          if (!loggedIn && provider.loginError == null) _failedAttempts++;
        });
        if (loggedIn) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  provider.loginError ?? 'ชื่อผู้ใช้หรือรหัสผ่านไม่ถูกต้อง'),
              backgroundColor: const Color(0xFFCD2626),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ไม่สามารถติดต่อระบบผู้ดูแลได้ กรุณาลองใหม่'),
            backgroundColor: Color(0xFFCD2626),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _showForgotPasswordDialog() async {
    final emailController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ลืมรหัสผ่าน?'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'อีเมล'),
            validator: (value) =>
                value == null || value.trim().isEmpty ? 'กรุณากรอกอีเมล' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () {
              if (!formKey.currentState!.validate()) return;
              Navigator.of(dialogContext).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                      'ส่งลิงก์รีเซ็ตไปยัง ${emailController.text.trim()}'),
                ),
              );
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
    emailController.dispose();
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
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 10,
                        offset: Offset(0, 4))
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.admin_panel_settings,
                            size: 64, color: primaryColor),
                        const SizedBox(height: 16),
                        const Text('Admin Portal',
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: primaryColor)),
                        const SizedBox(height: 8),
                        const Text('เข้าสู่ระบบสำหรับผู้ดูแลพื้นที่จอดรถ',
                            style: TextStyle(color: Colors.black54)),
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

                          if (_failedAttempts >= 3)
                          const Text(
                            'หากลืมรหัสผ่าน คุณสามารถขอรีเซ็ตทางอีเมลได้',
                            style: TextStyle(color: Colors.red),
                          ),
                        TextButton(
                          onPressed:
                              _isLoading ? null : _showForgotPasswordDialog,
                          child: const Text('ลืมรหัสผ่าน?'),
                        ),

                          // ปุ่มกลับสู่หน้าหลัก
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            child: const Text('กลับสู่หน้าหลัก (สำหรับผู้ใช้บริการ)', style: TextStyle(color: Colors.black54)),
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