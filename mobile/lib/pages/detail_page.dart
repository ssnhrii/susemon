import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DetailPagePage extends StatelessWidget {
  const DetailPagePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: Text('DetailPage', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1F6E8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('DetailPage Page')),
    );
  }
}
