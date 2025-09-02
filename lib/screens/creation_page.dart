// lib/screens/creation_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../models/piece.dart';

class CreationPage extends StatefulWidget {
  final Piece? piece;        // existing piece to edit, or null if creating new
  final PieceType? fileType; // required if creating new
  final String? filePath;    // required if creating new (path of initial PDF/image)

  CreationPage({Key? key, this.piece, this.fileType, this.filePath}) : super(key: key) {
    // Ensure correct usage: either editing a piece, or creating with file info
    assert((piece != null && fileType == null && filePath == null) 
        || (piece == null && fileType != null && filePath != null),
      'Provide either an existing piece to edit, or fileType and filePath for a new piece');
  }

  @override
  State<CreationPage> createState() => _CreationPageState();
}

class _CreationPageState extends State<CreationPage> {
  // Text controllers for name and composer
  late TextEditingController _nameController;
  late TextEditingController _composerController;
  // Dropdown selections
  String _selectedDifficulty = 'Beginner';
  String _selectedProgress = 'Not Started';

  late PieceType _type;
  late String? _pdfPath;
  late String? _imagePath;
  String? _videoPath;

  @override
  void initState() {
    super.initState();
    if (widget.piece != null) {
      // Editing an existing piece – load its data
      Piece existing = widget.piece!;
      _nameController = TextEditingController(text: existing.name);
      _composerController = TextEditingController(text: existing.composer ?? '');
      _selectedDifficulty = existing.difficulty;
      _selectedProgress = existing.progress;
      _type = existing.type;
      if (_type == PieceType.pdf) {
        _pdfPath = existing.pdfPath;
        _imagePath = null;
      } else {
        _pdfPath = null;
        // Use first image path as preview (if multiple images are stored)
        _imagePath = (existing.imagePaths != null && existing.imagePaths!.isNotEmpty) 
                      ? existing.imagePaths!.first 
                      : null;
      }
      _videoPath = existing.videoPath;
    } else {
      // Creating a new piece – initialize with provided file info
      _nameController = TextEditingController();
      _composerController = TextEditingController();
      _type = widget.fileType!;
      if (_type == PieceType.pdf) {
        _pdfPath = widget.filePath;
        _imagePath = null;
      } else {
        _pdfPath = null;
        _imagePath = widget.filePath;
      }
      _videoPath = null;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  // Helper to pick a video file for performance
  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.isNotEmpty) {
      String videoPath = result.files.single.path!;
      setState(() {
        _videoPath = videoPath;
      });
    }
  }

  void _onCreateOrSave() {
    final String name = _nameController.text.trim();
    final String composer = _composerController.text.trim();
    if (name.isEmpty) {
      // Name is required
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the piece.'))
      );
      return;
    }
    if (widget.piece != null) {
      // Save changes to existing piece
      widget.piece!.name = name;
      widget.piece!.composer = composer.isEmpty ? null : composer;
      widget.piece!.difficulty = _selectedDifficulty;
      widget.piece!.progress = _selectedProgress;
      widget.piece!.videoPath = _videoPath;  // update video path
      // Note: type and file paths are not changed on edit
      Navigator.pop(context, widget.piece);
    } else {
      // Create a new Piece object with provided info
      Piece newPiece = Piece(
        name: name,
        composer: composer.isEmpty ? null : composer,
        difficulty: _selectedDifficulty,
        progress: _selectedProgress,
        type: _type,
        pdfPath: _type == PieceType.pdf ? _pdfPath : null,
        imagePaths: _type == PieceType.image ? [_imagePath!] : null,
        videoPath: _videoPath,
      );
      Navigator.pop(context, newPiece);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.piece != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Piece' : 'Add Piece'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Flex(
            direction: Axis.horizontal, // layout horizontally if space allows
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // File preview section
              if (_type == PieceType.pdf)
                Container(
                  width: 100,
                  height: 140,
                  alignment: Alignment.center,
                  color: Colors.grey[300],
                  child: Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey[700]),
                )
              else if (_imagePath != null)
                Image.file(
                  File(_imagePath!),
                  width: 100,
                  height: 140,
                  fit: BoxFit.cover,
                ),
              const SizedBox(width: 20),
              // Form fields section
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Piece name
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Piece Name *'),
                    ),
                    // Composer name (optional)
                    TextField(
                      controller: _composerController,
                      decoration: const InputDecoration(labelText: 'Composer (optional)'),
                    ),
                    const SizedBox(height: 10),
                    // Difficulty dropdown
                    DropdownButton<String>(
                      value: _selectedDifficulty,
                      items: ['Beginner', 'Intermediate', 'Advanced']
                          .map((level) => DropdownMenuItem(value: level, child: Text('Difficulty: $level')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedDifficulty = val;
                          });
                        }
                      },
                    ),
                    // Progress dropdown
                    DropdownButton<String>(
                      value: _selectedProgress,
                      items: ['Not Started', 'Learning', 'Practicing', 'Confident', 'Polished', 'Mastered']
                          .map((status) => DropdownMenuItem(value: status, child: Text('Progress: $status')))
                          .toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedProgress = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    // Performance Video selection
                    if (_videoPath != null) 
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Video: ${Uri.file(_videoPath!).pathSegments.last}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _pickVideo,
                            child: const Text('Change'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _videoPath = null;
                              });
                            },
                            child: const Text('Remove'),
                          ),
                        ],
                      )
                    else
                      OutlinedButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text('Add Performance Video'),
                        onPressed: _pickVideo,
                      ),
                    const SizedBox(height: 20),
                    // Create/Save button
                    Center(
                      child: ElevatedButton(
                        onPressed: _onCreateOrSave,
                        child: Text(isEdit ? 'Save Changes' : 'Create'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
