import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const JournalApp());
}

class JournalApp extends StatelessWidget {
  const JournalApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Body = Montserrat (already bundled), titles = Playfair Display via google_fonts.
    final base = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      useMaterial3: true,
      fontFamily: 'Montserrat',
    );

    return MaterialApp(
      title: 'Journal',
      theme: base.copyWith(
        textTheme: GoogleFonts.playfairDisplayTextTheme(base.textTheme).copyWith(
          // Body text stays Montserrat for readability — only *display/headline/title*
          // categories get Playfair Display.
          bodyLarge: base.textTheme.bodyLarge,
          bodyMedium: base.textTheme.bodyMedium,
          bodySmall: base.textTheme.bodySmall,
          labelLarge: base.textTheme.labelLarge,
          labelMedium: base.textTheme.labelMedium,
          labelSmall: base.textTheme.labelSmall,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
