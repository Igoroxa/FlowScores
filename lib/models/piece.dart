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
  String? videoPath;  // path to an attached performance video file

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

  // (We could add toJson/fromJson here if persisting pieces, but for now it's just an in-memory model.)
}
