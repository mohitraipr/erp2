import 'package:flutter/material.dart';
import 'screens/login_page.dart';
import 'screens/response_page.dart';
import 'models/login_response.dart';

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
      onGenerateRoute: (settings) {
        if (settings.name == ResponsePage.routeName) {
          final data = settings.arguments as LoginResponse;
          return MaterialPageRoute(builder: (_) => ResponsePage(data: data));
        }
        return null;
      },
    );
  }
}
