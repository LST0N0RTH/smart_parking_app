class Slot {
  final int id;
  final String name;
  final String status; // available / reserved / occupied

  const Slot({required this.id, required this.name, required this.status});

  factory Slot.fromJson(Map<String, dynamic> j) =>
      Slot(id: j['id'], name: j['name'], status: j['status']);

  bool get isAvailable => status == 'available';
  bool get isReserved  => status == 'reserved';
  bool get isOccupied  => status == 'occupied';
}