import 'package:flutter/material.dart';

import '../screens/dashboard_screen.dart';
import '../screens/resident_dashboard_screen.dart';
import 'auth_service.dart';

/// Admins use the web panel, so only GoBikers and residents can enter the app.
bool canUseMobileApp(AppUser user) => user.isGoBiker || user.isResident;

/// "GoBiker" gets the ronda dashboard, "User" (resident) gets the resident one.
Widget screenForUser(AppUser user) =>
    user.isGoBiker ? const DashboardScreen() : const ResidentDashboardScreen();
