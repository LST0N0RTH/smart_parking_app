import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking.dart';
import '../models/booking_qr_token.dart';
import '../models/slot.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';

class BookingScreen extends StatefulWidget {
  final Slot slot;
  const BookingScreen({super.key, required this.slot});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  DateTime _start = DateTime.now().add(const Duration(minutes: 5));
  DateTime _end = DateTime.now().add(const Duration(hours: 1, minutes: 5));
  bool _loading = false;
  bool _showLoadingOverlay = false;
  String? _selectedPlate;
  String _paymentMethod = 'promptpay';
  Timer? _loadingOverlayTimer;

  static const Map<String, String> _paymentMethods = {
    'promptpay': 'PromptPay QR',
    'mobile_banking_ธนาคารกสิกรไทย': 'Mobile Banking • KBANK',
    'mobile_banking_ธนาคารไทยพาณิชย์': 'Mobile Banking • SCB',
    'mobile_banking_ธนาคารกรุงไทย': 'Mobile Banking • KTB',
    'mobile_banking_ธนาคารกรุงเทพ': 'Mobile Banking • BBL',
    'mobile_banking_ธนาคารกรุงศรีอยุธยา': 'Mobile Banking • BAY',
    'mobile_banking_ธนาคารทหารไทยธนชาต': 'Mobile Banking • TTB',
    'mobile_banking_ธนาคารออมสิน': 'Mobile Banking • GSB',
    'card': 'บัตรเครดิต/เดบิต',
  };

  @override
  void initState() {
    super.initState();
    final userPlates = context.read<ParkingProvider>().userPlates;
    if (userPlates.isNotEmpty) {
      _selectedPlate = userPlates.first;
    }
  }

  @override
  void dispose() {
    _loadingOverlayTimer?.cancel();
    super.dispose();
  }

  void _startLoading() {
    setState(() => _loading = true);
    _loadingOverlayTimer?.cancel();
    _loadingOverlayTimer = Timer(const Duration(milliseconds: 400), () {
      if (mounted && _loading) {
        setState(() => _showLoadingOverlay = true);
      }
    });
  }

  void _stopLoading() {
    _loadingOverlayTimer?.cancel();
    _loadingOverlayTimer = null;

    if (!mounted) return;

    setState(() {
      _loading = false;
      _showLoadingOverlay = false;
    });
  }

  bool _isBeforeCurrentMinute(DateTime value) {
    final now = DateTime.now();
    final currentMinute = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute,
    );

