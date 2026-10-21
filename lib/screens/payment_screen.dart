import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/booking.dart';
import '../models/booking_qr_token.dart';
import '../models/payment_card.dart';
import '../providers/parking_provider.dart';
import '../services/api_service.dart';
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

  List<PaymentCard> _paymentCards = [];
  bool _isLoadingCards = true;
  String? _cardsError;
  int? _selectedPaymentCardId;

  BookingQrToken? _paymentQr;
  Timer? _paymentQrTimer;
  bool _isLoadingPaymentQr = false;
  bool _isReissuingPaymentQr = false;
  String? _paymentQrError;
  String? _paymentQrResetError;

  @override
  void initState() {
    super.initState();
    _loadPaymentCards();
    _createPaymentQr();
  }

  @override
  void dispose() {
    _paymentQrTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadPaymentCards() async {
    try {
      final cards = await ApiService.getPaymentCards();

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentCards = cards;
        _isLoadingCards = false;
        _cardsError = null;

        final selectedCardWasRemoved =
            _selectedPaymentCardId != null &&
            !cards.any((card) => card.id == _selectedPaymentCardId);

        if (selectedCardWasRemoved) {
          _selectedPaymentCardId = null;

          if (_method == 'card') {
            _method = 'promptpay';
          }
        }
      });
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCards = false;
        _cardsError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingCards = false;
        _cardsError = 'ไม่พบข้อมูลบัตร';
      });
    }
  }

  Future<void> _openAddCard() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddCardScreen(),
      ),
    );

    if (saved != true || !mounted) {
      return;
    }

    setState(() {
      _isLoadingCards = true;
      _cardsError = null;
    });

    await _loadPaymentCards();

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('เพิ่มบัตรเครดิต/บัตรเดบิตสำเร็จ!'),
        backgroundColor: Color(0xFF228B22),
      ),
    );
  }

    Future<void> _createPaymentQr() async {
    if (_isLoadingPaymentQr || _isReissuingPaymentQr) {
      return;
    }

    setState(() {
      _isLoadingPaymentQr = true;
      _paymentQrError = null;
    });

    try {
      final qr = await ApiService.createPaymentQr(widget.booking.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentQr = qr;
        _isLoadingPaymentQr = false;
        _paymentQrError = null;
      });

      _startPaymentQrTimer();
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPaymentQr = false;
        _paymentQrError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingPaymentQr = false;
        _paymentQrError = 'ไม่สามารถสร้าง PromptPay QR ได้';
      });
    }
  }

  Future<void> _reissuePaymentQr() async {
    if (!_isPaymentQrExpired || _isReissuingPaymentQr) {
      return;
    }

    setState(() {
      _isReissuingPaymentQr = true;
      _paymentQrResetError = null;
    });

    try {
      final qr = await ApiService.reissuePaymentQr(widget.booking.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _paymentQr = qr;
        _isReissuingPaymentQr = false;
        _paymentQrResetError = null;
      });

      _startPaymentQrTimer();
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isReissuingPaymentQr = false;
        _paymentQrResetError = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isReissuingPaymentQr = false;
        _paymentQrResetError = 'ไม่สามารถสร้าง PromptPay QR ใหม่ได้';
      });
    }
  }

  void _startPaymentQrTimer() {
    _paymentQrTimer?.cancel();

    if (_paymentQr?.expiresAt == null) {
      return;
    }

    _paymentQrTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_isPaymentQrExpired) {
          timer.cancel();
        }

        setState(() {});
      },
    );
  }

  bool get _isPaymentQrExpired {
    final expiresAt = _paymentQr?.expiresAt;

    return expiresAt != null && !expiresAt.isAfter(DateTime.now());
  }

  String _paymentQrRemainingTime() {
    final expiresAt = _paymentQr?.expiresAt;

    if (expiresAt == null) {
      return '';
    }

    final totalSeconds = expiresAt.difference(DateTime.now()).inSeconds;

    if (totalSeconds <= 0) {
      return '00:00';
    }

    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;

    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Booking _currentBooking(ParkingProvider provider) {
    for (final booking in provider.bookings) {
      if (booking.id == widget.booking.id) {
        return booking;
      }
    }

    return widget.booking;
  }

  bool _isBookingPaid(Booking booking) {
    return booking.status == 'ready_to_exit' &&
        booking.payment?.isPaid == true;
  }

  Widget _buildPromptPayQr({
    required Booking booking,
    required bool isPaid,
  }) {
    if (isPaid) {
      return const SizedBox.shrink();
    }

    if (_isLoadingPaymentQr) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
        ),
      );
    }

    if (_paymentQr == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 36,
            ),
            const SizedBox(height: 8),
            const Text(
              'ไม่สามารถแสดง PromptPay QR ได้',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            if (_paymentQrError != null) ...[
              const SizedBox(height: 6),
              Text(
                _paymentQrError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _createPaymentQr,
              icon: const Icon(Icons.refresh),
              label: const Text('กรุณาลองใหม่อีกครั้ง'),
            ),
          ],
        ),
      );
    }

    final isExpired = _isPaymentQrExpired;

    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(left: 40, bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: Column(
        children: [
          SizedBox(
            width: 180,
            height: 180,
            child: isExpired
                ? ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: 5,
                      sigmaY: 5,
                    ),
                    child: QrImageView(
                      data: _paymentQr!.qrUrl,
                      version: QrVersions.auto,
                      size: 180,
                      backgroundColor: Colors.white,
                    ),
                  )
                : QrImageView(
                    data: _paymentQr!.qrUrl,
                    version: QrVersions.auto,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
          ),
          const SizedBox(height: 12),
          Text(
            'ยอดชำระ: ฿${booking.totalAmount}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          if (isExpired)
            TextButton.icon(
              onPressed: _isReissuingPaymentQr
                  ? null
                  : _reissuePaymentQr,
              icon: _isReissuingPaymentQr
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              label: const Text('Reset'),
            )
          else
            Text(
              'หมดอายุใน ${_paymentQrRemainingTime()} นาที',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
          if (_paymentQrResetError != null) ...[
            const SizedBox(height: 4),
            Text(
              _paymentQrResetError!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'กรุณาบันทึกภาพ QR Code เพื่อใช้ในกรณีเกิดเหตุขัดข้องในการเข้าสู่พื้นที่จอดรถ',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.save_alt_outlined,
                size: 18,
                color: Color(0xFF0000CD),
              ),
              SizedBox(width: 6),
              Text(
                'Save',
                style: TextStyle(
                  color: Color(0xFF0000CD),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pay() async {
    if (_method == 'promptpay') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาสแกน PromptPay QR เพื่อยืนยันการชำระเงิน'),
          backgroundColor: Color(0xFFCD2626),
        ),
      );
      return;
    }

    if (_method == 'card' && _selectedPaymentCardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกบัตรที่ต้องการชำระเงิน'),
          backgroundColor: Color(0xFFCD2626),
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await ApiService.confirmPaymentWithDetails(
        bookingId: widget.booking.id,
        method: _method,
        paymentCardId:
            _method == 'card' ? _selectedPaymentCardId : null,
      );

      if (!mounted) {
        return;
      }

      await context.read<ParkingProvider>().loadBookings();

      if (!mounted) {
        return;
      }

      setState(() {
        _isPaid = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินสำเร็จ!'),
          backgroundColor: Color(0xFF228B22),
        ),
      );
    } on ApiRequestException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: const Color(0xFFCD2626),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ชำระเงินไม่สำเร็จ กรุณาลองใหม่อีกครั้ง'),
          backgroundColor: Color(0xFFCD2626),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();
    final b = _currentBooking(provider);
    final isPaid = _isPaid || _isBookingPaid(b);
    final canPay = b.enteredAt != null;
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
                _summaryRow('เข้าจอดจริง', canPay ? fmt.format(b.enteredAt!) : 'รอยืนยันจาก IR3'),
                _summaryRow('กำหนดออก',  fmt.format(b.endTime)),
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

            if (!canPay && !isPaid) ...[
              const Text(
                'ชำระเงินได้หลังระบบยืนยันรถผ่านไม้กั้นทางเข้าแล้ว',
                style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
            ],

            // เลือกวิธีชำระ
            const Text('วิธีชำระเงิน',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black54)),
            const SizedBox(height: 10),

            // PromptPay QR
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.qr_code_scanner,
                  color: Color(0xFF0000CD),
                  size: 28,
                ),
                title: const Text(
                  'PromptPay QR',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                onExpansionChanged: isPaid || !canPay
                    ? null
                    : (expanded) {
                        if (expanded) {
                          setState(() => _method = 'promptpay');
                        }
                      },
                children: [
                  _buildPromptPayQr(
                    booking: b,
                    isPaid: isPaid,
                  ),
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
                        _bankAppOption('ธนาคารกสิกรไทย', 'assets/images/KBANK.png', const Color(0xFF1D9E75), isPaid,),
                        _bankAppOption('ธนาคารไทยพาณิชย์', 'assets/images/SCB.png', const Color(0xFF4E2A84), isPaid,),
                        _bankAppOption('ธนาคารกรุงไทย', 'assets/images/KTB.jpg', const Color(0xFF00AEEF), isPaid,),
                        _bankAppOption('ธนาคารกรุงเทพ', 'assets/images/BBL.png', const Color(0xFF1E3A8A), isPaid,),
                        _bankAppOption('ธนาคารกรุงศรีอยุธยา', 'assets/images/BAY.png', const Color(0xFFFFC425), isPaid,),
                        _bankAppOption('ธนาคารทหารไทยธนชาต', 'assets/images/TTB.png', const Color(0xFFFF5000), isPaid,),
                        _bankAppOption('ธนาคารออมสิน', 'assets/images/GSB.jpg', const Color(0xFFEC008C), isPaid,),
                      ],
                    ),
                  )
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            // Credit/Debit Card
            Theme(
              data: Theme.of(context).copyWith(
                dividerColor: Colors.transparent,
              ),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                leading: const Icon(
                  Icons.credit_card,
                  color: Color(0xFF0000CD),
                  size: 28,
                ),
                title: const Text(
                  'บัตรเครดิต/บัตรเดบิต',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                children: [
                  Container(
                    margin: const EdgeInsets.only(
                      left: 40,
                      bottom: 8,
                      top: 8,
                    ),
                    decoration: const BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        if (_isLoadingCards)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (_cardsError != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                Text(
                                  _cardsError!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.red,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: _loadPaymentCards,
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง'),
                                ),
                              ],
                            ),
                          )
                        else if (_paymentCards.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              'ไม่พบบัตรที่บันทึกไว้',
                              style: TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                          )
                        else
                          for (final card in _paymentCards)
                            ListTile(
                              enabled: !isPaid,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 0,
                              ),
                              leading: const Icon(
                                Icons.credit_card,
                                color: Color(0xFF0000CD),
                                size: 28,
                              ),
                              title: Text(
                                '${card.cardBrand} •••• ${card.last4}',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${card.holderName} • หมดอายุ ${card.expiryDate}',
                              ),
                              trailing: _method == 'card' &&
                                      _selectedPaymentCardId == card.id
                                  ? const Icon(
                                      Icons.check_circle,
                                      color: Color(0xFF0000CD),
                                      size: 20,
                                    )
                                  : null,
                              onTap: isPaid
                                  ? null
                                  : () {
                                      setState(() {
                                        _method = 'card';
                                        _selectedPaymentCardId = card.id;
                                      });
                                    },
                            ),
                        ListTile(
                          enabled: !isPaid,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                          leading: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: Colors.black26,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(
                              Icons.add,
                              color: Colors.black54,
                              size: 20,
                            ),
                          ),
                          title: const Text(
                            'เพิ่มบัตรเครดิต/บัตรเดบิตใหม่',
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF0000CD),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: isPaid ? null : _openAddCard,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),

            const SizedBox(height: 32),

            // เมื่อชำระเงินสำเร็จแล้วเปลี่ยนเป็นปุ่มใบเสร็จทันที
            if (isPaid)
              FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => ReceiptScreen(booking: b)),
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
              onPressed: _loading || !canPay ? null : _pay,
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
            if (!isPaid)
              TextButton(
                onPressed: _loading ? null : () => Navigator.pop(context),
                child: const Text(
                  'ยกเลิกรายการชำระเงิน',
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
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

  Widget _bankAppOption(
    String bankName,
    String imagePath,
    Color tempIconColor,
    bool isPaid,
  ) {
    return ListTile(
      enabled: !isPaid,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 0,
      ),
      leading: CircleAvatar(
        radius: 14,
        backgroundColor: tempIconColor,
        child: Image.asset(imagePath),
      ),
      title: Text(
        bankName,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
      ),
      onTap: isPaid
          ? null
          : () {
              setState(() {
                _method = 'mobile_banking_$bankName';
              });
            },
      trailing: _method == 'mobile_banking_$bankName'
          ? const Icon(
              Icons.check_circle,
              color: Color(0xFF0000CD),
              size: 20,
            )
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
