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
  String? videoPath;  

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

  // Convert Piece to JSON
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'composer': composer,
      'difficulty': difficulty,
      'progress': progress,
      'type': type.name,
      'pdfPath': pdfPath,
      'imagePaths': imagePaths,
      'videoPath': videoPath,
    };
  }

  // Create Piece from JSON
  factory Piece.fromJson(Map<String, dynamic> json) {
    return Piece(
      name: json['name'] as String,
      composer: json['composer'] as String?,
      difficulty: json['difficulty'] as String,
      progress: json['progress'] as String,
      type: PieceType.values.firstWhere((e) => e.name == json['type']),
      pdfPath: json['pdfPath'] as String?,
      imagePaths: json['imagePaths'] != null ? List<String>.from(json['imagePaths']) : null,
      videoPath: json['videoPath'] as String?,
    );
  }

  // Convert list of pieces to JSON
  static String piecesToJson(List<Piece> pieces) {
    return jsonEncode(pieces.map((piece) => piece.toJson()).toList());
  }

  // Create list of pieces from JSON
  static List<Piece> piecesFromJson(String jsonString) {
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => Piece.fromJson(json as Map<String, dynamic>)).toList();
  }
}
