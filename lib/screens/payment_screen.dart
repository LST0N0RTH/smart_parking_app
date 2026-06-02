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
        title: const Text('ชำระเงิน', style: TextStyle(color: Color(0xFF0000CD), fontWeight: FontWeight.bold)), // 🔘 น้ำเงิน
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          color: const Color(0xFF0000CD), 
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
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
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
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
            const SizedBox(height: 10),

            _methodTile(
              value:    'promptpay',
              label:    'PromptPay QR',
              subLabel: 'สแกน QR Code ผ่านแอปธนาคาร',
              icon:    Icons.qr_code,
            ),
            const SizedBox(height: 8),
            _methodTile(
              value:    'cash',
              label:    'เงินสด',
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
                  border: Border.all(color: Colors.black26), // ปรับสีกรอบให้อ่อนลงเล็กน้อยสบายตา
                ),
                child: Column(children: [
                  const Text('สแกน QR เพื่อชำระเงิน',
                      style: TextStyle(fontSize: 13, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
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
                        Icon(Icons.qr_code_2, size: 100, color: Colors.black54), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
                        SizedBox(height: 8),
                        Text('PromptPay QR',
                            style: TextStyle(fontSize: 12, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('฿${b.totalAmount}',
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
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
        Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
        Text(value, style: const TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.bold)), // 🔵 สีเทาเข้มแบบตัวหนาตามบรีฟข้อแรก
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
                : Colors.black26, 
            width: _method == value ? 2 : 1,
          ),
          color: _method == value
              ? const Color(0xFF228B22).withValues(alpha: 0.06) 
              : null,
        ),
        child: Row(children: [
          Icon(icon,
              color: _method == value
                  ? const Color(0xFF228B22) : Colors.black54), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่างเมื่อไม่เลือก
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 14,
                      color: _method == value
                          ? const Color(0xFF228B22) : Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่างเมื่อไม่เลือก
              Text(subLabel,
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54)), // 🔵 เปลี่ยนเป็นสีเดียวกับเมนูล่าง
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
    final totalHours = diff.inHours;
    final m = diff.inMinutes % 60;

    // 🌟 เงื่อนไขใหม่: ถ้าจองตั้งแต่ 24 ชั่วโมงเป็นต้นไป ให้แตกยอดเป็น "วัน"
    if (totalHours >= 24) {
      final d = diff.inDays;          // หาจำนวนวันเต็มๆ
      final h = totalHours % 24;      // หาเศษชั่วโมงที่เหลือจากวัน
      
      String result = '$d วัน';
      if (h > 0) result += ' $h ชั่วโมง';
      if (m > 0) result += ' $m นาที';
      return result;
    } 
    // 🌟 ถ้าต่ำกว่า 24 ชั่วโมง ให้ใช้ตรรกะเดิม (ไม่แสดงคำว่าวัน)
    else {
      final h = totalHours;
      if (h == 0) return '$m นาที';
      if (m == 0) return '$h ชั่วโมง';
      return '$h ชั่วโมง $m นาที';
    }
  }
}