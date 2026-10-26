import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/booking.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';
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
  static const Duration _overlayDelay =
      Duration(milliseconds: 500);

  Timer? _overlayDelayTimer;
  bool _isLoadingBookings = false;
  bool _hasLoadedBookings = false;
  bool _showLoadingOverlay = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_loadBookings());
      }
    });
  }

  @override
  void dispose() {
    _overlayDelayTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBookings() async {
    if (_isLoadingBookings) {
      return;
    }

    setState(() {
      _isLoadingBookings = true;
      _loadError = null;
    });

    _overlayDelayTimer?.cancel();
    _overlayDelayTimer = Timer(_overlayDelay, () {
      if (mounted && _isLoadingBookings) {
        setState(() => _showLoadingOverlay = true);
      }
    });

    final loaded =
        await context.read<ParkingProvider>().loadBookings();

    if (!mounted) {
      return;
    }

    _overlayDelayTimer?.cancel();
    _overlayDelayTimer = null;

    setState(() {
      _isLoadingBookings = false;
      _showLoadingOverlay = false;
      _hasLoadedBookings =
          loaded || _hasLoadedBookings;
      _loadError = loaded
          ? null
          : 'ไม่สามารถโหลดประวัติการจองได้ กรุณาลองใหม่อีกครั้ง';
    });
  }

  Future<void> _cancel(int bookingId) async {
    final provider = context.read<ParkingProvider>();
    final cancelled =
        await ApiService.cancelBooking(bookingId);

    if (!mounted) {
      return;
    }

    if (!cancelled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถยกเลิกรายการจองได้',
          ),
          backgroundColor: Color(0xFFCD2626),
        ),
      );
      return;
    }

    await Future.wait([
      provider.loadBookings(),
      provider.loadSlots(),
    ]);
  }

  bool _isCancelledBooking(String status) {
    return status == 'cancelled' ||
        status == 'time_out';
  }

  String _bookingStatusLabel(Booking booking) {
    if (booking.status == 'time_out') {
      return 'ยกเลิกอัตโนมัติ';
    }

    if (booking.status == 'cancelled') {
      return 'ยกเลิกแล้ว';
    }

    if (booking.status == 'completed') {
      return 'เสร็จสิ้น';
    }

    if (booking.status == 'ready_to_exit' ||
        booking.payment?.isPaid == true) {
      return 'ชำระแล้ว';
    }

    if (booking.status == 'active' &&
        booking.enteredAt != null) {
      return 'รอชำระเงิน';
    }

    if (booking.status == 'active') {
      return 'จองแล้ว';
    }

    return booking.status;
  }
  Color _bookingColor(Booking booking) {
    if (_isCancelledBooking(booking.status)) {
      return const Color(0xFFCD2626);
    }
    if (booking.status == 'completed') {
      return const Color(0xFF0000CD);
    }
    if (booking.status == 'ready_to_exit' ||
        booking.payment?.isPaid == true) {
      return const Color(0xFFE65100);
    }
    if (booking.status == 'active') {
      return const Color(0xFF228B22);
    }
    return const Color(0xFF9E9E9E);
  }

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
    final dateFormat = DateFormat('dd MMM HH:mm');

    if (_loadError != null && bookings.isEmpty) {
      return _buildHistoryScaffold(
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFCD2626),
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _isLoadingBookings
                    ? null
                    : _loadBookings,
                icon: const Icon(Icons.refresh),
                label: const Text('ลองใหม่อีกครั้ง'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      const Color(0xFF0000CD),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (bookings.isEmpty) {
      return _buildHistoryScaffold(
        _hasLoadedBookings
            ? RefreshIndicator(
                onRefresh: _loadBookings,
                child: ListView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 220),
                    Center(
                      child: Text(
                        'ยังไม่มีประวัติการจอง',
                        style: TextStyle(
                          color: Color(0xFF9E9E9E),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const SizedBox.expand(),
      );
    }

    return _buildHistoryScaffold(
      RefreshIndicator(
        onRefresh: _loadBookings,
        child: ListView.separated(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          itemCount: bookings.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final booking = bookings[index];
            final payment = booking.payment;
            final isPaid = payment?.isPaid ?? false;

            final canCancel =
                booking.status == 'active' &&
                !isPaid &&
                booking.enteredAt == null;

            final canPay =
                booking.status == 'active' &&
                !isPaid &&
                booking.enteredAt != null;

            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor:
                              _bookingColor(booking),
                          child: Text(
                            booking.slotName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Slot ${booking.slotName}',
                                style: const TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${dateFormat.format(booking.startTime)} '
                                '→ ${dateFormat.format(booking.endTime)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9E9E9E),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${payment?.amount ?? booking.totalAmount} ฿',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _bookingStatusLabel(booking),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color:
                                    _bookingColor(booking),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    if (canCancel || canPay || isPaid)
                      Row(
                        children: [
                          if (canCancel)
                            TextButton(
                              onPressed: () =>
                                  _cancel(booking.id),
                              style: TextButton.styleFrom(
                                foregroundColor:
                                    const Color(0xFFCD2626),
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text(
                                'ยกเลิก',
                                style: TextStyle(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                              ),
                            ),
                          const Spacer(),
                          if (canPay)
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PaymentScreen(
                                      booking: booking,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.payment,
                                size: 16,
                              ),
                              label:
                                  const Text('ชำระเงิน'),
                              style:
                                  FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(
                                  0xFF0000CD,
                                ),
                                foregroundColor:
                                    Colors.white,
                              ),
                            ),
                          if (isPaid)
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        ReceiptScreen(
                                      booking: booking,
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(
                                Icons.receipt_long,
                                size: 16,
                              ),
                              label:
                                  const Text('ดูใบเสร็จ'),
                              style:
                                  FilledButton.styleFrom(
                                backgroundColor:
                                    const Color(
                                  0xFF228B22,
                                ),
                                foregroundColor:
                                    Colors.white,
                              ),
                            ),
                        ],
                      ),
                    if (booking.status == 'active' &&
                        !isPaid &&
                        booking.enteredAt == null) ...[
                      const SizedBox(height: 8),
                      ExpansionTile(
                        key: PageStorageKey<String>(
                          'entry-qr-${booking.id}',
                        ),
                        tilePadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.qr_code_2,
                          color: Color(0xFF0000CD),
                        ),
                        title: const Text(
                          'QR ทางเข้า',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'ใช้ได้ก่อนเวลาเริ่มจอง 10 นาที '
                          'ถึงหลังเวลาเริ่มจอง 30 นาที',
                          style: TextStyle(fontSize: 12),
                        ),
                        childrenPadding:
                            const EdgeInsets.fromLTRB(
                          16,
                          0,
                          16,
                          16,
                        ),
                        children: [
                          EntryQrSection(
                            booking: booking,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}