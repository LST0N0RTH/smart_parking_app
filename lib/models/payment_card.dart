class PaymentCard {
  final int id;
  final String cardBrand;
  final String last4;
  final String holderName;
  final String expiryDate;
  final DateTime createdAt;

  const PaymentCard({
    required this.id,
    required this.cardBrand,
    required this.last4,
    required this.holderName,
    required this.expiryDate,
    required this.createdAt,
  });

  factory PaymentCard.fromJson(Map<String, dynamic> json) {
    return PaymentCard(
      id: json['id'] as int,
      cardBrand: json['card_brand'].toString(),
      last4: json['last4'].toString(),
      holderName: json['holder_name'].toString(),
      expiryDate: json['expiry_date'].toString(),
      createdAt: DateTime.parse(json['created_at'].toString()),
    );
  }
  String get displayLabel => '$cardBrand **** $last4';
}