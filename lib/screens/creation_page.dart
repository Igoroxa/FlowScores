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

  String _getUploadedFileName() {
    if (_type == PieceType.pdf && _pdfPath != null) {
      return _pdfPath!.split('/').last;
    } else if (_type == PieceType.image && _imagePaths.isNotEmpty) {
      return _imagePaths.first.split('/').last;
    }
    return '';
  }

  Widget _buildUploadOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 1,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Choose Upload Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    onPressed: () {
                      Navigator.pop(context);
                      _pickPdf();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    onPressed: () {
                      Navigator.pop(context);
                      _captureImage();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.photo_library,
                    label: 'Gallery',
                    onPressed: () {
                      Navigator.pop(context);
                      _pickImagesFromGallery();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final bool isEdit = widget.piece != null;

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
          'Work Creation',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: _buildFormFields(isEdit),
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
        // Title Input Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                hintText: 'Input',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: _nameController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: () {
                          _nameController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Author Input Field
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Author',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _composerController,
              decoration: InputDecoration(
                hintText: 'Input',
                hintStyle: TextStyle(color: Colors.grey[400]),
                filled: true,
                fillColor: Colors.grey[100],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                suffixIcon: _composerController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.grey),
                        onPressed: () {
                          _composerController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Difficulty Selection
        Row(
          children: ['Beginner', 'Intermediate', 'Advanced'].map((difficulty) {
            final isSelected = _selectedDifficulty == difficulty;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                child: ElevatedButton(
                  onPressed: () => setState(() => _selectedDifficulty = difficulty),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isSelected ? Colors.black : Colors.grey[300]!,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    difficulty,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 32),

        // Upload Work Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Upload Work Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _showUploadOptions,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Work',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.upload, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            
            // Upload Options (PDF, Camera, Gallery)
            Row(
              children: [
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.star,
                    label: 'PDF',
                    onPressed: _pickPdf,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.star,
                    label: 'Camera',
                    onPressed: _captureImage,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildUploadOptionButton(
                    icon: Icons.star,
                    label: 'Gallery',
                    onPressed: _pickImagesFromGallery,
                  ),
                ),
              ],
            ),
            
            // Show uploaded file info
            if (_type != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Uploaded: ${_getUploadedFileName()}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _type = null;
                          _pdfPath = null;
                          _imagePaths.clear();
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 32),

        // Upload Performance Section
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Upload Performance Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _pickVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Upload Performance',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Icon(Icons.upload, size: 20),
                  ],
                ),
              ),
            ),
            
            // Show uploaded video info
            if (_videoPath != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Uploaded: ${_videoPath!.split('/').last}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _videoPath = null;
                        });
                      },
                      child: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 40),
        
        // Finish Creating Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _isConvertingPdf ? null : _onSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.2),
            ),
            child: Text(
              isEdit ? 'Save Changes' : 'Finish Creating',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
