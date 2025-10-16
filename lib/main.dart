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
        seedColor: const Color(0xFF3F37C9),
        brightness: Brightness.light,
      ),
      fontFamily: 'Roboto',
      visualDensity: VisualDensity.adaptivePlatformDensity,
      useMaterial3: true,
    );

    final textTheme = baseTheme.textTheme.apply(
      bodyColor: const Color(0xFF1F2933),
      displayColor: const Color(0xFF0B132B),
    );

    return MaterialApp(
      title: 'Aurora ERP',
      theme: baseTheme.copyWith(
        scaffoldBackgroundColor: const Color(0xFFF3F5FB),
        textTheme: textTheme,
        cardTheme: baseTheme.cardTheme.copyWith(
          elevation: 4,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          clipBehavior: Clip.antiAlias,
        ),
        appBarTheme: baseTheme.appBarTheme.copyWith(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: baseTheme.colorScheme.primary, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: baseTheme.colorScheme.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
            textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            textStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            side: BorderSide(color: baseTheme.colorScheme.primary.withOpacity(0.4)),
          ),
        ),
        chipTheme: baseTheme.chipTheme.copyWith(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          side: BorderSide(color: baseTheme.colorScheme.primary.withOpacity(0.15)),
        ),
        snackBarTheme: baseTheme.snackBarTheme.copyWith(
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        tabBarTheme: baseTheme.tabBarTheme.copyWith(
          labelStyle: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          unselectedLabelStyle: textTheme.titleMedium,
          indicatorSize: TabBarIndicatorSize.tab,
        ),
      ),
      home: const LoginPage(),
    );
  }
}
