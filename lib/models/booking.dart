// เพิ่ม Class Payment เข้ามาด้านบนสุด
class Payment {
  final int     id;
  final int     amount;
  final String  method;
  final String  status;
  final DateTime? paidAt;

  const Payment({
    required this.id, 
    required this.amount,
    required this.method, 
    required this.status,
    this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
    id:     j['id'],
    amount: j['amount'],
    method: j['method'] ?? 'promptpay',
    status: j['status'] ?? 'pending',
    paidAt: j['paid_at'] != null ? DateTime.parse(j['paid_at']) : null,
  );

  bool get isPaid => status == 'paid';
}

class Booking {
  final int id;
  final int slotId;
  final DateTime startTime;
  final DateTime endTime;
  final String licensePlate; 
  final String status;
  final String slotName;
  final int totalAmount;    
  final Payment? payment;   
  final DateTime? createdAt;

  Booking({
    required this.id,
    required this.slotId,
    required this.startTime,
    required this.endTime,
    required this.licensePlate,
    required this.status,
    required this.slotName,
    required this.totalAmount, 
    this.payment,
    this.createdAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    String extractSlotName(dynamic jsonSlot) {
      if (jsonSlot == null) return 'N/A';
      if (jsonSlot is String) return jsonSlot;
      if (jsonSlot is Map && jsonSlot.containsKey('name')) return jsonSlot['name'];
      return 'N/A';
    }

    return Booking(
      id: json['id'],
      slotId: json['slot_id'],
      startTime: DateTime.parse(json['start_time']),
      endTime: DateTime.parse(json['end_time']),
      licensePlate: json['license_plate'] ?? '', 
      status: json['status'] ?? 'active',
      slotName: extractSlotName(json['slot']),
      totalAmount: json['total_amount'] ?? 0,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : DateTime.now(),
      payment: json['payment'] != null ? Payment.fromJson(json['payment']) : null,
    );
  }
}