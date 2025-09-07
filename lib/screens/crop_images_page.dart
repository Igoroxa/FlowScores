import 'dart:io';
import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'crop_image_page.dart';

class CropImagesPage extends StatefulWidget {
  final Piece piece;
  const CropImagesPage({Key? key, required this.piece}) : super(key: key);

  @override
  State<CropImagesPage> createState() => _CropImagesPageState();
}

class _CropImagesPageState extends State<CropImagesPage> {
  // Navigate to the single-image crop page and refresh on return
  Future<void> _openCropPage(int index) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CropImagePage(piece: widget.piece, pageIndex: index)),
    );
    setState(() {}); // refresh list to reflect any cropping changes
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.piece.imagePaths ?? [];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context, widget.piece),
        ),
        title: const Text(
          'Crop Images',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: images.isEmpty
          ? const Center(
              child: Text('No images to crop.', style: TextStyle(color: Colors.grey)),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: images.length,
              itemBuilder: (context, index) {
                final path = images[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Image.file(
                    File(path),
                    width: 80, // thumbnail width (height adjusts to aspect ratio)
                  ),
                  title: Text('Page ${index + 1}',
                      style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.w500)),
                  trailing: ElevatedButton(
                    onPressed: () => _openCropPage(index),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                    child: const Text('Crop', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  ),
                );
              },
            ),
    );
  }
}
