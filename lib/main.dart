import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/parking_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  await initializeDateFormatting('th', null); 

  runApp(
    ChangeNotifierProvider(
      create: (_) => ParkingProvider(),
      child: const SmartParkingApp(),
    ),
  );
}

class SmartParkingApp extends StatelessWidget {
  const SmartParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    final String primaryFont = GoogleFonts.notoSerifDisplay().fontFamily!;
    final String fallbackFont = GoogleFonts.fahkwang().fontFamily!;
    final boldTextStyle = TextStyle(
      fontWeight: FontWeight.bold, 
      fontFamilyFallback: [fallbackFont],
    );

    return MaterialApp(
      title: 'Coolkids Smart Parking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0000CD)),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
        useMaterial3: true,
        fontFamily: primaryFont,
        
        textTheme: TextTheme(
          displayLarge: boldTextStyle,
          displayMedium: boldTextStyle,
          displaySmall: boldTextStyle,
          headlineLarge: boldTextStyle,
          headlineMedium: boldTextStyle,
          headlineSmall: boldTextStyle,
          titleLarge: boldTextStyle,
          titleMedium: boldTextStyle,
          titleSmall: boldTextStyle,
          bodyLarge: boldTextStyle,
          bodyMedium: boldTextStyle,
          bodySmall: boldTextStyle,
          labelLarge: boldTextStyle,
          labelMedium: boldTextStyle,
          labelSmall: boldTextStyle,
        ),
      ),
          home: const _StartupGate(),
    );
  }
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool _restoreFailureDialogShown = false;

  void _showRestoreFailureDialog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.read<ParkingProvider>().authRestoreFailed) {
        return;
      }

      showDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: const Color(0x66000000),
        builder: (dialogContext) {
          const primaryColor = Color(0xFF0000CD);

          return Dialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 10,
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          tooltip: 'ปิด',
                          icon: const Icon(
                            Icons.close_rounded,
                            color: Color(0xFF8A94A3),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 52,
                        color: primaryColor,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Session Expired',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'ไม่สามารถยืนยันการเข้าสู่ระบบได้ กรุณาเข้าสู่ระบบอีกครั้ง',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Color(0xFF333333),
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          style: FilledButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'ตกลง',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ParkingProvider>();

    if (!provider.authRestoreFailed) {
      _restoreFailureDialogShown = false;
    } else if (provider.isInitialized && !_restoreFailureDialogShown) {
      _restoreFailureDialogShown = true;
      _showRestoreFailureDialog();
    }

    final Widget page;
    if (provider.isLoggedIn) {
      page = provider.userRole == 'admin'
          ? const AdminDashboardScreen()
          : const HomeScreen();
    } else {
      page = const LoginScreen();
    }

    return Stack(
      children: [
        page,
        if (!provider.isInitialized) ...[
          const Positioned.fill(
            child: ModalBarrier(
              color: Color(0x88000000),
              dismissible: false,
            ),
          ),
          const Center(
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.all(Radius.circular(12)),
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('กำลังเข้าสู่ระบบ...'),
                    SizedBox(height: 16),
                    SizedBox(
                      width: 220,
                      child: LinearProgressIndicator(
                        color: Color(0xFF0000CD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}