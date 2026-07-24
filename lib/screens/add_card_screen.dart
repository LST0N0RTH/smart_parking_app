import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AddCardScreen extends StatefulWidget {
  const AddCardScreen({super.key});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey        = GlobalKey<FormState>();
  final _cardNumberCtrl = TextEditingController();
  final _expiryCtrl     = TextEditingController();
  final _cvvCtrl        = TextEditingController();
  final _nameCtrl       = TextEditingController();
  bool _loading = false;

@override
  void initState() {
    super.initState();
    _cardNumberCtrl.addListener(() => setState(() {}));
    _nameCtrl.addListener(() => setState(() {}));
    _expiryCtrl.addListener(() => setState(() {}));
  }

 @override
  void dispose() {
    _cardNumberCtrl.dispose();
    _expiryCtrl.dispose();
    _cvvCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  void _saveCard() {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      
      // จำลองการบันทึกข้อมูลบัตร
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (!mounted) return;
        setState(() => _loading = false);
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เพิ่มบัตรเครดิต/บัตรเดบิตสำเร็จ'),
            backgroundColor: Color(0xFF228B22),
          ),
        );
      });
    }
  }

  Widget _buildCreditCardMockup() {
    final cardNumber = _cardNumberCtrl.text.isEmpty
        ? '0000 0000 0000 0000'
        : _cardNumberCtrl.text;
    final cardName = _nameCtrl.text.isEmpty
        ? 'ชื่อเจ้าของบัตร'
        : _nameCtrl.text.toUpperCase();
    final expiry = _expiryCtrl.text.isEmpty
        ? 'ดด/ปป'
        : _expiryCtrl.text;

    return Container(
      height: 200,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0000CD), Color(0xFF4169E1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Icon(Icons.memory, color: Colors.amberAccent, size: 36),
              SizedBox(
                width: 48,
                child: Stack(
                  children: [
                    Positioned(
                      right: 16,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 0,
                      child: Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Text(
            cardNumber,
            style: const TextStyle(
              color: Colors.white, fontSize: 22,
              letterSpacing: 2, fontFamily: 'Courier',
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Card Holder',
                        style: TextStyle(color: Colors.white70, fontSize: 10)),
                    const SizedBox(height: 4),
                    Text(cardName,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15,
                            fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Expires',
                      style: TextStyle(color: Colors.white70, fontSize: 10)),
                  const SizedBox(height: 4),
                  Text(expiry,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'เพิ่มบัตรใหม่',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: primaryColor,
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [

                _buildCreditCardMockup(),

                const SizedBox(height: 24),

              // ข้อความแจ้งเตือนความปลอดภัย
              Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF228B22).withValues(alpha: 0.08), 
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF228B22).withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Color(0xFF228B22), size: 24),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ข้อมูลการชำระเงินของคุณถูกเก็บรักษาเป็นความลับ',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF228B22)),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'และเข้ารหัสด้วยมาตรฐานความปลอดภัยสูงสุด',
                              style: TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

              // ช่องกรอกชื่อเจ้าของบัตร
              TextFormField(
                  controller: _nameCtrl,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'ชื่อเจ้าของบัตร',
                    prefixIcon: const Icon(Icons.person_outline, color: Colors.black45),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'กรุณากรอกชื่อเจ้าของบัตร';
                    return null;
                  },
              ),
              const SizedBox(height: 16),

              // ช่องกรอกหมายเลขบัตร
              TextFormField(
                  controller: _cardNumberCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(16),
                    CustomCardNumberFormatter(),
                  ],
                decoration: InputDecoration(
                  labelText: 'หมายเลขบัตร',
                  hintText: '0000 0000 0000 0000',
                  prefixIcon: const Icon(Icons.credit_card, color: Colors.black45),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'กรุณากรอกหมายเลขบัตร';
                  if (value.replaceAll(' ', '').length < 16) return 'หมายเลขบัตรต้องมี 16 หลัก';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // ช่องกรอกวันหมดอายุ และ CVV
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                        controller: _expiryCtrl,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(4),
                        CustomExpiryFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: 'วันหมดอายุ',
                        hintText: 'ดด/ปป',
                        labelStyle: const TextStyle(fontSize: 13), 
                        prefixIcon: const Icon(Icons.calendar_month, color: Colors.black45, size: 20),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'กรุณากรอกวันหมดอายุ';
                        if (!value.contains('/') || value.length < 5) return 'รูปแบบไม่ถูกต้อง';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  Expanded(
                    child: TextFormField(
                      controller: _cvvCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      obscureText: true,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: 'CVV',
                        labelStyle: const TextStyle(fontSize: 13),
                        prefixIcon: const Icon(Icons.lock_outline, color: Colors.black45, size: 20),
                        prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 0),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) return 'กรุณากรอก CVV';
                        if (value.length < 3) return 'CVV ต้องมี 3 หลัก';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ปุ่มบันทึกข้อมูลบัตร
              FilledButton(
                  onPressed: _loading ? null : _saveCard,
                  style: FilledButton.styleFrom(
                    backgroundColor: primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                        'บันทึกข้อมูล',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// รูปแบบ
class CustomCardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll(' ', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) % 4 == 0 && (i + 1) != text.length) buffer.write(' ');
    }
    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}

class CustomExpiryFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text.replaceAll('/', '');
    var buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      buffer.write(text[i]);
      if ((i + 1) == 2 && (i + 1) != text.length) buffer.write('/');
    }
    var string = buffer.toString();
    return newValue.copyWith(
        text: string,
        selection: TextSelection.collapsed(offset: string.length));
  }
}