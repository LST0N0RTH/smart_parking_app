import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/parking_provider.dart';
import 'payment_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  
@override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ParkingProvider>().loadBookings();
      }
    });
  }

  // 🌟 ใช้ฟังก์ชัน Cancel จากโค้ดปัจจุบันที่อัปเดตทั้ง Booking และ Slots
  Future<void> _cancel(int id) async {
    final provider = context.read<ParkingProvider>();
    final ok = await ApiService.cancelBooking(id);   
    if (ok && mounted) {
      await provider.loadBookings();
      await provider.loadSlots();
    }
  }

  // 🌟 ปรับสีสถานะตาม Design System ของแอป
  Color _bookingColor(String s) => switch (s) {
    'active'    => const Color(0xFF228B22), // 🟢 สีเขียว
    'cancelled' => const Color(0xFFCD2626), // 🔴 สีแดง
    'completed' => const Color(0xFF0000CD), // 🔵 สีน้ำเงิน
    _           => const Color(0xFF9E9E9E), // 🔘 สีเทา
  };

  String _payStatusLabel(String s) => switch (s) {
    'paid'    => 'ชำระแล้ว',
    'pending' => 'รอชำระ',
    _         => s,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();
    final bookings = provider.bookings;
    final fmt      = DateFormat('dd MMM HH:mm');

    // 🌟 หน้าจอโหลดข้อมูล (โค้ดปัจจุบัน)
    if (provider.isLoading && bookings.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0000CD)));
    }

    if (bookings.isEmpty) {
      return const Center(child: Text('ยังไม่มีประวัติการจอง', style: TextStyle(color: Color(0xFF9E9E9E))));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5), // ⚪️ พื้นหลังสีเทาอ่อน
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final b       = bookings[i];
          final isPaid  = b.payment?.isPaid ?? false;
          final payStatus = b.payment?.status ?? 'pending';

          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Row บน: Slot badge + สถานะ
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _bookingColor(b.status),
                        child: Text(b.slotName,
                            style: const TextStyle(color: Colors.white,
                                fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Slot ${b.slotName}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          Text(
                            '${fmt.format(b.startTime)} → ${fmt.format(b.endTime)}',
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF9E9E9E)), // 🔘 สีเทาตัวอักษร
                          ),
                        ],
                      )),

                      // ค่าจอด
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${b.totalAmount} ฿',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(_payStatusLabel(payStatus),
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: isPaid
                                    ? const Color(0xFF228B22) // 🟢 ชำระแล้ว
                                    : const Color(0xFFE65100))), // 🟠 รอชำระ
                      ]),
                    ],
                  ),

                  const Divider(height: 18, color: Color(0xFFDCDCDC)),

                  // Row ล่าง: ปุ่มต่างๆ
                  Row(children: [
                    // ยกเลิกการจอง
                    if (b.status == 'active')
                      TextButton(
                        onPressed: () => _cancel(b.id),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFCD2626), // 🔴 สีแดง
                            padding: EdgeInsets.zero),
                        child: const Text('ยกเลิก', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),

                    const Spacer(),

                    // ปุ่มชำระเงิน
                    if (b.status == 'active' && !isPaid)
                      FilledButton.icon(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(booking: b))),
                        icon: const Icon(Icons.payment, size: 16, color: Color(0xFFFFFFFF)),
                        label: const Text('ชำระเงิน', style: TextStyle(color: Color(0xFFFFFFFF))),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0000CD), // 🔵 สีน้ำเงิน
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8)),
                      ),

                    // Badge ชำระแล้ว
                    if (isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF228B22).withValues(alpha: 0.1), // 🟢 
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(children: [
                          Icon(Icons.check_circle,
                              color: Color(0xFF228B22), size: 14), // 🟢
                          SizedBox(width: 4),
                          Text('ชำระแล้ว',
                              style: TextStyle(
                                  color: Color(0xFF228B22), fontSize: 12, fontWeight: FontWeight.bold)),
                        ]),
                      ),

                    // Badge ยกเลิกแล้ว
                    if (b.status == 'cancelled')
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFCD2626).withValues(alpha: 0.1), // 🔴
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('ยกเลิกแล้ว',
                            style: TextStyle(color: Color(0xFFCD2626), fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                  ]),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}