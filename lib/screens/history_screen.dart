import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../providers/parking_provider.dart';
import 'booking_screen.dart' show EntryQrSection;
import 'payment_screen.dart';
import 'receipt_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryLoadingOverlay extends StatelessWidget {
  const _HistoryLoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ModalBarrier(
          dismissible: false,
          color: Color(0x66000000),
        ),
        Center(
          child: SizedBox(
            width: 220,
            child: Material(
              color: Colors.white,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  color: Color(0xFF0000CD),
                  backgroundColor: Color(0xFFE0E0E0),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const Duration _overlayDelay = Duration(milliseconds: 500);
  static const Duration _retryDelay = Duration(seconds: 3);

  Timer? _overlayDelayTimer;
  bool _isWaitingForBookings = false;
  bool _hasLoadedBookings = false;
  bool _showLoadingOverlay = false;
  
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadBookingsUntilSuccess();
      }
    });
  }

  @override
  void dispose() {
    _overlayDelayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookingsUntilSuccess() async {
    if (_isWaitingForBookings) return;

    _isWaitingForBookings = true;
    _overlayDelayTimer?.cancel();
    _overlayDelayTimer = Timer(_overlayDelay, () {
      if (mounted && _isWaitingForBookings) {
        setState(() => _showLoadingOverlay = true);
      }
    });

      final provider = context.read<ParkingProvider>();

    while (mounted && _isWaitingForBookings) {
      final requestTimer = Stopwatch()..start();
      final loaded = await provider.loadBookings();
      requestTimer.stop();

      if (!mounted || !_isWaitingForBookings) return;

      if (loaded) {
        _overlayDelayTimer?.cancel();
        _overlayDelayTimer = null;

        setState(() {
          _hasLoadedBookings = true;
          _isWaitingForBookings = false;
          _showLoadingOverlay = false;
        });
        return;
      }
      final remainingDelay = _retryDelay - requestTimer.elapsed;
      if (remainingDelay > Duration.zero) {
        await Future<void>.delayed(remainingDelay);
      }
    }
  }

  Future<void> _cancel(int id) async {
    final provider = context.read<ParkingProvider>();
    final ok = await ApiService.cancelBooking(id);

    if (ok && mounted) {
      final bookingReload = _loadBookingsUntilSuccess();
      await provider.loadSlots();
      await bookingReload;
    }
  }

  bool _isCancelledBooking(String status) {
    return status == 'cancelled' || status == 'time_out';
  }

  Color _bookingColor(String status) {
    if (status == 'active') return const Color(0xFF228B22);
    if (_isCancelledBooking(status)) return const Color(0xFFCD2626);
    if (status == 'completed') return const Color(0xFF0000CD);
    return const Color(0xFF9E9E9E);
  }

    String _payStatusLabel(String status) => switch (status) {
    'paid' => 'ชำระแล้ว',
    'pending' => 'รอชำระ',
    'cancelled' => 'ยกเลิก',
    _ => status,
  };

  Widget _buildHistoryScaffold(Widget content) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Positioned.fill(child: content),
          if (_showLoadingOverlay)
            const Positioned.fill(
              child: _HistoryLoadingOverlay(),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();
    final bookings = provider.bookings;
    final fmt      = DateFormat('dd MMM HH:mm');

    if (bookings.isEmpty) {
      return _buildHistoryScaffold(
        _hasLoadedBookings
            ? const Center(
                child: Text(
                  'ยังไม่มีประวัติการจอง',
                  style: TextStyle(color: Color(0xFF9E9E9E)),
                ),
              )
            : const SizedBox.expand(),
      );
    }

      return _buildHistoryScaffold(
        ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) {
          final b = bookings[i];
          final payment = b.payment;
          final isPaid = payment?.isPaid ?? false;
          final payStatus = payment?.status;

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
                        Text('${payment?.amount ?? b.totalAmount} ฿',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                      if (payStatus != null)
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


                  // ปุ่มต่างๆ
                  Row(children: [
                    // ยกเลิกการจอง
                    if (b.status == 'active' && !isPaid && b.enteredAt == null)
                      TextButton(
                        onPressed: () => _cancel(b.id),
                        style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFFCD2626), 
                            padding: EdgeInsets.zero),
                        child: const Text('ยกเลิก', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),

                    const Spacer(),

                    // ปุ่มชำระเงิน
                    if (b.status == 'active' && !isPaid && b.enteredAt != null)
                      FilledButton.icon(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => PaymentScreen(booking: b))),
                        icon: const Icon(Icons.payment, size: 16, color: Color(0xFFFFFFFF)),
                        label: const Text('ชำระเงิน', style: TextStyle(color: Color(0xFFFFFFFF))),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF0000CD),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8)),
                      ),
                    if (b.status == 'active' && !isPaid && b.enteredAt == null)
                      const Text('รอยืนยันรถเข้า', style: TextStyle(color: Colors.deepOrange)),

                    // Badge ชำระแล้ว
                    if (isPaid)
                      FilledButton.icon(
                        onPressed: () => Navigator.push(context,
                          MaterialPageRoute(
                            builder: (_) => ReceiptScreen(booking: b))),
                        icon: const Icon(Icons.receipt_long, size: 16, color: Colors.white),
                        label: const Text('ดูใบเสร็จ', style: TextStyle(color: Colors.white)),
                        style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF228B22), // 🟢 สีเขียว
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8)),
                      ),

                    // Badge ยกเลิกแล้ว
                    if (_isCancelledBooking(b.status))
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
                  if (b.status == 'active' &&
                      !isPaid &&
                      b.enteredAt == null) ...[
                    const SizedBox(height: 8),
                    ExpansionTile(
                      key: PageStorageKey<String>('entry-qr-${b.id}'),
                      tilePadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.qr_code_2,
                        color: Color(0xFF0000CD),
                      ),
                      title: const Text(
                        'QR ทางเข้า',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        'ใช้ได้ก่อนเวลาเริ่มจอง 10 นาที ถึงหลังเวลาเริ่มจอง 30 นาที',
                        style: TextStyle(fontSize: 12),
                      ),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        EntryQrSection(booking: b),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
