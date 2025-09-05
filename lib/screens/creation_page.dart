// lib/screens/creation_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

import '../models/piece.dart';

class CreationPage extends StatefulWidget {
  final Piece? piece; // null => creating new; non-null => editing
  const CreationPage({Key? key, this.piece}) : super(key: key);

  @override
  State<CreationPage> createState() => _CreationPageState();
}

class _CreationPageState extends State<CreationPage> {
  late final TextEditingController _nameController;
  late final TextEditingController _composerController;

  String _selectedDifficulty = 'Beginner';
  String _selectedProgress = 'Not Started';

  PieceType? _type;              // pdf or image after selection
  String? _pdfPath;              // when a PDF is chosen
  List<String> _imagePaths = []; // when one or more images are chosen
  String? _videoPath;

  bool _isConvertingPdf = false;

  final ImagePicker _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.piece != null) {
      final p = widget.piece!;
      _nameController = TextEditingController(text: p.name);
      _composerController = TextEditingController(text: p.composer ?? '');
      _selectedDifficulty = p.difficulty;
      _selectedProgress = p.progress;
      _type = p.type;
      _pdfPath = p.pdfPath;
      _imagePaths = p.imagePaths ?? [];
      _videoPath = p.videoPath;
    } else {
      _nameController = TextEditingController();
      _composerController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _composerController.dispose();
    super.dispose();
  }

  // ---------- Pickers ----------

  Future<void> _pickPdf() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _type = PieceType.pdf;
        _pdfPath = res.files.single.path!;
        _imagePaths.clear();
      });
    }
  }

  Future<void> _pickImagesFromGallery() async {
    final FilePickerResult? res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (res != null && res.files.isNotEmpty) {
      setState(() {
        _type = PieceType.image;
        _imagePaths = res.files.map((f) => f.path!).toList();
        _pdfPath = null;
      });
    }
  }

  Future<void> _captureImage() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _type = PieceType.image;
        _imagePaths = [photo.path];
        _pdfPath = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final FilePickerResult? res =
        await FilePicker.platform.pickFiles(type: FileType.video);
    if (res != null && res.files.isNotEmpty) {
      setState(() => _videoPath = res.files.single.path!);
    }
  }

  // ---------- Save / Create ----------

  Future<void> _onSave() async {
    final name = _nameController.text.trim();
    final composer = _composerController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title for the piece.')),
      );
      return;
    }
    if (_type == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload sheet music (PDF or images).')),
      );
      return;
    }

    // Editing existing piece
    if (widget.piece != null) {
      final p = widget.piece!;
      p.name = name;
      p.composer = composer.isEmpty ? null : composer;
      p.difficulty = _selectedDifficulty;
      p.progress = _selectedProgress;
      p.videoPath = _videoPath;
      // (Changing sheet files on edit is intentionally not supported.)
      Navigator.pop(context, p);
      return;
    }

    // Creating a new piece
    List<String> imagePaths = _imagePaths;
    PieceType finalType = _type!;
    String? pdfPath = _pdfPath;

    // Convert PDF to images (if a PDF was selected)
    if (_type == PieceType.pdf && _pdfPath != null) {
      setState(() => _isConvertingPdf = true);
      try {
        final pdf = PdfImageRenderer(path: _pdfPath!);

        await pdf.open();
        final int pageCount = await pdf.getPageCount();
        final outDir = await getApplicationDocumentsDirectory();

        final generated = <String>[];
        for (int i = 0; i < pageCount; i++) {
          await pdf.openPage(pageIndex: i);
          final size = await pdf.getPageSize(pageIndex: i);

          final Uint8List? bytes = await pdf.renderPage(
            pageIndex: i,
            x: 0,
            y: 0,
            width: size.width,
            height: size.height,
            scale: 1,
            background: Colors.white,
          );

          if (bytes == null) {
            // skip page if render failed
            await pdf.closePage(pageIndex: i);
            continue;
          }

          final filename =
              '${_fileNameWithoutExt(_pdfPath!)}_page${i + 1}.png';
          final path = '${outDir.path}/$filename';
          await File(path).writeAsBytes(bytes, flush: true);

          generated.add(path);
          await pdf.closePage(pageIndex: i);
        }
        await pdf.close();

        imagePaths = generated;
        finalType = PieceType.image; // from now on we display images
      } catch (e) {
        debugPrint('PDF conversion error: $e');
      } finally {
        setState(() => _isConvertingPdf = false);
      }
    }

    final newPiece = Piece(
      name: name,
      composer: composer.isEmpty ? null : composer,
      difficulty: _selectedDifficulty,
      progress: _selectedProgress,
      type: finalType,
      pdfPath: pdfPath,
      imagePaths: imagePaths,
      videoPath: _videoPath,
    );

    Navigator.pop(context, newPiece);
  }

  String _fileNameWithoutExt(String path) {
    final file = path.split('/').last;
    final dot = file.lastIndexOf('.');
    return dot == -1 ? file : file.substring(0, dot);
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.piece != null; // pass into form section
    final bool isWide = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? 'Edit Piece' : 'Add New Work')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 120,
                        height: 160,
                        color: Colors.grey[300],
                        child: _buildPreview(),
                      ),
                      const SizedBox(width: 20),
                      Expanded(child: _buildFormFields(isEdit)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 120,
                        height: 160,
                        child: Container(
                          color: Colors.grey[300],
                          child: _buildPreview(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildFormFields(isEdit),
                    ],
                  ),
          ),
          if (_isConvertingPdf)
            Container(
              color: Colors.black38,
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    if (_type == null) {
      return Center(child: Text('No file', style: TextStyle(color: Colors.grey[700])));
    }
    if (_type == PieceType.pdf) {
      return const Icon(Icons.picture_as_pdf, size: 80, color: Colors.grey);
    }
    if (_type == PieceType.image && _imagePaths.isNotEmpty) {
      return Image.file(File(_imagePaths.first), fit: BoxFit.cover);
    }
    return Center(child: Text('No file', style: TextStyle(color: Colors.grey[700])));
  }

  Widget _buildFormFields(bool isEdit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _nameController,
          decoration: const InputDecoration(labelText: 'Title *'),
        ),
        TextField(
          controller: _composerController,
          decoration: const InputDecoration(labelText: 'Composer (optional)'),
        ),
        const SizedBox(height: 10),

        DropdownButton<String>(
          value: _selectedDifficulty,
          items: const ['Beginner', 'Intermediate', 'Advanced']
              .map((e) => DropdownMenuItem(value: e, child: Text('Difficulty: $e')))
              .toList(),
          onChanged: (v) => setState(() => _selectedDifficulty = v!),
        ),
        DropdownButton<String>(
          value: _selectedProgress,
          items: const [
            'Not Started',
            'Learning',
            'Practicing',
            'Confident',
            'Polished',
            'Mastered'
          ].map((e) => DropdownMenuItem(value: e, child: Text('Progress: $e'))).toList(),
          onChanged: (v) => setState(() => _selectedProgress = v!),
        ),
        const SizedBox(height: 10),

        // Sheet upload section
        if (_type == null) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.file_present),
            label: const Text('Upload PDF'),
            onPressed: _pickPdf,
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Upload Images'),
                  onPressed: _pickImagesFromGallery,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Scan (Camera)'),
                  onPressed: _captureImage,
                ),
              ),
            ],
          ),
        ] else ...[
          if (_type == PieceType.pdf && _pdfPath != null)
            Text('Selected PDF: ${_pdfPath!.split('/').last}',
                overflow: TextOverflow.ellipsis),
          if (_type == PieceType.image && _imagePaths.isNotEmpty)
            Text(
              _imagePaths.length == 1
                  ? 'Selected image: ${_imagePaths.first.split('/').last}'
                  : 'Selected images: ${_imagePaths.length} files',
              overflow: TextOverflow.ellipsis,
            ),
          Row(
            children: [
              TextButton(
                onPressed: () => _type == PieceType.pdf ? _pickPdf() : _pickImagesFromGallery(),
                child: const Text('Change'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _type = null;
                    _pdfPath = null;
                    _imagePaths.clear();
                  });
                },
                child: const Text('Remove'),
              ),
            ],
          )
        ],

        const SizedBox(height: 10),

        // Performance video
        if (_videoPath != null)
          Row(
            children: [
              Expanded(
                child: Text('Video: ${_videoPath!.split('/').last}',
                    overflow: TextOverflow.ellipsis),
              ),
              TextButton(onPressed: _pickVideo, child: const Text('Change')),
              TextButton(
                onPressed: () => setState(() => _videoPath = null),
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
        Center(
          child: ElevatedButton(
            onPressed: _isConvertingPdf ? null : _onSave,
            child: Text(isEdit ? 'Save Changes' : 'Create'),
          ),
        ),
      ],
    );
  }
}
