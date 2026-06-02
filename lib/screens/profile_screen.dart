import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../providers/parking_provider.dart';
import 'login_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isEditing = false;
  bool _loading = false;
  bool _dataLoaded = false;

  late TextEditingController _nameCtrl;
  late TextEditingController _emailCtrl;
  
  List<TextEditingController> _plateCtrls = [];
  List<TextEditingController> _provinceCtrls = [];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _emailCtrl = TextEditingController();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final provider = context.read<ParkingProvider>();
    await provider.fetchUserProfile();
    if (mounted) {
      setState(() {
        _nameCtrl.text = provider.userName;
        _emailCtrl.text = provider.userEmail;
        _plateCtrls = [];
        _provinceCtrls = [];

        if (provider.userPlates.isEmpty) {
          _plateCtrls.add(TextEditingController(text: ''));
          _provinceCtrls.add(TextEditingController(text: ''));
        } else {
          // 🌟 วนลูปแกะป้ายทะเบียนเพื่อแยก ทะเบียน กับ จังหวัด ออกจากกัน
          for (var currentPlate in provider.userPlates) {
            if (currentPlate.contains(' ')) {
              int lastSpace = currentPlate.lastIndexOf(' ');
              _plateCtrls.add(TextEditingController(text: currentPlate.substring(0, lastSpace)));
              _provinceCtrls.add(TextEditingController(text: currentPlate.substring(lastSpace + 1)));
            } else {
              _plateCtrls.add(TextEditingController(text: currentPlate));
              _provinceCtrls.add(TextEditingController(text: ''));
            }
          }
        }  
        _dataLoaded = true;
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    for (var ctrl in _plateCtrls) { ctrl.dispose(); }
    for (var ctrl in _provinceCtrls) { ctrl.dispose(); }
    super.dispose();
  }

  void _addPlate() {
    if (_plateCtrls.length < 5) {
      setState(() {
        _plateCtrls.add(TextEditingController());
        _provinceCtrls.add(TextEditingController()); // 🌟 เพิ่มช่องจังหวัดคู่กัน
      });
    }
  }

  void _removePlate(int index) {
    setState(() {
      _plateCtrls[index].dispose();
      _provinceCtrls[index].dispose();
      _plateCtrls.removeAt(index);
      _provinceCtrls.removeAt(index);
    });
  }

  Future<void> _saveData() async {
    setState(() => _loading = true);
    final provider = context.read<ParkingProvider>();
    final newPlates = <String>[];
    for (int i = 0; i < _plateCtrls.length; i++) {
      final plateText = _plateCtrls[i].text.trim();
      final provinceText = _provinceCtrls[i].text.trim();
      
      if (plateText.isNotEmpty) {
        if (provinceText.isNotEmpty) {
          newPlates.add("$plateText $provinceText"); // รวมร่าง เช่น "กข1234 กรุงเทพฯ"
        } else {
          newPlates.add(plateText);
        }
      }
    }  

    final success = await ApiService.updateProfile(
      _nameCtrl.text.trim(),
      newPlates,
    );

    if (success && mounted) {
      await provider.fetchUserProfile(); 
      if (!mounted) return;
      setState(() {
        _isEditing = false;
        _loading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกข้อมูลเรียบร้อยแล้ว'), backgroundColor: Color(0xFF1D9E75))
      );
    } else if (mounted) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล'), backgroundColor: Colors.red)
      );
    }
  }

  Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool showPass = false;
    bool isSavingPass = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('เปลี่ยนรหัสผ่าน', style: TextStyle(color: Color(0xFF0000CD), fontWeight: FontWeight.bold)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('กรุณากรอกรหัสผ่านใหม่ให้ตรงกัน', style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่านใหม่',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณากรอกรหัสผ่าน';
                    if (v.length < 6) return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัว';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPassCtrl,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: 'ยืนยันรหัสผ่านใหม่',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: IconButton(
                      icon: Icon(showPass ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9E9E9E)),
                      onPressed: () => setDialogState(() => showPass = !showPass),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'กรุณายืนยันรหัสผ่าน';
                    if (v != newPassCtrl.text) return 'รหัสผ่านไม่ตรงกัน!'; 
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
            ),
            FilledButton(
              onPressed: isSavingPass ? null : () async {
                if (formKey.currentState!.validate()) {
                  setDialogState(() => isSavingPass = true);
                  final provider = context.read<ParkingProvider>();
                  final success = await ApiService.updateProfile(provider.userName, provider.userPlates, password: newPassCtrl.text);
                  
                  if (!context.mounted) return;
                  Navigator.pop(ctx);
                  
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เปลี่ยนรหัสผ่านสำเร็จ!'), backgroundColor: Color(0xFF1D9E75)),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('เปลี่ยนรหัสผ่านไม่สำเร็จ'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0000CD)),
              child: isSavingPass 
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('บันทึกรหัสผ่าน', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);
    const secondaryGrey = Color(0xFFDCDCDC);

    if (!_dataLoaded) {
      return const Scaffold(
        backgroundColor: Color(0xFFF5F5F5),
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold( 
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ข้อมูลบัญชี', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
                  FilledButton.icon(
                    onPressed: _loading ? null : (_isEditing ? _saveData : () => setState(() => _isEditing = true)), 
                    style: FilledButton.styleFrom(
                      backgroundColor: _isEditing ? const Color(0xFF1D9E75) : primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _loading 
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Icon(_isEditing ? Icons.check : Icons.edit, size: 18, color: Colors.white),
                    label: Text(_isEditing ? 'บันทึก' : 'แก้ไข', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              Card(
                elevation: 3,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildField('ชื่อ-นามสกุล', _nameCtrl, Icons.person_outline, _isEditing),
                      const SizedBox(height: 16),
                      _buildField('อีเมล', _emailCtrl, Icons.email_outlined, false), 
                      const SizedBox(height: 16),
                      
                      InkWell(
                        onTap: _showChangePasswordDialog, 
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _isEditing ? secondaryGrey : Colors.transparent),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lock_outline, color: Colors.grey),
                              const SizedBox(width: 12),
                              const Expanded(child: Text('••••••••', style: TextStyle(letterSpacing: 2))),
                              TextButton(
                                onPressed: _showChangePasswordDialog,
                                style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                child: const Text('เปลี่ยนรหัส', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const Divider(height: 48, color: secondaryGrey),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('รถของคุณ (สูงสุด 5 คัน)', style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                          Text('${_plateCtrls.length}/5'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      ..._plateCtrls.asMap().entries.map((e) {
                        final index = e.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            children: [
                              // ช่องกรอกเลขทะเบียน
                              Expanded(
                                flex: 4,
                                child: _buildField(
                                  'ทะเบียนคันที่ ${index + 1}', 
                                  _plateCtrls[index], 
                                  Icons.directions_car_outlined, 
                                  _isEditing,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // ช่องกรอกจังหวัด
                              Expanded(
                                flex: 3,
                                child: _buildField(
                                  'จังหวัด', 
                                  _provinceCtrls[index], 
                                  Icons.map_outlined, 
                                  _isEditing, 
                                  suffix: _isEditing && index > 0 
                                      ? IconButton(icon: const Icon(Icons.remove_circle, color: Colors.red), onPressed: () => _removePlate(index)) 
                                      : null,
                                  textAction: index == _plateCtrls.length - 1 ? TextInputAction.done : TextInputAction.next
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                      if (_isEditing && _plateCtrls.length < 5)
                        TextButton.icon(
                          onPressed: _addPlate, 
                          icon: const Icon(Icons.add, color: primaryColor), 
                          label: const Text('เพิ่มรถ', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              OutlinedButton.icon(
                onPressed: () async {
                  await context.read<ParkingProvider>().logout();
                  if (context.mounted) {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (context) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                icon: const Icon(Icons.logout, color: Colors.red),
                label: const Text('ออกจากระบบ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Colors.red),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, IconData icon, bool enabled, {Widget? suffix, TextInputAction textAction = TextInputAction.next}) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      textInputAction: textAction,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.transparent)),
        filled: !enabled,
        fillColor: enabled ? Colors.transparent : Colors.grey.shade100,
      ),
      style: TextStyle(color: enabled ? Colors.black : Colors.black87, fontWeight: FontWeight.bold),
    );
  }
}