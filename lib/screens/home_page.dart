// lib/screens/home_page.dart
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/piece.dart';
import 'creation_page.dart';
import 'piece_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final List<Piece> _pieces = [];  // list of pieces in the portfolio

  final ImagePicker _imagePicker = ImagePicker();

  // Helper: open file picker for PDF
  Future<void> _pickPdfAndAdd() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result != null && result.files.isNotEmpty) {
      String pdfPath = result.files.single.path!; 
      // Navigate to creation page with the selected PDF
      Piece? newPiece = await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CreationPage(filePath: pdfPath, fileType: PieceType.pdf),
      ));
      if (newPiece != null) {
        setState(() {
          _pieces.add(newPiece);
        });
      }
    }
  }

  // Helper: use camera to scan and add an image piece
  Future<void> _scanImageAndAdd() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      String imagePath = photo.path;
      // Navigate to creation page with the captured image
      Piece? newPiece = await Navigator.push(context, MaterialPageRoute(
        builder: (_) => CreationPage(filePath: imagePath, fileType: PieceType.image),
      ));
      if (newPiece != null) {
        setState(() {
          _pieces.add(newPiece);
        });
      }
    }
  }

  // Show options (PDF or Scan) when the + button is pressed
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.file_present),
                title: const Text('Upload PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _pickPdfAndAdd();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Scan Papers'),
                onTap: () {
                  Navigator.pop(context);
                  _scanImageAndAdd();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPieces = _pieces.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowScores'),
      ),
      body: hasPieces 
        ? _buildPortfolioList() 
        : _buildFirstPiecePrompt(),
      floatingActionButton: hasPieces 
        ? FloatingActionButton(
            onPressed: _showAddOptions,
            tooltip: 'Add Piece',
            child: const Icon(Icons.add),
          )
        : null,
      // Place FAB on bottom-left if present
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }

  // Widget for initial state (no pieces): prompts to add first piece
  Widget _buildFirstPiecePrompt() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Add your First Piece',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.file_present),
            label: const Text('Upload PDF'),
            onPressed: _pickPdfAndAdd,
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Scan Papers'),
            onPressed: _scanImageAndAdd,
          ),
        ],
      ),
    );
  }

  // Widget for portfolio list when pieces have been added
  Widget _buildPortfolioList() {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: _pieces.length,
      itemBuilder: (context, index) {
        Piece piece = _pieces[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          child: ListTile(
            title: Text(piece.name),
            subtitle: Text('${piece.difficulty} • ${piece.progress}'),
            onTap: () async {
              // Open the piece view page. After returning, refresh to reflect any edits.
              await Navigator.push(context, MaterialPageRoute(
                builder: (_) => PiecePage(piece: piece),
              ));
              setState(() {}); // refresh list (in case piece was edited)
            },
            trailing: Icon(piece.type == PieceType.pdf ? Icons.picture_as_pdf : Icons.image),
          ),
        );
      },
    );
  }
}
