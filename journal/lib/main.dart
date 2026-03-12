import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const JournalApp());
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
        fontFamily: 'Montserrat',
        textTheme: const TextTheme(
          displayLarge:  TextStyle(fontFamily: 'IosevkaCharonMono'),
          displayMedium: TextStyle(fontFamily: 'IosevkaCharonMono'),
          displaySmall:  TextStyle(fontFamily: 'IosevkaCharonMono'),
          headlineLarge: TextStyle(fontFamily: 'IosevkaCharonMono'),
          headlineMedium:TextStyle(fontFamily: 'IosevkaCharonMono'),
          headlineSmall: TextStyle(fontFamily: 'IosevkaCharonMono'),
          titleLarge:    TextStyle(fontFamily: 'IosevkaCharonMono'),
          titleMedium:   TextStyle(fontFamily: 'IosevkaCharonMono'),
          titleSmall:    TextStyle(fontFamily: 'IosevkaCharonMono'),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
