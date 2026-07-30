import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/booking.dart';

class ReceiptScreen extends StatelessWidget {
  final Booking booking;

  const ReceiptScreen({super.key, required this.booking});

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
    } else {
      final h = totalHours;
      if (h == 0) return '$m นาที';
      if (m == 0) return '$h ชั่วโมง';
      return '$h ชั่วโมง $m นาที';
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy HH:mm');
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'ใบเสร็จรับเงิน',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: primaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [

            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF228B22),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 40),
            ),
            const SizedBox(height: 12),
            const Text(
              'ชำระเงินเรียบร้อยแล้ว',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF228B22),
              ),
            ),
            const SizedBox(height: 24),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Coolkids Smart Parking',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'รหัสการจอง: #${booking.id}',
                  ),
                  const Divider(height: 24, color: Colors.black12),

                  _row('ช่องจอด', booking.slotName),
                  _row('เข้า', fmt.format(booking.startTime)),
                  _row('ออก', fmt.format(booking.endTime)),
                  _row('ระยะเวลา', _duration(booking.startTime, booking.endTime)),
                  _row('ทะเบียนรถ', booking.licensePlate),

                  const Divider(height: 24, color: Colors.black12),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'ยอดชำระ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${booking.totalAmount} บาท',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05), 
                    blurRadius: 10, 
                    offset: const Offset(0, 4)
                  )
                ]
              ),
              child: Column(
                children: [
                  const Text('Exit Code', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                  const SizedBox(height: 12),
                  const Icon(Icons.qr_code_2, size: 140, color: Colors.black87), // QR Code จำลอง
                  const SizedBox(height: 8),
                  Text('รหัสนำออก: Exit Code-${booking.id}', style: const TextStyle(fontSize: 15, color: Colors.black87, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 16),
                  const Text(
                    'หากเกิดเหตุขัดข้องในการออกจากที่จอดรถ สามารถนำรหัสหรือ QR Code นี้แสกนที่ตู้ควบคุมบริเวณทางเข้า-ออกที่จอดรถ ขออภัยในความไม่สะดวก',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.4),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 32),

            // ปุ่มปิดหน้า
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'ตกลง',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 14)),
          Text(
            value,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}