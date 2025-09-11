// import 'dart:async';
// import 'dart:developer';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/box_check/box_check_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_filtering_bloc/bloc/db_filtering_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_event.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag_popup/db_tag_popup_cubit.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/rfid_tag/rfid_tag_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/cubit/navigaion_qubit_cubit.dart';
// import 'package:water_boiler_rfid_labeler/data/repositories/rfid_tag_repository.dart';
// import 'package:water_boiler_rfid_labeler/firebase_options.dart';
// import 'package:water_boiler_rfid_labeler/java_comm/rfid_c72_plugin.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_router.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/main_menu/main_menu.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/splash_screen/splash_screen.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(
//     options: DefaultFirebaseOptions.currentPlatform,
//   );
//   log("Connecting RFID module at app startup...");
//   final bool? connected = await RfidC72Plugin.connect;
//   if (connected == true) {
//     log("RFID module connected successfully at startup!");
//   } else {
//     log("Failed to connect RFID module at startup.");
//   }

//   runApp(MultiBlocProvider(
//     providers: [
//       BlocProvider(
//         create: (context) => DBTagBloc(RfidTagRepository())..add(DBGetTags()),
//       ),
//       BlocProvider(
//         create: (context) => DbTagPopupCubit(),
//       ),
//       BlocProvider(
//         create: (context) => NavigationCubit(),
//       ),
//       BlocProvider(
//         create: (context) => DbFilteringBloc()
//           ..add(const DbFilterSelectionEvent(
//               filteringStates: FilteringStates.none)),
//       ),
//       BlocProvider(
//         create: (context) => RfidTagBloc(),
//       ),
//       BlocProvider(
//         create: (context) => BoxCheckBloc(),
//       )
//     ],
//     child: MyApp(),
//   ));
// }

// class MyApp extends StatelessWidget {
//   MyApp({Key? key}) : super(key: key);
//   final AppRouter _appRouter = AppRouter();

//   @override
//   Widget build(BuildContext context) {
//     // Delay to allow splash screen to be shown (if desired)
//     return FutureBuilder(
//       future: Future.delayed(const Duration(seconds: 5)),
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.done) {
//           // If needed, you could initialize key events here:
//           // RfidC72Plugin.initializeKeyEventHandler(context);
//           return MaterialApp(
//             title: 'RFID App',
//             debugShowCheckedModeBanner: false,
//             theme: ThemeData(
//               colorScheme: ColorScheme.fromSeed(seedColor: Colors.white),
//               useMaterial3: true,
//             ),
//             home: const MainMenu(),
//             onGenerateRoute: _appRouter.onGenerateRoute,
//           );
//         }
//         return const MaterialApp(
//           debugShowCheckedModeBanner: false,
//           home: SplashScreen(),
//         );
//       },
//     );
//   }
// }
// import 'dart:developer';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:firebase_core/firebase_core.dart';

// import 'package:water_boiler_rfid_labeler/firebase_options.dart';
// import 'package:water_boiler_rfid_labeler/ui/router/app_router.dart';
// import 'package:water_boiler_rfid_labeler/ui/screens/main_menu/main_menu.dart';

// import 'package:water_boiler_rfid_labeler/business_logic/blocs/box_check/box_check_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_filtering_bloc/bloc/db_filtering_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag/db_tag_event.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/db_tag_popup/db_tag_popup_cubit.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/blocs/rfid_tag/rfid_tag_bloc.dart';
// import 'package:water_boiler_rfid_labeler/business_logic/cubit/navigaion_qubit_cubit.dart';
// import 'package:water_boiler_rfid_labeler/data/repositories/rfid_tag_repository.dart';

// Future<void> main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

//   // (Opsiyonel) Sistem barları
//   SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
//     statusBarColor: Colors.transparent,
//     statusBarIconBrightness: Brightness.light,
//     systemNavigationBarColor: Colors.black,
//     systemNavigationBarIconBrightness: Brightness.light,
//   ));

//   runApp(const Root());
// }

// class Root extends StatelessWidget {
//   const Root({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MultiBlocProvider(
//       providers: [
//         BlocProvider(
//             create: (_) => DBTagBloc(RfidTagRepository())..add(DBGetTags())),
//         BlocProvider(create: (_) => DbTagPopupCubit()),
//         BlocProvider(create: (_) => NavigationCubit()),
//         BlocProvider(
//             create: (_) => DbFilteringBloc()
//               ..add(const DbFilterSelectionEvent(
//                   filteringStates: FilteringStates.none))),
//         BlocProvider(create: (_) => RfidTagBloc()),
//         BlocProvider(create: (_) => BoxCheckBloc()),
//       ],
//       child: const MyApp(),
//     );
//   }
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//   static const Color _thyRed = Color(0xFFE31837);
//   static const Color _thyNavy = Color(0xFF003B5C);

//   @override
//   Widget build(BuildContext context) {
//     final appRouter = AppRouter();

//     final scheme = ColorScheme.fromSeed(
//       seedColor: _thyRed,
//       brightness: Brightness.light,
//     ).copyWith(
//       primary: _thyRed,
//       secondary: _thyNavy,
//       surfaceTint: _thyRed,
//     );

//     return MaterialApp(
//       title: 'RFID App',
//       debugShowCheckedModeBanner: false,
//       // 🔹 Tema renk düzenlemesi YOK — yalnızca M3 açık
//       theme: ThemeData(useMaterial3: true),
//       home: const MainMenu(),
//       onGenerateRoute: appRouter.onGenerateRoute,
//     );
//   }
// }
// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:water_boiler_rfid_labeler/ui/router/app_router.dart';
import 'package:water_boiler_rfid_labeler/ui/screens/main_menu/main_menu.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // (Opsiyonel) Sistem bar görünümü
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final appRouter = AppRouter();
    return MaterialApp(
      title: 'RFID App',
      debugShowCheckedModeBanner: false,
      // Tema: eski hâl (renk düzenlemesi yok)
      theme: ThemeData(useMaterial3: true),
      home: const MainMenu(),
      onGenerateRoute: appRouter.onGenerateRoute,
    );
  }
}
