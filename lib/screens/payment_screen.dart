import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../providers/parking_provider.dart';
import 'add_card_screen.dart';
import 'receipt_screen.dart';

class PaymentScreen extends StatefulWidget {
  final Booking booking;
  const PaymentScreen({super.key, required this.booking});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method  = 'promptpay';
  bool   _loading = false;
  bool   _isPaid  = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    final ok = await ApiService.confirmPayment(widget.booking.id, _method);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      await context.read<ParkingProvider>().loadBookings();
      if (!mounted) return;
      setState(() {
        _isPaid = true;
      });

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินสำเร็จ'),
          backgroundColor: Color(0xFF228B22), 
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Color(0xFFCD2626), 
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b   = widget.booking;
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ชำระเงิน', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)), 
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: primaryColor, 
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            // ใบสรุปค่าจอด
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0000CD).withValues(alpha: 0.08), 
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF0000CD).withValues(alpha: 0.3)), 
              ),
              child: Column(children: [
                const Text('สรุปค่าจอดรถ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                const SizedBox(height: 16),
                _summaryRow('Slot',       b.slotName),
                _summaryRow('เข้า',       fmt.format(b.startTime)),
                _summaryRow('ออก',        fmt.format(b.endTime)),
                _summaryRow('ระยะเวลา',  _duration(b.startTime, b.endTime)),
                const Divider(height: 24, color: Color(0xFFFFFFFF)), 
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รวม',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
                    Text('${b.totalAmount} บาท',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: Color(0xFF0000CD))), 
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // เลือกวิธีชำระ
            const Text('วิธีชำระเงิน',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),

            // PromptPay QR
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.qr_code_scanner, color: Color(0xFF0000CD), size: 28),
                title: const Text('PromptPay QR', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                onExpansionChanged: (expanded) {
                  if (expanded) setState(() => _method = 'promptpay');
                },
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(left: 40, bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.qr_code_2, size: 80, color: Colors.black54),
                        const SizedBox(height: 8),
                        Text('ยอดชำระ: ฿${b.totalAmount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Mobile Banking
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_android, color: Color(0xFF0000CD), size: 28),
                title: const Text('Mobile Banking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 40, bottom: 8),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFFE0E0E0), width: 2))
                    ),
                    child: Column(
                      children: [
                        _bankAppOption('ธนาคารกสิกรไทย', 'assets/images/KBANK.png', const Color(0xFF1D9E75)),
                        _bankAppOption('ธนาคารไทยพาณิชย์', 'assets/images/SCB.png', const Color(0xFF4E2A84)),
                        _bankAppOption('ธนาคารกรุงไทย', 'assets/images/KTB.jpg', const Color(0xFF00AEEF)),
                        _bankAppOption('ธนาคารกรุงเทพ', 'assets/images/BBL.png', const Color(0xFF1E3A8A)),
                        _bankAppOption('ธนาคารกรุงศรีอยุธยา', 'assets/images/BAY.png', const Color(0xFFFFC425)),
                        _bankAppOption('ธนาคารทหารไทยธนชาต', 'assets/images/TTB.png', const Color(0xFFFF5000)),
                        _bankAppOption('ธนาคารออมสิน', 'assets/images/GSB.jpg', const Color(0xFFEC008C)),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Credit/Debit Card
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(Icons.credit_card, color: Color(0xFF0000CD), size: 28),
                title: const Text('บัตรเครดิต/บัตรเดบิต', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                onExpansionChanged: _isPaid ? null : (expanded) {},
                children: [
                  Container(
                    margin: const EdgeInsets.only(left: 40, bottom: 8, top: 8),
                    decoration: const BoxDecoration(
                      border: Border(left: BorderSide(color: Color(0xFFE0E0E0), width: 2))
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          leading: const Icon(Icons.credit_card, color: Color(0xFF0000CD), size: 28),
                          title: const Text('Visa **** 1234', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.black87)),
                          onTap: _isPaid ? null : () {
                            setState(() {
                              _method = 'credit_card_1234';
                            });
                          },

                          trailing: _method == 'credit_card_1234' 
                              ? const Icon(Icons.check_circle, color: Color(0xFF0000CD), size: 20) 
                              : null,
                        ),

                        // ปุ่มเพิ่มบัตรใหม่
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.black26, style: BorderStyle.solid),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add, color: Colors.black54, size: 20),
                          ),
                          title: const Text('เพิ่มบัตรเครดิต/เดบิตใหม่', style: TextStyle(fontSize: 15, color: Color(0xFF0000CD), fontWeight: FontWeight.bold)),
                          onTap: _isPaid ? null : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AddCardScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            const SizedBox(height: 32),

            // เมื่อชำระเงินสำเร็จแล้วเปลี่ยนเป็นปุ่มใบเสร็จทันที
            if (_isPaid)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => ReceiptScreen(booking: widget.booking)),
                  );
                },
                icon: const Icon(Icons.receipt_long, color: Colors.white),
                label: const Text('ใบเสร็จรับเงิน', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF228B22), 
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                ),
              )
            else

            // ปุ่มยืนยัน
            FilledButton.icon(
              onPressed: _loading ? null : _pay,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: const Text('ยืนยันการชำระเงิน', style: TextStyle(fontSize: 15, color: Colors.white, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0000CD), 
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
            ),

            const SizedBox(height: 12),

            // ปุ่มยกเลิกรายการด้านล่าง
            TextButton(
              onPressed: _loading ? null : () => Navigator.pop(context),
              child: const Text(
                'ยกเลิกรายการชำระเงิน',
                style: TextStyle(color: Colors.red, fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)), 
        Text(value, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)), 
      ],
    ),
  );

  Widget _bankAppOption(String bankName, String imagePath, Color tempIconColor) {
    return ListTile(
      enabled: !_isPaid,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: tempIconColor,
        child: Image.asset(imagePath),
      ),
      title: Text(bankName, style: const TextStyle(fontSize: 15, color: Colors.black87)),
      onTap: () {
        setState(() {
          _method = 'mobile_banking_$bankName';
        });
      },
      trailing: _method == 'mobile_banking_$bankName' 
          ? const Icon(Icons.check_circle, color: Color(0xFF0000CD), size: 20) 
          : null,
    );
  }

  String _duration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final totalHours = diff.inHours;
    final m = diff.inMinutes % 60;

    if (totalHours >= 24) {
      final d = diff.inDays;          
      final h = totalHours % 24;      
      
      String result = '$d วัน';
      if (h > 0) result += ' $h ชั่วโมง';
      if (m > 0) result += ' $m นาที';
      return result;
    } 
    else {
      final h = totalHours;
      if (h == 0) return '$m นาที';
      if (m == 0) return '$h ชั่วโมง';
      return '$h ชั่วโมง $m นาที';
    }
  }
}