import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // body: Container(
      //   color: titleBackgroundColor,
      //   child: Center(
      //     child: Column(
      //       children: [
      //         Image.asset(
      //           'assets/images/c4_TT_Logo_RGB.png',
      //           scale: 10.0,
      //           width: 200.0,
      //           height: 200.0,
      //           color: titleTextAndIconColor,
      //         ),
      //         Text(
      //           'R&D',
      //           style: TextStyle(
      //             color: titleTextAndIconColor,
      //             fontSize: 40,
      //           ),
      //         ),
      //         Text(
      //           'Tool & Test Systems',
      //           style: TextStyle(
      //             color: titleTextAndIconColor,
      //             fontSize: 30,
      //           ),
      //         ),
      //         Text(
      //           'Bootstrap RFID Reader v0.0.1',
      //           style: TextStyle(
      //             color: titleTextAndIconColor,
      //             fontSize: 10,
      //           ),
      //         ),
      //       ],
      //     ),
      //   ),
      // ),
      body: Stack(
        children: [
          Image.asset(
            'assets/images/launch_image.png',
            width: 720,
            height: 1440,
            fit: BoxFit.fill,
          ),
          const Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            right: 0,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Tool And Test Systems',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      //fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'RFID SOFTWARE',
                    style: TextStyle(color: Colors.white),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
