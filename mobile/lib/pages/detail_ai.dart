import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DetailAIPage extends StatelessWidget {
  final String title;
  final String confidence;
  final String description;
  
  const DetailAIPage({
    super.key,
    required this.title,
    required this.confidence,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: Text('DetailAi', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        backgroundColor: const Color(0xFF1F6E8A),
        foregroundColor: Colors.white,
      ),
      body: const Center(child: Text('DetailAi Page')),
    );
  }
}
