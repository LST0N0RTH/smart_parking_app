import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking.dart';
import '../models/booking_qr_token.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';

class ReceiptScreen extends StatefulWidget {
  final Booking booking;

  const ReceiptScreen({
    super.key,
    required this.booking,
  });

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  BookingQrToken? _exitQr;
  bool _isLoadingExitQr = false;
  String? _exitQrError;

  @override
  void initState() {
    super.initState();
    _loadExitQr();
  }

Future<void> _loadExitQr() async {
  if (_isLoadingExitQr || widget.booking.status == 'completed') {
    return;
  }
  setState(() {
    _isLoadingExitQr = true;
    _exitQrError = null;
  });
  try {
    final qr = await ApiService.getExitQr(widget.booking.id);

    if (!mounted) {
      return;
    }
    setState(() {
      _exitQr = qr;
      _isLoadingExitQr = false;
      _exitQrError = null;
    });
  } on ApiRequestException catch (error) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingExitQr = false;
      _exitQrError = error.statusCode == 409
          ? 'QR ทางออกจะแสดงเมื่อระบบยืนยันการชำระเงินเรียบร้อยแล้ว'
          : error.message;
    });
  } catch (_) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingExitQr = false;
      _exitQrError = 'ไม่สามารถโหลด QR ทางออกได้';
    });
  }
}
  Booking _currentBooking(ParkingProvider provider) {
    for (final booking in provider.bookings) {
      if (booking.id == widget.booking.id) {
        return booking;
      }
    }
    return widget.booking;
  }

  String _duration(DateTime start, DateTime end) {
    final diff = end.difference(start);
    final totalHours = diff.inHours;
    final minutes = diff.inMinutes % 60;

    if (totalHours >= 24) {
      final days = diff.inDays;
      final hours = totalHours % 24;

      String result = '$days วัน';

      if (hours > 0) {
        result += ' $hours ชั่วโมง';
      }

      if (minutes > 0) {
        result += ' $minutes นาที';
      }

      return result;
    }

    if (totalHours == 0) {
      return '$minutes นาที';
    }

    if (minutes == 0) {
      return '$totalHours ชั่วโมง';
    }

    return '$totalHours ชั่วโมง $minutes นาที';
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
          ),
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

  Widget _buildExitQrSection({
    required Booking booking,
    required bool isCompleted,
  }) {
    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF228B22).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF228B22).withValues(alpha: 0.3),
          ),
        ),
        child: const Column(
          children: [
            Icon(
              Icons.check_circle,
              color: Color(0xFF228B22),
              size: 44,
            ),
            SizedBox(height: 12),
            Text(
              'ออกจากพื้นที่จอดรถเรียบร้อยแล้ว',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF228B22),
              ),
            ),
          ],
        ),
      );
    }

    if (_isLoadingExitQr) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    if (_exitQr == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 40,
            ),
            const SizedBox(height: 12),
            const Text(
              'ยังไม่สามารถแสดง QR ทางออกได้',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (_exitQrError != null) ...[
              const SizedBox(height: 8),
              Text(
                _exitQrError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadExitQr,
              icon: const Icon(Icons.refresh),
              label: const Text('กรุณาลองใหม่อีกครั้ง'),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'QR ทางออก',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          QrImageView(
            data: _exitQr!.qrUrl,
            version: QrVersions.auto,
            size: 180,
            backgroundColor: Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'รหัสการจอง: ${_exitQr!.bookingCode}',
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 16),
          const Text(
            'โปรดนำรถไปยังจุดตรวจทางออก แล้วสแกน QR Code นี้ ระบบจะเปิดไม้กั้นเมื่อยืนยันรถยนต์เรียบร้อย หากพบปัญหากรุณาติดต่อผู้ดูแลพื้นที่จอดรถ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();
    final booking = _currentBooking(provider);
    final isCompleted = booking.status == 'completed';

    final fmt = DateFormat('dd MMM yyyy HH:mm');
    const primaryColor = Color(0xFF0000CD);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text(
          'ใบเสร็จรับเงิน',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: primaryColor,
          ),
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
              child: const Icon(
                Icons.check,
                color: Colors.white,
                size: 40,
              ),
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
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.3),
                ),
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
                  Text('รหัสการจอง: ${booking.bookingCode}'),
                  const Divider(height: 24, color: Colors.black12),
                  _row('ช่องจอด', booking.slotName),
                  _row('ทะเบียนรถ', booking.licensePlate),
                  _row(
                    'เข้าจอดจริง',
                    booking.enteredAt == null
                        ? 'ยังไม่ยืนยัน'
                        : fmt.format(booking.enteredAt!),
                  ),
                  _row(
                    'ออกจริง',
                    booking.exitedAt == null
                        ? 'ยังไม่ออก'
                        : fmt.format(booking.exitedAt!),
                  ),
                  if (booking.exitedAt == null)
                    _row('กำหนดออก', fmt.format(booking.endTime)),
                    _row(
                      booking.exitedAt == null
                          ? 'ระยะเวลาตามแผน'
                          : 'ระยะเวลาใช้จริง',
                      _duration(
                        booking.enteredAt ?? booking.startTime,
                        booking.exitedAt ?? booking.endTime,
                      ),
                    ),
                  if ((booking.payment?.overstayFee ?? 0) > 0)
                    _row(
                      'ค่าจอดเกินเวลา',
                      '${booking.payment!.overstayFee} บาท',
                    ),
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
                        '${booking.payment?.amount ?? booking.totalAmount} บาท',
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
            _buildExitQrSection(
              booking: booking,
              isCompleted: isCompleted,
            ),
            const SizedBox(height: 32),
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
