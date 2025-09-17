import 'package:shared_preferences/shared_preferences.dart';
import '../models/piece.dart';

class PieceStorageService {
  static const String _piecesKey = 'saved_pieces';

  // Save pieces to local storage
  static Future<void> savePieces(List<Piece> pieces) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = Piece.piecesToJson(pieces);
      await prefs.setString(_piecesKey, jsonString);
    } catch (e) {
      print('Error saving pieces: $e');
    }
  }

  // Load pieces from local storage
  static Future<List<Piece>> loadPieces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_piecesKey);
      
      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }
      
      return Piece.piecesFromJson(jsonString);
    } catch (e) {
      print('Error loading pieces: $e');
      return [];
    }
  }

  // Clear all saved pieces
  static Future<void> clearPieces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_piecesKey);
    } catch (e) {
      print('Error clearing pieces: $e');
    }
  }
}
