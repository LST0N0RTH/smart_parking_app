DateTime _requiredLocalDateTime(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value is! String || value.isEmpty) {
    throw FormatException('Invalid $key');
  }

  return DateTime.parse(value).toLocal();
}

DateTime? _optionalLocalDateTime(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid optional datetime');
  }

  return DateTime.parse(value).toLocal();
}

int _requiredInt(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw FormatException('Invalid $key');
}

int? _optionalInt(dynamic value) {
  if (value == null) {
    return null;
  }

  if (value is int) {
    return value;
  }

  if (value is num) {
    return value.toInt();
  }

  throw const FormatException('Invalid optional integer');
}

String _requiredString(
  Map<String, dynamic> json,
  String key,
) {
  final value = json[key];

  if (value is! String) {
    throw FormatException('Invalid $key');
  }

  return value;
}

class BookingVehicle {
  final int id;
  final String plateNumber;
  final String province;

  const BookingVehicle({
    required this.id,
    required this.plateNumber,
    required this.province,
  });

  factory BookingVehicle.fromJson(Map<String, dynamic> json) {
    return BookingVehicle(
      id: _requiredInt(json, 'id'),
      plateNumber: _requiredString(json, 'plate_number'),
      province: _requiredString(json, 'province'),
    );
  }
}

class BookingUser {
  final int id;
  final String name;
  final String? username;
  final DateTime? usernameChangedAt;
  final String email;
  final String role;
  final String? licensePlate;
  final List<BookingVehicle> vehicles;

  const BookingUser({
    required this.id,
    required this.name,
    this.username,
    this.usernameChangedAt,
    required this.email,
    required this.role,
    this.licensePlate,
    required this.vehicles,
  });

  factory BookingUser.fromJson(Map<String, dynamic> json) {
    final rawVehicles = json['vehicles'];

    if (rawVehicles is! List) {
      throw const FormatException('Invalid user vehicles');
    }

    return BookingUser(
      id: _requiredInt(json, 'id'),
      name: _requiredString(json, 'name'),
      username: json['username']?.toString(),
      usernameChangedAt: _optionalLocalDateTime(
        json['username_changed_at'],
      ),
      email: _requiredString(json, 'email'),
      role: _requiredString(json, 'role'),
      licensePlate: json['license_plate']?.toString(),
      vehicles: rawVehicles.map((rawVehicle) {
        if (rawVehicle is! Map) {
          throw const FormatException('Invalid user vehicle');
        }

        return BookingVehicle.fromJson(
          Map<String, dynamic>.from(rawVehicle),
        );
      }).toList(growable: false),
    );
  }
}

class Payment {
  final int id;
  final int bookingId;
  final int amount;
  final int? baseAmount;
  final int? overstayFee;
  final int? paymentCardId;
  final String? cardBrand;
  final String? cardLast4;
  final String? method;
  final String status;
  final DateTime? paidAt;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.amount,
    this.baseAmount,
    this.overstayFee,
    this.paymentCardId,
    this.cardBrand,
    this.cardLast4,
    this.method,
    required this.status,
    this.paidAt,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: _requiredInt(json, 'id'),
      bookingId: _requiredInt(json, 'booking_id'),
      amount: _requiredInt(json, 'amount'),
      baseAmount: _optionalInt(json['base_amount']),
      overstayFee: _optionalInt(json['overstay_fee']),
      paymentCardId: _optionalInt(json['payment_card_id']),
      cardBrand: json['card_brand']?.toString(),
      cardLast4: json['card_last4']?.toString(),
      method: json['method']?.toString(),
      status: _requiredString(json, 'status'),
      paidAt: _optionalLocalDateTime(json['paid_at']),
    );
  }

  bool get isPaid => status == 'paid';
}

class Booking {
  final int id;
  final String bookingCode;
  final int slotId;
  final int? vehicleId;
  final String licensePlate;
  final String? vehiclePlateNumber;
  final String? vehicleProvince;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? enteredAt;
  final DateTime? exitedAt;
  final String status;
  final int totalAmount;
  final DateTime createdAt;
  final String slotName;
  final String slotStatus;
  final BookingUser user;
  final Payment? payment;

  const Booking({
    required this.id,
    required this.bookingCode,
    required this.slotId,
    this.vehicleId,
    required this.licensePlate,
    this.vehiclePlateNumber,
    this.vehicleProvince,
    required this.startTime,
    required this.endTime,
    this.enteredAt,
    this.exitedAt,
    required this.status,
    required this.totalAmount,
    required this.createdAt,
    required this.slotName,
    required this.slotStatus,
    required this.user,
    this.payment,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    final rawSlot = json['slot'];
    final rawUser = json['user'];
    final rawPayment = json['payment'];

    if (rawSlot is! Map) {
      throw const FormatException('Invalid booking slot');
    }

    if (rawUser is! Map) {
      throw const FormatException('Invalid booking user');
    }

    Payment? payment;

    if (rawPayment != null) {
      if (rawPayment is! Map) {
        throw const FormatException('Invalid booking payment');
      }

      payment = Payment.fromJson(
        Map<String, dynamic>.from(rawPayment),
      );
    }

    final slot = Map<String, dynamic>.from(rawSlot);

    return Booking(
      id: _requiredInt(json, 'id'),
      bookingCode: _requiredString(json, 'booking_code'),
      slotId: _requiredInt(json, 'slot_id'),
      vehicleId: _optionalInt(json['vehicle_id']),
      licensePlate: json['license_plate']?.toString() ?? '',
      vehiclePlateNumber: json['vehicle_plate_number']?.toString(),
      vehicleProvince: json['vehicle_province']?.toString(),
      startTime: _requiredLocalDateTime(json, 'start_time'),
      endTime: _requiredLocalDateTime(json, 'end_time'),
      enteredAt: _optionalLocalDateTime(json['entered_at']),
      exitedAt: _optionalLocalDateTime(json['exited_at']),
      status: _requiredString(json, 'status'),
      totalAmount: _requiredInt(json, 'total_amount'),
      createdAt: _requiredLocalDateTime(json, 'created_at'),
      slotName: _requiredString(slot, 'name'),
      slotStatus: _requiredString(slot, 'status'),
      user: BookingUser.fromJson(
        Map<String, dynamic>.from(rawUser),
      ),
      payment: payment,
    );
  }
}