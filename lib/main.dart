import 'package:flutter/material.dart';
import 'screens/login_page.dart';

void main() {
  runApp(const AuroraLoginApp());
}

class AuroraLoginApp extends StatelessWidget {
  const AuroraLoginApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aurora Login',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}