    return value.isBefore(currentMinute);
  }

  void _showPastStartTimeMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'เวลาเริ่มจองไม่ถูกต้อง',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final picked =
        await showDateTimePicker(context, isStart ? _start : _end, now);
    if (picked == null) return;
    if (isStart && _isBeforeCurrentMinute(picked)) {
      _showPastStartTimeMessage();
      return;
    }
    setState(() {
      if (isStart) {
        _start = picked;
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      } else {
        _end = picked;
      }
    });
  }

  Future<void> _confirm() async {
    if (_loading) return;
    if (_isBeforeCurrentMinute(_start)) {
      _showPastStartTimeMessage();
      return;
    }
    if (!_end.isAfter(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'เวลาออกต้องหลังเวลาเข้าเท่านั้น',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_selectedPlate == null || _selectedPlate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'กรุณาเพิ่มทะเบียนรถในหน้าข้อมูลส่วนบุคคลก่อนสร้างรายการจอง',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    _startLoading();
    late final Booking booking;
    try {
      booking = await ApiService.createBookingWithDetails(
        widget.slot.id,
        _start,
        _end,
        _selectedPlate!,
        _paymentMethod,
      );
    } on ApiRequestException catch (error) {
      if (!mounted) return;
      _stopLoading();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    } catch (_) {
      if (!mounted) return;
      _stopLoading();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'ไม่สามารถสร้างรายการจองได้ กรุณาลองใหม่อีกครั้ง',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (!mounted) return;

    await Future.wait([
      context.read<ParkingProvider>().loadSlots(),
      context.read<ParkingProvider>().loadBookings(),
    ]);

    if (!mounted) return;
    _stopLoading();

    await _showBookingSuccessDialog(booking: booking);
  }

Future<void> _showBookingSuccessDialog({
  required Booking booking,
}) {
  final dateFormat = DateFormat('dd MMM yyyy HH:mm', 'th');
  final amountFormat = NumberFormat.decimalPattern('th');

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(0xFF1D9E75),
                size: 60,
              ),
              const SizedBox(height: 12),
              Text(
                'จอง ${booking.slotName} สำหรับรถ ${booking.licensePlate} สำเร็จ!',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1D9E75),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'รหัสการจอง: ${booking.bookingCode}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0000CD),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDCDCDC),
                  ),
                ),
                child: Column(
                  children: [
                    _bookingDetailRow('ช่องจอด', booking.slotName),
                    const SizedBox(height: 10),
                    _bookingDetailRow(
                      'เวลาเริ่ม',
                      dateFormat.format(booking.startTime),
                    ),
                    const SizedBox(height: 10),
                    _bookingDetailRow(
                      'เวลาสิ้นสุด',
                      dateFormat.format(booking.endTime),
                    ),
                    const SizedBox(height: 10),
                    _bookingDetailRow(
                      'ยอดชำระ (ประมาณ)',
                      '${amountFormat.format(booking.totalAmount)} บาท',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'หากจอดเกินเวลาที่จอง จะมีค่าปรับเพิ่ม 50 บาท',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'เข้าจอดช้าเกินกว่าเวลาจองได้สูงสุด 30 นาที หลังจากนั้นระบบจะยกเลิกรายการจองอัตโนมัติ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(
                height: 1,
                color: Color(0xFFEEEEEE),
              ),
              const SizedBox(height: 20),
              EntryQrSection(booking: booking),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    Navigator.of(context).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0000CD),
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
    },
  );
}

  Widget _bookingDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

    @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy HH:mm', 'th');
    final userPlates = context.watch<ParkingProvider>().userPlates;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'จองพื้นที่จอดรถ ${widget.slot.name}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF0000CD),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _withLoadingOverlay(
        SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'เลือกรถที่จะเข้าจอด',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0000CD),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFDCDCDC),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedPlate,
                    isExpanded: true,
                    icon: const Icon(
                      Icons.directions_car,
                      color: Color(0xFF0000CD),
                    ),
                    hint: const Text('ไม่พบข้อมูลรถ'),
                    items: userPlates.map((plate) {
                      return DropdownMenuItem<String>(
                        value: plate,
                        child: Text(
                          plate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      );
                    }).toList(),
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _selectedPlate = value);
                          },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'ระยะเวลาการจอง',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0000CD),
                ),
              ),
              const SizedBox(height: 8),
              _timeCard(
                'เวลาเข้า',
                fmt.format(_start),
                () => _pickTime(true),
              ),
              const SizedBox(height: 14),
              _timeCard(
                'เวลาออก',
                fmt.format(_end),
                () => _pickTime(false),
              ),
              const SizedBox(height: 24),
              const Text(
                'เลือกวิธีชำระเงิน',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Color(0xFF0000CD),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                isExpanded: true,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _paymentMethods.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(entry.value),
                  );
                }).toList(),
                onChanged: _loading
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _paymentMethod = value);
                        }
                      },
              ),
              const SizedBox(height: 8),
              const Text(
                'หากต้องการชำระเงินด้วยบัตรเครดิต/เดบิต กรุณาเพิ่มข้อมูลบัตรให้เรียบร้อย',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: _loading ? null : _confirm,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline),
                label: const Text(
                  'ยืนยันการจอง',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0000CD),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        Navigator.pop(context);
                      },
                child: const Text('ยกเลิกการจอง'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _withLoadingOverlay(Widget child) {
    return Stack(
      children: [
        Positioned.fill(child: child),
        if (_showLoadingOverlay)
          const Positioned.fill(
            child: AbsorbPointer(
              child: ColoredBox(
                color: Color(0x1A000000),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: LinearProgressIndicator(
                    color: Color(0xFF0000CD),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _timeCard(
    String label,
    String value,
    VoidCallback onTap,
  ) {
    return ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: Color(0xFFDCDCDC),
        ),
      ),
      leading: const Icon(
        Icons.access_time,
        color: Color(0xFF0000CD),
      ),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.edit_outlined,
        color: Colors.grey,
      ),
      onTap: _loading ? null : onTap,
    );
  }
}

enum _EntryQrDisplay {
  waiting,
  loading,
  available,
  unavailable,
  expired,
}

class EntryQrSection extends StatefulWidget {
  final Booking booking;
  const EntryQrSection({super.key, required this.booking});

  @override
  State<EntryQrSection> createState() => _EntryQrSectionState();
}

class _EntryQrSectionState extends State<EntryQrSection> {
  static const _earlyAccess = Duration(minutes: 10);
  static const _validity = Duration(minutes: 30);
  static const _primaryColor = Color(0xFF0000CD);

  BookingQrToken? _entryQr;
  Timer? _windowTimer;
  String? _errorMessage;
  _EntryQrDisplay _display = _EntryQrDisplay.waiting;

  DateTime get _availableFrom =>
      widget.booking.startTime.subtract(_earlyAccess);

  DateTime get _expiresAt => widget.booking.startTime.add(_validity);

  bool get _isWindowOpen {
    final now = DateTime.now();

    return !now.isBefore(_availableFrom) && now.isBefore(_expiresAt);
  }

  @override
  void initState() {
    super.initState();
    _scheduleWindowUpdate();

    if (_isWindowOpen) {
      _display = _EntryQrDisplay.loading;
      unawaited(_loadEntryQr());
    } else if (!DateTime.now().isBefore(_expiresAt)) {
      _display = _EntryQrDisplay.expired;
    }
  }

  @override
  void dispose() {
    _windowTimer?.cancel();
    super.dispose();
  }
  void _scheduleWindowUpdate() {
    _windowTimer?.cancel();

    final now = DateTime.now();
    final nextBoundary = now.isBefore(_availableFrom)
        ? _availableFrom
        : now.isBefore(_expiresAt)
            ? _expiresAt
            : null;
    if (nextBoundary == null) {
      return;
    }
    _windowTimer = Timer(
      nextBoundary.difference(now) + const Duration(milliseconds: 250),
      () {
        if (!mounted) {
          return;
        }
        if (_isWindowOpen) {
          unawaited(_loadEntryQr());
        } else {
          setState(() {
            _entryQr = null;
            _errorMessage = null;
            _display = _EntryQrDisplay.expired;
          });
        }
        _scheduleWindowUpdate();
      },
    );
  }

  Future<void> _loadEntryQr() async {
    if (!_isWindowOpen) {
      return;
    }
    setState(() {
      _entryQr = null;
      _errorMessage = null;
      _display = _EntryQrDisplay.loading;
    });
    try {
      final entryQr = await ApiService.getEntryQr(widget.booking.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _entryQr = entryQr;
        _display = _EntryQrDisplay.available;
      });
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entryQr = null;
        _errorMessage = error.statusCode == 410 ? null : error.message;
        _display = switch (error.statusCode) {
          425 => _EntryQrDisplay.waiting,
          410 => _EntryQrDisplay.expired,
          _ => _EntryQrDisplay.unavailable,
        };
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entryQr = null;
        _errorMessage = 'ไม่สามารถโหลด QR ทางเข้าได้ กรุณาลองใหม่อีกครั้ง';
        _display = _EntryQrDisplay.unavailable;
      });
    }
  }

  Widget _blurredQr({Widget? overlay}) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: const Opacity(
              opacity: 0.65,
              child: Icon(
                Icons.qr_code_2,
                size: 180,
                color: Color(0xFF757575),
              ),
            ),
          ),
          if (overlay != null) overlay,
        ],
      ),
    );
  }

  Widget _message(String text, {Color color = Colors.black54}) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontSize: 13,
        color: color,
        height: 1.45,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('dd MMM yyyy HH:mm', 'th');
    final availabilityMessage =
        'QR ทางเข้า จะพร้อมใช้งานตั้งแต่ ${formatter.format(_availableFrom)} น. '
        'ถึง ${formatter.format(_expiresAt)} น.';
    switch (_display) {
      case _EntryQrDisplay.available:
        return Column(
          children: [
            QrImageView(
              data: _entryQr!.qrUrl,
              version: QrVersions.auto,
              size: 180,
              backgroundColor: Colors.white,
            ),
            const SizedBox(height: 14),
            _message(
              'โปรดสแกน QR Code บริเวณทางเข้า-ออกที่จอดรถเท่านั้น',
            ),
          ],
        );
      case _EntryQrDisplay.loading:
        return Column(
          children: [
            _blurredQr(
              overlay: const SizedBox(
                width: 34,
                height: 34,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _primaryColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            _message('กำลังเตรียม QR ทางเข้า...'),
          ],
        );
      case _EntryQrDisplay.waiting:
        return Column(
          children: [
            _blurredQr(),
            const SizedBox(height: 14),
            _message(
              _errorMessage ?? availabilityMessage,
              color: const Color(0xFF555555),
            ),
          ],
        );
      case _EntryQrDisplay.expired:
        return Column(
          children: [
            _blurredQr(),
            const SizedBox(height: 14),
            _message(
              'รายการจองถูกยกเลิก เนื่องจากไม่พบการเข้าใช้งานพื้นที่จอดรถภายในระยะเวลาที่กำหนด กรุณาทำรายการจองใหม่',
              color: const Color(0xFFCD2626),
            ),
          ],
        );
      case _EntryQrDisplay.unavailable:
        return Column(
          children: [
            _blurredQr(),
            const SizedBox(height: 14),
            _message(
              _errorMessage ?? 'ยังไม่สามารถโหลด QR ทางเข้าได้',
              color: const Color(0xFFCD2626),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _loadEntryQr,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่อีกครั้ง'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primaryColor,
              ),
            ),
          ],
        );
    }
  }
}

Future<DateTime?> showDateTimePicker(BuildContext context, DateTime initial, DateTime first) async {
  final date = await showDatePicker(
    context: context, initialDate: initial,
    firstDate: first, lastDate: first.add(const Duration(days: 30)),
  );
  if (date == null) return null;
  if (!context.mounted) return null;
  final time = await showTimePicker(
    context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (time == null) return null;
  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
