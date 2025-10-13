import 'package:flutter/material.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const AuroraLoginApp());
}

class AuroraLoginApp extends StatelessWidget {
  const AuroraLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1F3C88),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Aurora ERP',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF6F8FB),
        cardTheme: baseTheme.cardTheme.copyWith(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: baseTheme.colorScheme.surface,
          foregroundColor: baseTheme.colorScheme.onSurface,
          centerTitle: true,
          elevation: 0,
        ),
        textTheme: baseTheme.textTheme.apply(
          bodyColor: const Color(0xFF1F2937),
          displayColor: const Color(0xFF111827),
        ),
      ),
      home: const LoginPage(),
    );
  }
}
