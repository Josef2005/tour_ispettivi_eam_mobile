import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// IMPORTA SEMPRE COSÌ:
import 'package:tour_ispettivi_efm_mobile/viewmodels/login_viewmodel.dart';
import 'package:tour_ispettivi_efm_mobile/viewmodels/sync_viewmodel.dart';
import 'package:tour_ispettivi_efm_mobile/viewmodels/interventions_viewmodel.dart';
import 'package:tour_ispettivi_efm_mobile/views/login_view.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoginViewModel()),
        ChangeNotifierProvider(create: (_) => SyncViewModel()),
        ChangeNotifierProvider(create: (_) => InterventionsViewModel()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'eFm Inspection Tour',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8.0),
            borderSide: const BorderSide(color: Colors.blue, width: 2.0),
          ),
        ),
      ),
      home: const LoginView(),
    );
  }
}
