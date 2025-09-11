import 'package:water_boiler_rfid_labeler/data/models/variables.dart';
import 'package:flutter/material.dart';

SizedBox commonDrawer(BuildContext context) {
  Color textAndIconColor = titleTextAndIconColor;
  Color backgroundColor = titleBackgroundColor;
  return SizedBox(
    width: 100.0,
    child: Drawer(
      backgroundColor: backgroundColor,
      child: Column(
        children: [
          Image.asset(
            'assets/images/c4_TT_Logo_RGB.png',
            //scale: 10.0,
            //width: 200.0,
            //height: 200.0,
            color: titleTextAndIconColor,
          ),
          IconButton(
            color: textAndIconColor,
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            icon: const Icon(Icons.menu),
          ),
          IconButton(
            color: textAndIconColor,
            onPressed: () {
              Navigator.pushNamedAndRemoveUntil(
                  context, '/second', (route) => false);
            },
            icon: const Icon(Icons.data_object),
          ),
        ],
      ),
    ),
  );
}
