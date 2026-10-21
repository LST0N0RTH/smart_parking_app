import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/payment_card.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';
import 'add_card_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _successColor = Color(0xFF1D9E75);

  bool _isEditing = false;
  bool _loading = false;
  bool _isLoadingProfile = false;
  bool _isLoggingOut = false;
  bool _showLoadingOverlay = false;
  bool _dataLoaded = false;
  List<PaymentCard> _paymentCards = [];
  bool _isLoadingCards = false;
  String? _profileError;
  String? _cardsError;

  final _nameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  List<TextEditingController> _plateCtrls = [];
  List<TextEditingController> _provinceCtrls = [];
  Timer? _loadingOverlayTimer;

  bool get _isBusy {
    return _loading || _isLoadingProfile || _isLoadingCards || _isLoggingOut;
  }
  int get _vehicleCount {
    return _plateCtrls
        .where((controller) => controller.text.trim().isNotEmpty)
        .length;
  }

  @override
  void initState() {
    super.initState();
    unawaited(_loadProfile());
    unawaited(_loadPaymentCards());
  }

  void _scheduleLoadingOverlay() {
    if (_showLoadingOverlay || _loadingOverlayTimer?.isActive == true) return;
    _loadingOverlayTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _isBusy) {
        setState(() => _showLoadingOverlay = true);
      }
    });
  }

  void _hideLoadingOverlayIfIdle() {
    if (_isBusy) return;
    _loadingOverlayTimer?.cancel();
    _loadingOverlayTimer = null;

    if (_showLoadingOverlay && mounted) {
      setState(() => _showLoadingOverlay = false);
    }
  }

  void _replaceVehicleControllers(List<RegisteredVehicle> vehicles) {
    for (final controller in _plateCtrls) {
      controller.dispose();
    }
    for (final controller in _provinceCtrls) {
      controller.dispose();
    }
    _plateCtrls = vehicles
        .map((vehicle) => TextEditingController(text: vehicle.plateNumber))
        .toList();
    _provinceCtrls = vehicles
        .map((vehicle) => TextEditingController(text: vehicle.province))
        .toList();

    if (_plateCtrls.isEmpty) {
      _plateCtrls.add(TextEditingController());
      _provinceCtrls.add(TextEditingController());
    }
  }

  void _applyProfile(ParkingProvider provider) {
    _nameCtrl.text = provider.userName;
    _usernameCtrl.text = provider.userUsername;
    _emailCtrl.text = provider.userEmail;
    _replaceVehicleControllers(provider.userVehicles);
  }

  Future<void> _loadProfile() async {
    if (_isLoadingProfile) return;
    setState(() {
      _isLoadingProfile = true;
      _profileError = null;
    });
    _scheduleLoadingOverlay();

    final provider = context.read<ParkingProvider>();
    final loaded = await provider.fetchUserProfile();

    if (!mounted) return;
    setState(() {
      _isLoadingProfile = false;
      _dataLoaded = loaded;
      _profileError = loaded ? null : 'ไม่สามารถโหลดข้อมูลส่วนบุคคลได้';

      if (loaded) {
        _applyProfile(provider);
      }
    });
    _hideLoadingOverlayIfIdle();
  }

  Future<void> _loadPaymentCards() async {
    if (_isLoadingCards) return;
    setState(() {
      _isLoadingCards = true;
      _cardsError = null;
    });
    _scheduleLoadingOverlay();
    try {
      final cards = await ApiService.getPaymentCards();

      if (!mounted) return;
      setState(() {
        _paymentCards = cards;
      });
    } on ApiRequestException catch (error) {
      if (!mounted) return;
      setState(() => _cardsError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _cardsError = 'ไม่สามารถโหลดข้อมูลบัตรได้');
    } finally {
      if (mounted) {
        setState(() => _isLoadingCards = false);
        _hideLoadingOverlayIfIdle();
      }
    }
  }

  @override
  void dispose() {
    _loadingOverlayTimer?.cancel();
    _nameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();

    for (final controller in _plateCtrls) {
      controller.dispose();
    }
    for (final controller in _provinceCtrls) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addVehicle() {
    if (_plateCtrls.length < 5) {
      setState(() {
        _plateCtrls.add(TextEditingController());
        _provinceCtrls.add(TextEditingController());
      });
    }
  }

  void _removeVehicle(int index) {
    setState(() {
      if (_plateCtrls.length == 1) {
        _plateCtrls.first.clear();
        _provinceCtrls.first.clear();
        return;
      }
      _plateCtrls.removeAt(index).dispose();
      _provinceCtrls.removeAt(index).dispose();
    });
  }

  Future<void> _saveData() async {
    final username = _usernameCtrl.text.trim();

    if (username.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อผู้ใช้งาน'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final vehicles = <Map<String, String>>[];
    final vehicleKeys = <String>{};

    for (var index = 0; index < _plateCtrls.length; index++) {
      final plate = _plateCtrls[index].text.trim();
      final province = _provinceCtrls[index].text.trim();
      if (plate.isEmpty && province.isEmpty) continue;
      if (plate.isEmpty || province.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('รถทุกคันต้องมีทั้งทะเบียนรถและจังหวัด'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final vehicleKey = '${plate.toLowerCase()}|${province.toLowerCase()}';

      if (!vehicleKeys.add(vehicleKey)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('มีทะเบียนรถและจังหวัดซ้ำกัน'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      vehicles.add({
        'plate_number': plate,
        'province': province,
      });
    }
    setState(() => _loading = true);
    _scheduleLoadingOverlay();

    final provider = context.read<ParkingProvider>();
    final success = await provider.updateUserProfile(
      username: username,
      vehicles: vehicles,
    );

    if (!mounted) return;
    setState(() {
      _loading = false;
      if (success) {
        _applyProfile(provider);
        _isEditing = false;
      }
    });
    _hideLoadingOverlayIfIdle();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'บันทึกข้อมูลเรียบร้อยแล้ว!'
              : 'บันทึกข้อมูลไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
        ),
        backgroundColor: success ? _successColor : Colors.red,
      ),
    );
  }

    Future<void> _showChangePasswordDialog() async {
    final formKey = GlobalKey<FormState>();
    final newPassCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    bool showPass = false;
    bool isSavingPass = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'เปลี่ยนรหัสผ่าน',
            style: TextStyle(
              color: Color(0xFF0000CD),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'กรุณากรอกรหัสผ่านใหม่ให้ตรงกัน',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPassCtrl,
                  obscureText: !showPass,
                  decoration: InputDecoration(
                    labelText: 'รหัสผ่านใหม่',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณากรอกรหัสผ่าน';
                    }
                    if (value.length < 8) {
                      return 'รหัสผ่านต้องมีอย่างน้อย 8 ตัว';
                    }
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
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(
                        showPass ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF9E9E9E),
                      ),
                      onPressed: isSavingPass
                          ? null
                          : () => setDialogState(() => showPass = !showPass),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'กรุณายืนยันรหัสผ่าน';
                    }
                    if (value != newPassCtrl.text) {
                      return 'รหัสผ่านไม่ตรงกัน!';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSavingPass ? null : () => Navigator.pop(ctx),
              child: const Text(
                'ยกเลิก',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            FilledButton(
              onPressed: isSavingPass
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSavingPass = true);
                      final provider = context.read<ParkingProvider>();
                      final success = await ApiService.updateProfile(
                        provider.userName,
                        provider.userPlates,
                        password: newPassCtrl.text,
                        passwordConfirmation: confirmPassCtrl.text,
                      );
                      if (!dialogContext.mounted) return;
                      Navigator.pop(ctx);
                      if (!mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('เปลี่ยนรหัสผ่านสำเร็จ!'),
                            backgroundColor: Color(0xFF1D9E75),
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'เปลี่ยนรหัสผ่านไม่สำเร็จ กรุณาลองใหม่อีกครั้ง',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0000CD),
              ),
              child: isSavingPass
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'บันทึกรหัสผ่าน',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
  }

  Future<void> _openAddCard() async {
    if (_paymentCards.length >= 3 || _isBusy) return;

    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddCardScreen()),
    );

    if (saved != true || !mounted) return;
    await _loadPaymentCards();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เพิ่มบัตรเครดิต/บัตรเดบิตสำเร็จ!'),
        backgroundColor: _successColor,
      ),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    _scheduleLoadingOverlay();

    final success = await context.read<ParkingProvider>().logout();

    if (!mounted) return;
    setState(() => _isLoggingOut = false);
    _hideLoadingOverlayIfIdle();

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถออกจากระบบได้ กรุณาลองใหม่อีกครั้ง',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

    @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);
    const secondaryGrey = Color(0xFFDCDCDC);

    if (!_dataLoaded) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F5F5),
        body: _withLoadingOverlay(
          Center(
            child: _profileError == null
                ? const Text(
                    'กำลังโหลดข้อมูลส่วนบุคคล...',
                    style: TextStyle(color: Colors.black54),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _profileError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _isLoadingProfile ? null : _loadProfile,
                        icon: const Icon(Icons.refresh),
                        label: const Text('ลองใหม่'),
                      ),
                    ],
                  ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: _withLoadingOverlay(
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'ข้อมูลส่วนบุคคล',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _isBusy
                          ? null
                          : (_isEditing
                                ? _saveData
                                : () => setState(() => _isEditing = true)),
                      style: FilledButton.styleFrom(
                        backgroundColor: _isEditing
                            ? _successColor
                            : primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: _loading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Icon(
                              _isEditing ? Icons.check : Icons.edit,
                              size: 18,
                              color: Colors.white,
                            ),
                      label: Text(
                        _isEditing ? 'บันทึก' : 'แก้ไข',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Card(
                  elevation: 3,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildField(
                          'ชื่อ-นามสกุล',
                          _nameCtrl,
                          Icons.person_outline,
                          false,
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          'ชื่อผู้ใช้งาน',
                          _usernameCtrl,
                          Icons.alternate_email,
                          _isEditing,
                        ),
                        const Padding(
                          padding: EdgeInsets.only(top: 6, left: 4),
                          child: Text(
                            'สามารถเปลี่ยนชื่อผู้ใช้งานได้ทุก 7 วัน',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildField(
                          'อีเมล',
                          _emailCtrl,
                          Icons.email_outlined,
                          false,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: _isBusy ? null : _showChangePasswordDialog,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _isEditing
                                    ? secondaryGrey
                                    : Colors.transparent,
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.lock_outline,
                                  color: Colors.grey,
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    '••••••••',
                                    style: TextStyle(letterSpacing: 2),
                                  ),
                                ),
                                TextButton(
                                  onPressed: _isBusy
                                      ? null
                                      : _showChangePasswordDialog,
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                  ),
                                  child: const Text(
                                    'เปลี่ยนรหัส',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 48, color: secondaryGrey),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'รถของคุณ (สูงสุด 5 คัน)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                            Text('$_vehicleCount/5'),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ..._plateCtrls.asMap().entries.map((entry) {
                          final index = entry.key;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 4,
                                  child: _buildField(
                                    'ทะเบียนคันที่ ${index + 1}',
                                    _plateCtrls[index],
                                    Icons.directions_car_outlined,
                                    _isEditing,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 3,
                                  child: _buildField(
                                    'จังหวัด',
                                    _provinceCtrls[index],
                                    Icons.map_outlined,
                                    _isEditing,
                                    suffix: _isEditing
                                        ? IconButton(
                                            icon: const Icon(
                                              Icons.remove_circle,
                                              color: Colors.red,
                                            ),
                                            onPressed: () =>
                                                _removeVehicle(index),
                                          )
                                        : null,
                                    textAction: index == _plateCtrls.length - 1
                                        ? TextInputAction.done
                                        : TextInputAction.next,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        if (_isEditing && _plateCtrls.length < 5)
                          TextButton.icon(
                            onPressed: _addVehicle,
                            icon: const Icon(
                              Icons.add,
                              color: primaryColor,
                            ),
                            label: const Text(
                              'เพิ่มทะเบียนรถ',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'ช่องทางการชำระเงิน',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'เลือกวิธีชำระเงิน (สามารถเปลี่ยนได้อีกครั้งภายหลัง)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 3,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        const ListTile(
                          leading: Icon(
                            Icons.qr_code_2,
                            color: primaryColor,
                            size: 30,
                          ),
                          title: Text(
                            'PromptPay QR',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1, indent: 60),
                        ExpansionTile(
                          leading: const Icon(
                            Icons.phone_android,
                            color: primaryColor,
                            size: 30,
                          ),
                          title: const Text(
                            'Mobile Banking',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: const Text(
                            'ดูรายชื่อธนาคารที่รองรับ',
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                0,
                                20,
                                16,
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    const [
                                          'ธนาคารกสิกรไทย (KBANK)',
                                          'ธนาคารไทยพาณิชย์ (SCB)',
                                          'ธนาคารกรุงไทย (KTB)',
                                          'ธนาคารกรุงเทพ (BBL)',
                                          'ธนาคารกรุงศรีอยุธยา (BAY)',
                                          'ธนาคารทหารไทยธนชาต (TTB)',
                                          'ธนาคารออมสิน (GSB)',
                                        ]
                                        .map(
                                          (bank) => Chip(
                                            label: Text(bank),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 1, indent: 60),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'บัตรเครดิต/บัตรเดบิต',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text('${_paymentCards.length}/3'),
                            ],
                          ),
                        ),
                        if (_cardsError != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  _cardsError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _isLoadingCards
                                      ? null
                                      : _loadPaymentCards,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('ลองใหม่'),
                                ),
                              ],
                            ),
                          )
                        else if (_isLoadingCards && _paymentCards.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'กำลังโหลดข้อมูลบัตร...',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else if (_paymentCards.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'ไม่พบบัตรที่บันทึกไว้',
                              style: TextStyle(color: Colors.black54),
                            ),
                          )
                        else
                          for (final card in _paymentCards) ...[
                            ListTile(
                              leading: const Icon(
                                Icons.credit_card,
                                color: primaryColor,
                                size: 30,
                              ),
                              title: Text(
                                card.displayLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Text(
                                '${card.holderName} • หมดอายุ ${card.expiryDate}',
                              ),
                            ),
                            const Divider(
                              height: 1,
                              indent: 60,
                              color: secondaryGrey,
                            ),
                          ],
                        if (_paymentCards.length < 3)
                          ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.black26,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.black54,
                                size: 20,
                              ),
                            ),
                            title: const Text(
                              'เพิ่มบัตรเครดิต/บัตรเดบิตใหม่',
                              style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: _openAddCard,
                          )
                        else
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'ไม่สามารถบันทึกบัตรเครดิต/บัตรเดบิตได้ เนื่องจากครบจำนวนสูงสุดแล้ว',
                              style: TextStyle(color: Colors.black54),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: _isBusy ? null : _logout,
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.red,
                  ),
                  label: const Text(
                    'ออกจากระบบ',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _withLoadingOverlay(Widget child) {
    return Stack(
      children: [
        child,
        if (_showLoadingOverlay)
          const Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(
                color: Color(0x1A000000),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SafeArea(
                    child: LinearProgressIndicator(
                      color: Color(0xFF0000CD),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController ctrl,
    IconData icon,
    bool enabled, {
    Widget? suffix,
    TextInputAction textAction = TextInputAction.next,
    ValueChanged<String>? onChanged,
  }) {
    return TextFormField(
      controller: ctrl,
      enabled: enabled,
      textInputAction: textAction,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Colors.transparent,
          ),
        ),
        filled: !enabled,
        fillColor: enabled
            ? Colors.transparent
            : Colors.grey.shade100,
      ),
      style: TextStyle(
        color: enabled ? Colors.black : Colors.black87,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}