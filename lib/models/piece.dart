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

  Piece({
    required this.name,
    this.composer,
    required this.difficulty,
    required this.progress,
    required this.type,
    this.pdfPath,
    this.imagePaths,
  });

  // (Optional) You could add serialization methods here if saving/loading to storage.
}
