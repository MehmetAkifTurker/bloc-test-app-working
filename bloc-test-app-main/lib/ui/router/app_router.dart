import 'package:water_boiler_rfid_labeler/ui/screens/box_check_scan_screen/box_check_scan_screen.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/main_menu/main_menu.dart';
import 'package:flutter/material.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/qr_scan_screen/qr_scan_screen.dart';

import '../screens/tag_write_screen/tag_write_screen.dart';

// class AppRouter {
//   Route onGenerateRoute(RouteSettings routeSettings) {
//     switch (routeSettings.name) {
//       case '/':
//         return MaterialPageRoute(builder: (_) => const MainMenu());
//       case '/db':
//         return MaterialPageRoute(builder: (_) => const RfidTagListScreen());

//       case '/rfidscan':
//         return MaterialPageRoute(builder: (_) => RfidScanTagListScreen());
//       case '/boxcheck':
//         return MaterialPageRoute(builder: (_) => const BoxCheckScanScreen());
//       case '/tagwrite':
//         return MaterialPageRoute(builder: (_) => const TagWriteScreen());

//       default:
//         return MaterialPageRoute(builder: (_) => const RfidTagListScreen());
//     }
//   }
// }

// List<String> pageNames = [
//   '/',
//   '/boxcheck',
//   '/rfidscan',
//   '/db',
//   '/tagwrite',
// ];

class AppRouter {
  Route onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const MainMenu());
      case '/read':
        return MaterialPageRoute(builder: (_) => const BoxCheckScanScreen());
      case '/write':
        return MaterialPageRoute(builder: (_) => const TagWriteScreen());
      case '/qr':
        return MaterialPageRoute(builder: (_) => const QrScanScreen());
      default:
        return MaterialPageRoute(builder: (_) => const MainMenu());
    }
  }

  PageRoute _fast(Widget page) => PageRouteBuilder(
        pageBuilder: (_, __, ___) => page,
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 150),
        reverseTransitionDuration: const Duration(milliseconds: 150),
      );
}

List<String> pageNames = ['/', '/read', '/write', '/qr'];
