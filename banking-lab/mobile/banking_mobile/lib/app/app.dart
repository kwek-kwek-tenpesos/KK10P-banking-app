import 'package:banking_mobile/features/system_info/presentation/screens/system_info_screen.dart';
import 'package:flutter/material.dart';

class BankingLabApp extends StatelessWidget {
  const BankingLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Banking Lab',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SystemInfoScreen(),
    );
  }
}
