import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';
import '../services/api_service.dart';
import '../providers/parking_provider.dart';

class PaymentScreen extends StatefulWidget {
  final Booking booking;
  const PaymentScreen({super.key, required this.booking});
  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String _method  = 'promptpay';
  bool   _loading = false;

  Future<void> _pay() async {
    setState(() => _loading = true);
    final ok = await ApiService.confirmPayment(widget.booking.id, _method);
    if (!mounted) return;
    setState(() => _loading = false);

    if (ok) {
      await context.read<ParkingProvider>().loadBookings();
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินสำเร็จ'),
          backgroundColor: Color(0xFF228B22), // 🟢 
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Color(0xFFCD2626), // 🔴 
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final b   = widget.booking;
    final fmt = DateFormat('dd MMM yyyy HH:mm');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('ชำระเงิน', style: TextStyle(color: Color(0xFF0000CD))), // 🔘 น้ำเงิน
        iconTheme: const IconThemeData(color: Color(0xFFFFFFFF)),
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
                color: const Color(0xFF0000CD).withOpacity(0.08), 
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFF0000CD).withOpacity(0.3)), 
              ),
              child: Column(children: [
                const Text('สรุปค่าจอดรถ',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF9E9E9E))), // 🔘
                const SizedBox(height: 16),
                _summaryRow('Slot',       b.slotName),
                _summaryRow('เข้า',       fmt.format(b.startTime)),
                _summaryRow('ออก',        fmt.format(b.endTime)),
                _summaryRow('ระยะเวลา',  _duration(b.startTime, b.endTime)),
                const Divider(height: 24, color: Color(0xFFFFFFFF)), // 🔘
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('รวม',
                        style: TextStyle(fontSize: 16,
                            fontWeight: FontWeight.bold, color: Color(0xFF9E9E9E))), // 🔘
                    Text('${b.totalAmount} บาท',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold,
                            color: Color(0xFF0000CD))), // 🟢 คงสีเขียวไว้ให้เด่นชัด
                  ],
                ),
              ]),
            ),

            const SizedBox(height: 24),

            // เลือกวิธีชำระ
            const Text('วิธีชำระเงิน',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF9E9E9E))), // 🔘
            const SizedBox(height: 10),

            _methodTile(
              value:   'promptpay',
              label:   'PromptPay QR',
              subLabel: 'สแกน QR Code ผ่านแอปธนาคาร',
              icon:    Icons.qr_code,
            ),
            const SizedBox(height: 8),
            _methodTile(
              value:   'cash',
              label:   'เงินสด',
              subLabel: 'ชำระที่จุดรับเงิน',
              icon:    Icons.payments_outlined,
            ),

            const SizedBox(height: 24),

            // QR Code (แสดงเมื่อเลือก PromptPay)
            if (_method == 'promptpay') ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF9E9E9E)), // 🔘 เปลี่ยนเป็นสีเทาใหม่
                ),
                child: Column(children: [
                  const Text('สแกน QR เพื่อชำระเงิน',
                      style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))), // 🔘
                  const SizedBox(height: 14),
                  // QR Placeholder
                  Container(
                    width: 180, height: 180,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5), 
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.qr_code_2, size: 100, color: Color(0xFF9E9E9E)), // 🔘
                        SizedBox(height: 8),
                        Text('PromptPay QR',
                            style: TextStyle(fontSize: 12,
                                color: Color(0xFF9E9E9E))), // 🔘
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('฿${b.totalAmount}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF9E9E9E))), // 🔘
                ]),
              ),
              const SizedBox(height: 24),
            ],

            // ปุ่มยืนยัน
            FilledButton.icon(
              onPressed: _loading ? null : _pay,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline, color: Colors.white),
              label: Text(
                _method == 'promptpay'
                    ? 'ยืนยันชำระผ่าน PromptPay'
                    : 'ยืนยันชำระด้วยเงินสด',
                style: const TextStyle(fontSize: 15, color: Colors.white),
              ),
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0000CD), 
                  padding: const EdgeInsets.symmetric(vertical: 14)),
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
        Text(label, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13)), // 🔘
        Text(value, style: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 13, // 🔘
            fontWeight: FontWeight.w500)),
      ],
    ),
  );

  Widget _methodTile({
    required String value, required String label,
    required String subLabel, required IconData icon,
  }) =>
    GestureDetector(
      onTap: () => setState(() => _method = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _method == value
                ? const Color(0xFF228B22) 
                : const Color(0xFF9E9E9E), // 🔘
            width: _method == value ? 2 : 1,
          ),
          color: _method == value
              ? const Color(0xFF228B22).withOpacity(0.06) 
              : null,
        ),
        child: Row(children: [
          Icon(icon,
              color: _method == value
                  ? const Color(0xFF228B22) : const Color(0xFF9E9E9E)), // 🔘
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _method == value
                          ? const Color(0xFF228B22) : const Color(0xFF9E9E9E))), // 🔘
              Text(subLabel,
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF9E9E9E))), // 🔘
            ],
          )),
          if (_method == value)
            const Icon(Icons.check_circle,
                color: Color(0xFF228B22), size: 20), 
        ]),
      ),
    );

  String _duration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final h = diff.inHours;
    final m = diff.inMinutes % 60;
    if (h == 0) return '$m นาที';
    if (m == 0) return '$h ชั่วโมง';
    return '$h ชั่วโมง $m นาที';
  }
}