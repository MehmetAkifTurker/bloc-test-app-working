// import 'dart:ui' show ImageFilter;
// import 'package:flutter/material.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

// class MainMenu extends StatefulWidget {
//   const MainMenu({Key? key}) : super(key: key);

//   @override
//   State<MainMenu> createState() => _MainMenuState();
// }

// class _MainMenuState extends State<MainMenu> {
//   void _go(String route) {
//     Navigator.pushNamed(context, route);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return PopScope(
//       // Ana menüde sistem geri hareketini devre dışı bırak
//       canPop: false,
//       // Predictive back uyumlu: geri tetiklense bile hiçbir şey yapma
//       onPopInvokedWithResult: (didPop, result) {
//         if (didPop) return;
//         // İstersen bilgi mesajı gösterebilirsin:
//         // ScaffoldMessenger.of(context).showSnackBar(
//         //   const SnackBar(content: Text('Ana menüdesiniz')),
//         // );
//       },
//       child: Scaffold(
//         appBar: commonAppBar(context, 'Main Menu', showBack: false),
//         body: Column(
//           children: [
//             Expanded(
//               child: _HalfImageButton(
//                 imagePath: 'assets/images/rfid_box_check.jpg',
//                 label: 'TAG READER',
//                 onTap: () => _go('/read'),
//               ),
//             ),
//             Expanded(
//               child: _HalfImageButton(
//                 imagePath: 'assets/images/rfid_scan.jpg',
//                 label: 'TAG WRITER',
//                 onTap: () => _go('/write'),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _HalfImageButton extends StatelessWidget {
//   final String imagePath;
//   final String label;
//   final VoidCallback onTap;

//   const _HalfImageButton({
//     Key? key,
//     required this.imagePath,
//     required this.label,
//     required this.onTap,
//   }) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return Material(
//       color: Colors.transparent,
//       child: InkWell(
//         onTap: onTap,
//         splashColor: Colors.white24,
//         child: Stack(
//           fit: StackFit.expand,
//           children: [
//             Image.asset(imagePath, fit: BoxFit.cover),
//             ClipRect(
//               child: BackdropFilter(
//                 filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
//                 child: Container(color: Colors.black.withOpacity(0.22)),
//               ),
//             ),
//             Center(
//               child: Padding(
//                 padding: const EdgeInsets.symmetric(horizontal: 12),
//                 child: FittedBox(
//                   fit: BoxFit.scaleDown,
//                   child: Stack(
//                     children: [
//                       // kontur
//                       Text(
//                         label,
//                         textAlign: TextAlign.center,
//                         style: TextStyle(
//                           fontSize: 52,
//                           fontWeight: FontWeight.w700,
//                           foreground: Paint()
//                             ..style = PaintingStyle.stroke
//                             ..strokeWidth = 3
//                             ..color = Colors.black,
//                         ),
//                       ),
//                       // dolgu
//                       Text(
//                         label,
//                         textAlign: TextAlign.center,
//                         style: const TextStyle(
//                           fontSize: 52,
//                           fontWeight: FontWeight.w700,
//                           color: Colors.white,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:water_boiler_rfid_labeler/ui/router/app_bar.dart';

class MainMenu extends StatefulWidget {
  const MainMenu({Key? key}) : super(key: key);

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  // Turkish Airlines brand colors
  static const Color _thyRed = Color(0xFFE31837);
  static const Color _thyNavy = Color(0xFF003B5C);

  void _go(String route) {
    HapticFeedback.selectionClick();
    Navigator.pushNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1114) : const Color(0xFFF6F7F9);

    return PopScope(
      canPop: false, // main menüde geri ile uygulama kapanmasın
      onPopInvokedWithResult: (_, __) {},
      child: Scaffold(
        appBar: commonAppBar(context, 'Main Menu', showBack: false),
        backgroundColor: bg,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Tool & Test Systems RFID\nSoftware',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .2,
                        color: _thyNavy,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 70),
                      decoration: const BoxDecoration(
                        borderRadius: BorderRadius.all(Radius.circular(4)),
                        gradient: LinearGradient(
                          colors: [_thyRed, _thyNavy],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                      ),
                    ),
                    const SizedBox(height: 36),

                    // TAG READER
                    _BrandActionCard(
                      icon: Icons.qr_code_scanner,
                      title: 'TAG READER',
                      subtitle: 'Scan and read RFID tags',
                      accent: _thyNavy,
                      onTap: () => _go('/read'),
                    ),
                    const SizedBox(height: 28),

                    // TAG WRITER
                    _BrandActionCard(
                      icon: Icons.edit,
                      title: 'TAG WRITER',
                      subtitle: 'Write & configure RFID tags',
                      accent: _thyNavy,
                      onTap: () => _go('/write'),
                    ),
                    const SizedBox(height: 28),

                    // NEW: QR CODE READER
                    _BrandActionCard(
                      icon: Icons.qr_code_2,
                      title: 'QR CODE READER',
                      subtitle: 'Scan QR codes',
                      accent: _thyRed,
                      onTap: () => _go('/qr'),
                    ),

                    const Spacer(),
                    const Center(
                      child: Text(
                        '© Turkish Airlines Technic',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  const _BrandActionCard({
    Key? key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? const Color(0xFF161A1F) : Colors.white;

    return Material(
      color: base,
      elevation: 4,
      shadowColor: Colors.black.withOpacity(.08),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withOpacity(.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withOpacity(.18)),
                ),
                child: Icon(icon, color: accent, size: 30),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .3,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.black.withOpacity(.55),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
