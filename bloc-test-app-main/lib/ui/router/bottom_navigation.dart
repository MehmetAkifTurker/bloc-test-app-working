// import 'dart:developer';

// import 'package:water_boiler_rfid_labeler/business_logic/cubit/navigaion_qubit_cubit.dart';
// import 'package:water_boiler_rfid_labeler/data/models/variables.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_router.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// Widget bottomNavigationBar(BuildContext context) {
//   return BlocBuilder<NavigationCubit, int>(
//     builder: (context, state) {
//       return BottomNavigationBar(
//         currentIndex: state,
//         type: BottomNavigationBarType.fixed,
//         onTap: (index) {
//           log(index.toString());
//           context.read<NavigationCubit>().navigateToPage(index);
//           Navigator.pushNamedAndRemoveUntil(
//               context, pageNames[index], (route) => false);
//         },
//         showSelectedLabels: true,
//         showUnselectedLabels: true,
//         backgroundColor: titleBackgroundColor,
//         selectedItemColor: titleTextAndIconColor,
//         unselectedItemColor: titleTextAndIconColorDeactive,
//         items: const [
//           BottomNavigationBarItem(
//             icon: Icon(Icons.home),
//             label: 'Home',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.check),
//             label: 'Check',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.add),
//             label: 'Add',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.search),
//             label: 'DB',
//           ),
//           BottomNavigationBarItem(
//             icon: Icon(Icons.edit),
//             label: 'Write',
//           ),
//         ],
//       );
//     },
//   );
// }
import 'package:flutter/material.dart';
import 'app_router.dart';

Widget bottomNavigationBar(BuildContext context) {
  return BottomNavigationBar(
    currentIndex: 0,
    type: BottomNavigationBarType.fixed,
    onTap: (index) {
      Navigator.pushNamedAndRemoveUntil(
          context, pageNames[index], (route) => false);
    },
    selectedItemColor: Colors.white,
    unselectedItemColor: Colors.white70,
    backgroundColor: const Color.fromRGBO(239, 46, 31, 1),
    items: const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Main',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.qr_code_scanner),
        label: 'Read Tag',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.edit),
        label: 'Write Tag',
      ),
    ],
  );
}
