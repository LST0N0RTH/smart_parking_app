class BookingQrToken {
  final int id;
  final int bookingId;
  final String bookingCode;
  final String qrType;
  final String token;
  final String qrUrl;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final DateTime? scannedAt;
  final DateTime? usedAt;
  final DateTime? revokedAt;

  const BookingQrToken({
    required this.id,
    required this.bookingId,
    required this.bookingCode,
    required this.qrType,
    required this.token,
    required this.qrUrl,
    required this.issuedAt,
    this.expiresAt,
    this.scannedAt,
    this.usedAt,
    this.revokedAt,
  });

  factory BookingQrToken.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      return DateTime.parse(value.toString());
    }

    return BookingQrToken(
      id: json['id'] as int,
      bookingId: json['booking_id'] as int,
      bookingCode: json['booking_code'].toString(),
      qrType: json['qr_type'].toString(),
      token: json['token'].toString(),
      qrUrl: json['qr_url'].toString(),
      issuedAt: DateTime.parse(json['issued_at'].toString()),
      expiresAt: parseDate(json['expires_at']),
      scannedAt: parseDate(json['scanned_at']),
      usedAt: parseDate(json['used_at']),
      revokedAt: parseDate(json['revoked_at']),
    );
  }
}