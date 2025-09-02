// lib/models/piece.dart
import 'dart:convert';

enum PieceType { pdf, image }

class Piece {
  String name;
  String? composer;
  String difficulty;
  String progress;
  PieceType type;
  String? pdfPath;
  List<String>? imagePaths;
  String? videoPath;  // new field for performance video file path

  Piece({
    required this.name,
    this.composer,
    required this.difficulty,
    required this.progress,
    required this.type,
    this.pdfPath,
    this.imagePaths,
    this.videoPath,
  });
}
