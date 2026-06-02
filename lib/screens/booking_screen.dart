import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
  DateTime _end   = DateTime.now().add(const Duration(hours: 1, minutes: 5));
  bool _loading   = false;
  String? _selectedPlate;

  @override
  void initState() {
    super.initState();
    final userPlates = context.read<ParkingProvider>().userPlates;
    if (userPlates.isNotEmpty) {
      _selectedPlate = userPlates.first;
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final now = DateTime.now();
    final picked = await showDateTimePicker(context, isStart ? _start : _end, now);
    if (picked == null) return;
    setState(() {
      if (isStart) { _start = picked; if (_end.isBefore(_start)) _end = _start.add(const Duration(hours: 1)); }
      else         { _end = picked; }
    });
  }

  Future<void> _confirm() async {
    if (_end.isBefore(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('เวลาออกต้องหลังเวลาเข้า', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.red));
      return;
    }
    
    if (_selectedPlate == null || _selectedPlate!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเพิ่มทะเบียนรถในหน้าข้อมูลส่วนบุุคลก่อนทำการจอง', style: TextStyle(fontWeight: FontWeight.bold)), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _loading = true);

    final ok = await ApiService.createBooking(widget.slot.id, _start, _end, _selectedPlate!);
    
    if (!mounted) return;
    setState(() => _loading = false);
    
    if (ok) {
      final provider = context.read<ParkingProvider>();
      await Future.wait([
        provider.loadSlots(),
        provider.loadBookings(), 
      ]);
      
      if (!mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('จอง ${widget.slot.name} สำหรับรถ $_selectedPlate สำเร็จ!', style: const TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: const Color(0xFF1D9E75)
        )
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('รถทะเบียน $_selectedPlate มีการจองค้างอยู่ในระบบแล้ว!', 
          style: const TextStyle(fontWeight: FontWeight.bold)), 
          backgroundColor: Colors.red
        )
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('dd MMM yyyy HH:mm', 'th');
    final userPlates = context.watch<ParkingProvider>().userPlates;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text('จอง Slot ${widget.slot.name}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0000CD),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(' เลือกรถที่จะจอด', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0000CD))),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFDCDCDC)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPlate,
                  isExpanded: true,
                  icon: const Icon(Icons.directions_car, color: Color(0xFF0000CD)),
                  hint: const Text('ยังไม่มีข้อมูลรถ'),
                  items: userPlates.map((plate) {
                    return DropdownMenuItem<String>(
                      value: plate,
                      child: Text(plate, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedPlate = val),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Text(' กำหนดเวลาเข้า-ออก', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0000CD))),
            const SizedBox(height: 8),

            _timeCard('เวลาเข้า', fmt.format(_start), () => _pickTime(true)),
            const SizedBox(height: 14),
            _timeCard('เวลาออก', fmt.format(_end),    () => _pickTime(false)),
            
            const Spacer(),
            
            FilledButton.icon(
              onPressed: _loading ? null : _confirm,
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle_outline),
              label: const Text('ยืนยันการจอง', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF0000CD),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeCard(String label, String value, VoidCallback onTap) =>
    ListTile(
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFDCDCDC))
      ),
      leading: const Icon(Icons.access_time, color: Color(0xFF0000CD)),
      title: Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
      subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      trailing: const Icon(Icons.edit_outlined, color: Colors.grey),
      onTap: onTap,
    );
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