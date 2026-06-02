import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'providers/parking_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

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
      home: Consumer<ParkingProvider>(
        builder: (context, provider, child) {
          if (!provider.isInitialized) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: Color(0xFF0000CD)),
              ),
            );
          }
          return provider.isLoggedIn ? const HomeScreen() : const LoginScreen();
        },
      ),
    );
  }
}