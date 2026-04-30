import 'package:flutter/material.dart';
import '../store/auth_store.dart';
import '../widgets/findly_logo.dart';
import '../widgets/gradient_background.dart';
import 'auth/phone_entry.dart';
import 'employer/home.dart';
import 'employee/home.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, __, ___) => _decideHome(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Widget _decideHome() {
    if (!authStore.isLoggedIn) return const PhoneEntryScreen();
    switch (authStore.role) {
      case 'employer':
        return const EmployerHomeScreen();
      case 'employee':
        return const EmployeeHomeScreen();
      default:
        return const PhoneEntryScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: BrandGradientBackground(
        child: Center(
          child: FindlyLogo(fontSize: 64, subtitle: 'BUSINESS'),
        ),
      ),
    );
  }
}
