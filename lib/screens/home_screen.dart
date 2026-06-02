import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/parking_provider.dart';
import '../models/slot.dart';
import 'booking_screen.dart';
import 'history_screen.dart';
import 'profile_screen.dart'; 
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ParkingProvider>().loadSlots();
      }
    });
  }

  Color _slotColor(Slot s) {
    if (s.isAvailable) return const Color(0xFF228B22);
    if (s.isReserved)  return const Color(0xFFe65100);
    return const Color(0xFFCD2626);
  }

  String _slotLabel(Slot s) {
    if (s.isAvailable) return 'ว่าง';
    if (s.isReserved)  return 'จองแล้ว';
    return 'ไม่ว่าง';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Parking', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF0000CD),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              final readProvider = context.read<ParkingProvider>();
              await readProvider.loadSlots();
              await readProvider.loadBookings();
              
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('อัปเดตข้อมูลล่าสุดแล้ว')),
              );
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await context.read<ParkingProvider>().logout();

              if (!context.mounted) return;

              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              );
            },
          ),
        ], // actions
      ),
      
      body: IndexedStack(
        index: _tab,
        children: [
          _buildHome(provider),       
          const ProfileScreen(), 
          const HistoryScreen(),      
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.local_parking), label: 'ที่จอดรถ'),
          NavigationDestination(icon: Icon(Icons.person), label: 'ข้อมูลบัญชี'),
          NavigationDestination(icon: Icon(Icons.history), label: 'ประวัติ'),
        ],
      ),
    );
  }

  Widget _buildHome(ParkingProvider provider) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          color: const Color(0xFF0000CD),
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Text(
            'ว่าง ${provider.availableCount} / ${provider.slots.length} ช่อง',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white, 
              fontSize: 20, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.8, 
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 18),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _legend(const Color(0xFF228B22), 'ว่าง'),
              const SizedBox(width: 30),
              _legend(const Color(0xFFe65100), 'จองแล้ว'),
              const SizedBox(width: 30),
              _legend(const Color(0xFFCD2626), 'ไม่ว่าง'),
            ],
          ),
        ),
        if (provider.isLoading)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(20),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3, crossAxisSpacing: 14, mainAxisSpacing: 14,
              ),
              itemCount: provider.slots.length,
              itemBuilder: (_, i) {
                final slot = provider.slots[i];
                return GestureDetector(
                  onTap: slot.isAvailable
                      ? () => Navigator.push(context,
                            MaterialPageRoute(
                              builder: (_) => BookingScreen(slot: slot)))
                      : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: _slotColor(slot),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(slot.name,
                            style: const TextStyle(color: Colors.white,
                                fontSize: 28, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 6),
                        Text(_slotLabel(slot),
                            style: const TextStyle(color: Colors.white70,
                                fontSize: 13, fontWeight: FontWeight.bold)), 
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
    Container(
      width: 20, 
      height: 20, 
      decoration: BoxDecoration(
        color: color, 
        borderRadius: BorderRadius.circular(6)
      ),
    ),
    const SizedBox(width: 10),
    Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
  ]);
}