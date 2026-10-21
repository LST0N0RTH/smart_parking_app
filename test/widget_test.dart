import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_parking_app/main.dart';
import 'package:smart_parking_app/providers/parking_provider.dart';
import 'package:smart_parking_app/screens/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets(
    'แสดงหน้าเข้าสู่ระบบเมื่อไม่มี session ที่บันทึกไว้',
    (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<ParkingProvider>(
          create: (_) => ParkingProvider(),
          child: const SmartParkingApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Session Expired'), findsNothing);
    },
  );
}