import 'package:flutter/material.dart';
import 'screens/splash/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/otp_screen.dart';
import 'screens/role_selection/role_selection_screen.dart';
import 'screens/auth/welcome_screen.dart';
import 'screens/dropr/dropr_home_screen.dart';
import 'screens/needr/needr_home_screen.dart'; // ✅ new import

final Map<String, WidgetBuilder> appRoutes = {
  '/splash': (_) => const SplashScreen(),
  '/welcome': (_) => const WelcomeScreen(),
  '/login': (_) => const LoginScreen(),
  '/otp': (_) => const OTPScreen(),
  '/role': (_) => const RoleSelectionScreen(),
  '/dropr-home': (_) => const DroprHomeScreen(),
  '/needr-home': (_) => const NeedrHomeScreen(), // ✅ new route
};
