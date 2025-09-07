import 'dart:io';
import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'crop_page.dart';

class PagesEditPage extends StatelessWidget {
  final Piece piece;
  const PagesEditPage({super.key, required this.piece});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Pages',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: piece.imagePaths?.length ?? 0,
        itemBuilder: (context, index) {
          final pagePath = piece.imagePaths![index];
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Image.file(
              File(pagePath),
              height: 80,
              fit: BoxFit.fitHeight,
            ),
            title: Text(
              'Page ${index + 1}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.arrow_forward, color: Colors.black),
            onTap: () async {
              // Navigate to crop screen for this page
              final result = await Navigator.push<Piece?>(
                context,
                MaterialPageRoute(builder: (_) => CropPage(piece: piece, pageIndex: index)),
              );
              if (result != null && context.mounted) {
                // If a crop was applied (piece updated), pop back to PiecePage with updated piece
                Navigator.pop(context, result);
              }
            },
          );
        },
      ),
    );
  }
}
