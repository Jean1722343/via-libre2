import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

void main() {
  runApp(const ViaLibreApp());
}

class ViaLibreApp extends StatefulWidget {
  const ViaLibreApp({super.key});

  @override
  State<ViaLibreApp> createState() => ViaLibreAppState();

  static ViaLibreAppState of(BuildContext context) {
    return context.findAncestorStateOfType<ViaLibreAppState>()!;
  }
}

class ViaLibreAppState extends State<ViaLibreApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme(bool isDark) {
    setState(() {
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Via Libre',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // Tema Claro (Estilo crema/bosque premium)
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF6EFE1),
        primaryColor: const Color(0xFF2F5D4C),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF2F5D4C),
          secondary: Color(0xFFBF5B34),
          surface: Color(0xFFF6EFE1),
        ),
      ),
      // Tema Oscuro (Estilo obsidiana/noche premium)
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090E17),
        primaryColor: const Color(0xFF2F5D4C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2F5D4C),
          secondary: Color(0xFFBF5B34),
          surface: Color(0xFF090E17),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
