import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _plate = TextEditingController();
  final _province = TextEditingController();

  bool _loading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  String? _error;

  Future<void> _register() async {
    if (_loading) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final provider = context.read<ParkingProvider>();
    final success = await provider.register(
      _name.text.trim(),
      _email.text.trim(),
      _password.text,
      _plate.text.trim(),
      username: _username.text.trim(),
      passwordConfirmation: _confirm.text,
      province: _province.text.trim(),
    );

    if (!mounted) return;
    setState(() => _loading = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('สมัครสมาชิกสำเร็จ!'),
          backgroundColor: Color(0xFF1D9E75),
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() =>
          _error = provider.registrationError ?? 'ไม่สามารถสมัครสมาชิกได้ อีเมลนี้อาจถูกใช้งานแล้ว');
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    _plate.dispose();
    _province.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);
    const secondaryGrey = Color(0xFF828282);

    // สร้างฟังก์ชันตกแต่งช่องกรอกข้อมูล เพื่อลดความซ้ำซ้อนของโค้ด
    InputDecoration customInputDecoration(String label, IconData icon,
        {Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        labelStyle: WidgetStateTextStyle.resolveWith((states) =>
            states.contains(WidgetState.focused)
                ? const TextStyle(color: primaryColor)
                : const TextStyle(color: secondaryGrey)),
        prefixIcon: Icon(icon),
        prefixIconColor: WidgetStateColor.resolveWith((states) =>
            states.contains(WidgetState.focused)
                ? primaryColor
                : secondaryGrey),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: secondaryGrey),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // สีพื้นหลังเหมือนหน้า Login
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text('สมัครสมาชิก', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white), // ปุ่มย้อนกลับสีขาว
        centerTitle: true,
        elevation: 2,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Card(
              elevation: 3,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      const Icon(Icons.person_add_alt_1_rounded, size: 56, color: primaryColor),
                      const SizedBox(height: 8),
                      const Text('สร้างบัญชีใหม่',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor)),
                      const SizedBox(height: 28),

                      // ชื่อ-นามสกุล
                      TextFormField(
                        controller: _name,
                        cursorColor: primaryColor,
                        decoration: customInputDecoration(
                          'ชื่อ-นามสกุล',
                          Icons.person_outline,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final name = (value ?? '').trim();
                          if (name.isEmpty) return 'กรุณากรอกชื่อ-นามสกุล';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ชื่อผู้ใช้งาน
                      TextFormField(
                        controller: _username,
                        cursorColor: primaryColor,
                        decoration: customInputDecoration(
                          'ชื่อผู้ใช้งาน (Username)',
                          Icons.account_circle_outlined,
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final username = (value ?? '').trim();
                          if (username.isEmpty) return 'กรุณากรอกชื่อผู้ใช้งาน';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // อีเมล
                      TextFormField(
                        controller: _email,
                        cursorColor: primaryColor,
                        decoration: customInputDecoration('อีเมล', Icons.email_outlined),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final email = (value ?? '').trim();
                          if (email.isEmpty) return 'กรุณากรอกอีเมล';
                          if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                              .hasMatch(email)) {
                            return 'รูปแบบอีเมลไม่ถูกต้อง';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // รหัสผ่าน
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPass,
                        cursorColor: primaryColor,
                        decoration: customInputDecoration(
                          'รหัสผ่าน',
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            color: secondaryGrey,
                            onPressed: () => setState(() => _showPass = !_showPass),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกรหัสผ่าน';
                          }
                          if (value.length < 8) {
                            return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัวอักษร';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ยืนยันรหัสผ่าน
                      TextFormField(
                        controller: _confirm,
                        obscureText: !_showConfirm,
                        cursorColor: primaryColor,
                        decoration: customInputDecoration(
                          'ยืนยันรหัสผ่าน', 
                          Icons.lock_outline,
                          suffixIcon: IconButton(
                            icon: Icon(_showConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            color: secondaryGrey,
                            onPressed: () => setState(() => _showConfirm = !_showConfirm),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                          if (v != _password.text) return 'รหัสผ่านไม่ตรงกัน';
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // ทะเบียนรถ
                      Row(
                        children: [
                          Expanded(
                            flex: 4,
                            child: TextFormField(
                              controller: _plate,
                              cursorColor: primaryColor,
                              decoration: customInputDecoration(
                                'ทะเบียนรถ (ไม่บังคับ)',
                                Icons.directions_car_outlined,
                              ).copyWith(
                                hintText: 'เช่น กข-1234',
                                hintStyle: const TextStyle(color: secondaryGrey),
                              ),
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _province,
                              cursorColor: primaryColor,
                              decoration: customInputDecoration(
                                'จังหวัด (ไม่บังคับ)',
                                Icons.map_outlined,
                              ),
                              textCapitalization: TextCapitalization.words,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _register(),
                            ),
                          ),
                        ],
                      ),
                      
                      // Error message
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCEBEB),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(children: [
                            const Icon(Icons.error_outline, color: Color(0xFFE24B4A), size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_error!,
                                style: const TextStyle(color: Color(0xFF791F1F), fontSize: 13, fontWeight: FontWeight.bold))),
                          ]),
                        ),
                      ],
                      const SizedBox(height: 32),

                      // ปุ่มสมัคร
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: FilledButton(
                          onPressed: _loading ? null : _register,
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _loading
                              ? const SizedBox(
                                  height: 20, width: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('สมัครสมาชิก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // กลับไป Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'มีบัญชีแล้ว? ',
                            style: TextStyle(color: secondaryGrey),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              foregroundColor: primaryColor,
                            ),
                            child: const Text(
                              'เข้าสู่ระบบ',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
      ),
      if (_loading) ...[
        const ModalBarrier(
          dismissible: false,
          color: Color(0x66000000),
        ),
        const Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      ],
    ],
  ),
);
  }
}