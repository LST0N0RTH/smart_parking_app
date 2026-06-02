import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;
  bool _obscurePassword = true;

  // 🌟 1. ตัวนับจำนวนครั้งที่ล็อกอินผิด
  int _failedAttempts = 0;

  Future<void> _login() async {
    if (_email.text.isEmpty || _password.text.isEmpty) {
      setState(() => _error = 'กรุณากรอกข้อมูลให้ครบถ้วน');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      final ok = await context.read<ParkingProvider>().login(
        _email.text.trim(),
        _password.text.trim(),
      );
      
      if (!ok && mounted) {
        setState(() {
          // 🌟 2. ถ้าล็อกอินพลาด ให้บวกตัวนับเพิ่ม
          _failedAttempts++;
          _error = 'อีเมลหรือรหัสผ่านไม่ถูกต้อง';
          _loading = false;
        });
      } else if (ok && mounted) {
        // รีเซ็ตตัวนับถ้าล็อกอินสำเร็จ
        setState(() => _failedAttempts = 0);
        
        // 🌟 3. เปลี่ยนหน้าแบบไม่ให้กดย้อนกลับได้
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()), 
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'เกิดข้อผิดพลาด: $e';
          _loading = false;
        });
      }
    }
  }

  // 🌟 4. ฟังก์ชันหน้าต่าง Popup สำหรับลืมรหัสผ่าน
  void _showForgotPasswordDialog() {
    final resetEmailController = TextEditingController(text: _email.text);
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ลืมรหัสผ่าน?', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0000CD))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('ระบุอีเมลของคุณเพื่อรับลิงก์สำหรับรีเซ็ตรหัสผ่าน', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: resetEmailController,
              decoration: InputDecoration(
                labelText: 'อีเมล',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx), 
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey))
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ระบบได้ส่งลิงก์รีเซ็ตรหัสผ่านไปที่ ${resetEmailController.text} แล้ว'), 
                  backgroundColor: const Color(0xFF228B22)
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0000CD),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('ส่งข้อมูล', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD); 
    const secondaryGrey = Color(0xFF828282); 

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), 
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/logo.png', 
                      width: 200, 
                      height: 200,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.local_parking_rounded, 
                        size: 80, 
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    Text(
                      'Smart Parking',
                      style: GoogleFonts.bowlbyOne(
                        fontSize: 36, 
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // ช่องกรอกอีเมล
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next, 
                      cursorColor: primaryColor,
                      decoration: InputDecoration(
                        labelText: 'อีเมล',
                        labelStyle: WidgetStateTextStyle.resolveWith((states) => 
                            states.contains(WidgetState.focused) ? const TextStyle(color: primaryColor) : const TextStyle(color: secondaryGrey)),
                        prefixIcon: const Icon(Icons.email_outlined),
                        prefixIconColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.focused) ? primaryColor : secondaryGrey),
                        enabledBorder: OutlineInputBorder( 
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: secondaryGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ช่องกรอกรหัสผ่าน
                    TextField(
                      controller: _password,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done, 
                      onSubmitted: (_) => _login(), 
                      cursorColor: primaryColor,
                      decoration: InputDecoration(
                        labelText: 'รหัสผ่าน',
                        labelStyle: WidgetStateTextStyle.resolveWith((states) => 
                            states.contains(WidgetState.focused) ? const TextStyle(color: primaryColor) : const TextStyle(color: secondaryGrey)),
                        prefixIcon: const Icon(Icons.lock_outline),
                        prefixIconColor: WidgetStateColor.resolveWith((states) => 
                            states.contains(WidgetState.focused) ? primaryColor : secondaryGrey),
                        suffixIcon: IconButton(
                          icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                          color: secondaryGrey,
                        ),
                        enabledBorder: OutlineInputBorder( 
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: secondaryGrey),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 2),
                        ),
                      ),
                    ),

                    // แสดง Error Message
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],

                    if (_failedAttempts >= 3)
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text('ลืมรหัสผ่านใช่หรือไม่?', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ),
                      ),

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _loading ? null : _login,
                        style: FilledButton.styleFrom(
                          backgroundColor: primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(height: 20, width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('เข้าสู่ระบบ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('ยังไม่มีบัญชีใช่ไหม?', style: TextStyle(color: Color(0xFF828282))), 
                        TextButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const RegisterScreen(),
                              ),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: primaryColor,
                          ),
                          child: const Text('สมัครสมาชิก', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}