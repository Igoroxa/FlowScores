// lib/screens/creation_page.dart
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_image_renderer/pdf_image_renderer.dart';

import '../models/piece.dart';
import '../services/onboarding_service.dart';
import '../widgets/onboarding_popups.dart';

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
  bool _isInCameraMode = false;  // Track if user is capturing multiple images
  bool _isInGalleryMode = false; // Track if user is selecting multiple images from gallery

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
      // Show first work creation popup if needed (only for new pieces, not editing)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkAndShowFirstWorkCreationPopup();
      });
    }
  }

  Future<void> _checkAndShowFirstWorkCreationPopup() async {
    final shouldShow = await OnboardingService.shouldShowFirstWorkCreation();
    if (shouldShow && mounted) {
      OnboardingPopups.showFirstWorkCreationPopup(context);
      await OnboardingService.markFirstWorkCreationShown();
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
    FocusScope.of(context).unfocus();
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
        _isInGalleryMode = true;  // Enter gallery mode for multiple selections
      });
    }
  }

  void _startGalleryMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isInGalleryMode = true;
      _type = PieceType.image;
      _imagePaths.clear();
      _pdfPath = null;
    });
  }

  void _finishGalleryMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isInGalleryMode = false;
    });
  }

  Future<void> _captureImage() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      setState(() {
        _type = PieceType.image;
        _imagePaths.add(photo.path);
        _pdfPath = null;
        _isInCameraMode = true;  // Enter camera mode for multiple captures
      });
    }
  }

  void _startCameraMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isInCameraMode = true;
      _type = PieceType.image;
      _imagePaths.clear();
      _pdfPath = null;
    });
  }

  void _finishCameraMode() {
    FocusScope.of(context).unfocus();
    setState(() {
      _isInCameraMode = false;
    });
  }

  void _removeImage(int index) {
    FocusScope.of(context).unfocus();
    setState(() {
      _imagePaths.removeAt(index);
      if (_imagePaths.isEmpty) {
        _isInCameraMode = false;
        _isInGalleryMode = false;
        _type = null;
      }
    });
  }

  Future<void> _pickVideo() async {
    FocusScope.of(context).unfocus();
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
        const SnackBar(content: Text('Please enter a title for your Work.')),
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
      FocusScope.of(context).unfocus();
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

    FocusScope.of(context).unfocus();
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
      if (_imagePaths.length == 1) {
        return _imagePaths.first.split('/').last;
      } else {
        return '${_imagePaths.length} images';
      }
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
        color: Colors.white,
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
          onPressed: () {
            // Dismiss keyboard before navigating back
            FocusScope.of(context).unfocus();
            Navigator.pop(context);
          },
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
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: _buildFormFields(isEdit),
            ),
            if (_isConvertingPdf)
              Container(
                color: Colors.black38,
                child: const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
                  ),
                ),
              ),
          ],
        ),
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
              cursorColor: Colors.grey,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                hintText: 'Enter Here',
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
                          FocusScope.of(context).unfocus();
                          _nameController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
              },
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
              cursorColor: Colors.grey,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                hintText: 'Enter Here',
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
                          FocusScope.of(context).unfocus();
                          _composerController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (value) => setState(() {}),
              onSubmitted: (value) {
                FocusScope.of(context).unfocus();
              },
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
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _selectedDifficulty = difficulty);
                  },
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
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _showUploadOptions();
                },
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
            if (!_isInCameraMode && !_isInGalleryMode) ...[
              Row(
                children: [
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.picture_as_pdf,
                      label: 'PDF',
                      onPressed: _pickPdf,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.camera_alt,
                      label: 'Camera',
                      onPressed: _startCameraMode,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.photo_library,
                      label: 'Gallery',
                      onPressed: _startGalleryMode,
                    ),
                  ),
                ],
              ),
            ] else if (_isInCameraMode) ...[
              // Camera mode - show capture and done buttons
              Row(
                children: [
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.camera_alt,
                      label: 'Take Photo',
                      onPressed: _captureImage,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.check,
                      label: 'Done',
                      onPressed: _finishCameraMode,
                    ),
                  ),
                ],
              ),
            ] else if (_isInGalleryMode) ...[
              // Gallery mode - show select more and done buttons
              Row(
                children: [
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.photo_library,
                      label: 'Select More',
                      onPressed: _pickImagesFromGallery,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildUploadOptionButton(
                      icon: Icons.check,
                      label: 'Done',
                      onPressed: _finishGalleryMode,
                    ),
                  ),
                ],
              ),
            ],
            
            // Show uploaded file info
            if (_type != null) ...[
              const SizedBox(height: 16),
              if (_type == PieceType.pdf) ...[
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
                            _isInCameraMode = false;
                            _isInGalleryMode = false;
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
              ] else if (_type == PieceType.image && _imagePaths.isNotEmpty) ...[
                // Show image previews
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _isInCameraMode 
                                ? 'Captured Images (${_imagePaths.length})'
                                : _isInGalleryMode
                                    ? 'Selected Images (${_imagePaths.length})'
                                    : 'Images (${_imagePaths.length})',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          if (!_isInCameraMode && !_isInGalleryMode)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _type = null;
                                  _imagePaths.clear();
                                  _isInCameraMode = false;
                                  _isInGalleryMode = false;
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
                      const SizedBox(height: 12),
                      // Image grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                        itemCount: _imagePaths.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_imagePaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
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
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _pickVideo();
                },
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
            onPressed: _isConvertingPdf ? null : () {
              FocusScope.of(context).unfocus();
              _onSave();
            },
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
