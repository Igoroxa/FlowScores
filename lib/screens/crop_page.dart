import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/piece.dart';

class CropPage extends StatefulWidget {
  final Piece piece;
  final int pageIndex;
  const CropPage({super.key, required this.piece, required this.pageIndex});

  @override
  State<CropPage> createState() => _CropPageState();
}

class _CropPageState extends State<CropPage> {
  late GlobalKey _imageKey;
  late String _backupPath;
  late File _backupFile;
  late bool _backupExists;
  bool _initialized = false;
  double _left = 0;
  double _top = 0;
  double _right = 0;
  double _bottom = 0;
  double _imageDisplayWidth = 0;
  double _imageDisplayHeight = 0;

  @override
  void initState() {
    super.initState();
    _imageKey = GlobalKey();
    // Determine backup file path for this image
    String origPath = widget.piece.imagePaths![widget.pageIndex];
    int dotIndex = origPath.lastIndexOf('.');
    if (dotIndex != -1) {
      _backupPath = '${origPath.substring(0, dotIndex)}_original${origPath.substring(dotIndex)}';
    } else {
      _backupPath = '${origPath}_original';
    }
    _backupFile = File(_backupPath);
    _backupExists = _backupFile.existsSync();
  }

  // Initialize the crop rectangle (called after image is laid out)
  void _initCropRect() {
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null) {
      final displayWidth = renderBox.size.width;
      final displayHeight = renderBox.size.height;
      setState(() {
        // Set default crop selection (10% margin on each side)
        _left = displayWidth * 0.1;
        _top = displayHeight * 0.1;
        _right = displayWidth * 0.9;
        _bottom = displayHeight * 0.9;
        // If the image has an original backup (meaning it was previously cropped),
        // default to selecting the entire current image.
        if (_backupExists) {
          _left = 0;
          _top = 0;
          _right = displayWidth;
          _bottom = displayHeight;
        }
        _imageDisplayWidth = displayWidth;
        _imageDisplayHeight = displayHeight;
        _initialized = true;
      });
    }
  }

  Future<void> _restoreOriginal() async {
    if (_backupExists) {
      // Restore original image from backup file
      String origPath = widget.piece.imagePaths![widget.pageIndex];
      try {
        await _backupFile.rename(origPath);
      } catch (e) {
        // If rename fails (e.g., different file system), try copying
        try {
          await _backupFile.copy(origPath);
          await _backupFile.delete();
        } catch (copyError) {
          debugPrint('Failed to restore original image: $copyError');
          return;
        }
      }
      // Clear image cache so the original image will be reloaded
      imageCache.clear();
      imageCache.clearLiveImages();
      // Reset state to show the original image and reset selection
      setState(() {
        _imageKey = GlobalKey();  // new key to force image widget refresh
        _backupExists = false;
        _initialized = false;
      });
      // Reinitialize crop rectangle after the image is updated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _initCropRect();
      });
    }
  }

  Future<void> _applyCrop() async {
    String origPath = widget.piece.imagePaths![widget.pageIndex];
    // Ensure we have a backup of the original image (only once)
    if (!_backupExists) {
      try {
        await File(origPath).copy(_backupPath);
        _backupExists = true;
      } catch (e) {
        debugPrint('Could not backup original image: $e');
        return;
      }
    }
    // Load the image bytes and decode
    Uint8List imageBytes = await File(origPath).readAsBytes();
    img.Image? originalImage = img.decodeImage(imageBytes);
    if (originalImage == null) {
      debugPrint('Image decoding failed');
      return;
    }
    // Calculate crop area in original image coordinates
    double scaleX = originalImage.width / _imageDisplayWidth;
    double scaleY = originalImage.height / _imageDisplayHeight;
    int cropX = (_left * scaleX).round();
    int cropY = (_top * scaleY).round();
    int cropW = ((_right - _left) * scaleX).round();
    int cropH = ((_bottom - _top) * scaleY).round();
    // Clamp values to image bounds
    if (cropX < 0) cropX = 0;
    if (cropY < 0) cropY = 0;
    if (cropX + cropW > originalImage.width) {
      cropW = originalImage.width - cropX;
    }
    if (cropY + cropH > originalImage.height) {
      cropH = originalImage.height - cropY;
    }
    if (cropW <= 0 || cropH <= 0) {
      debugPrint('Invalid crop dimensions');
      return;
    }
    // Perform the crop operation
    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );
    // Save the cropped image back to the original file path
    try {
      if (origPath.toLowerCase().endsWith('.png')) {
        await File(origPath).writeAsBytes(img.encodePng(croppedImage));
      } else if (origPath.toLowerCase().endsWith('.jpg') || origPath.toLowerCase().endsWith('.jpeg')) {
        await File(origPath).writeAsBytes(img.encodeJpg(croppedImage));
      } else {
        // Default to PNG if file extension is not recognized
        await File(origPath).writeAsBytes(img.encodePng(croppedImage));
      }
    } catch (e) {
      debugPrint('Failed to save cropped image: $e');
    }
    // Clear image cache so the updated image will be loaded next time
    imageCache.clear();
    imageCache.clearLiveImages();
    // Return to the previous screen with the updated piece
    Navigator.pop(context, widget.piece);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Set up crop rect after the first frame (when image is rendered)
    if (!_initialized) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_initialized) {
          _initCropRect();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Crop Page',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_backupExists)
            IconButton(
              icon: const Icon(Icons.undo, color: Colors.black),
              onPressed: _restoreOriginal,
              tooltip: 'Undo Crop',
            ),
          IconButton(
            icon: const Icon(Icons.check, color: Colors.black),
            onPressed: _applyCrop,
            tooltip: 'Apply Crop',
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Stack(
            children: [
              // The image (sheet page) to crop
              Image.file(
                File(widget.piece.imagePaths![widget.pageIndex]),
                key: _imageKey,
                width: MediaQuery.of(context).size.width,
                fit: BoxFit.fitWidth,
              ),
              // Overlay and crop handles (only show once initialized)
              if (_initialized) ...[
                // Top overlay (above crop area)
                Positioned(
                  left: 0,
                  top: 0,
                  width: _imageDisplayWidth,
                  height: _top,
                  child: Container(color: Colors.black54),
                ),
                // Bottom overlay (below crop area)
                Positioned(
                  left: 0,
                  top: _bottom,
                  width: _imageDisplayWidth,
                  height: _imageDisplayHeight - _bottom,
                  child: Container(color: Colors.black54),
                ),
                // Left overlay
                Positioned(
                  left: 0,
                  top: _top,
                  width: _left,
                  height: _bottom - _top,
                  child: Container(color: Colors.black54),
                ),
                // Right overlay
                Positioned(
                  left: _right,
                  top: _top,
                  width: _imageDisplayWidth - _right,
                  height: _bottom - _top,
                  child: Container(color: Colors.black54),
                ),
                // Crop area border
                Positioned(
                  left: _left,
                  top: _top,
                  width: _right - _left,
                  height: _bottom - _top,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2),
                    ),
                  ),
                ),
                // Top-left corner handle
                Positioned(
                  left: _left,
                  top: _top,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _left += details.delta.dx;
                        _top += details.delta.dy;
                        if (_left < 0) _left = 0;
                        if (_top < 0) _top = 0;
                        if (_left > _right - 20) _left = _right - 20;
                        if (_top > _bottom - 20) _top = _bottom - 20;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ),
                // Top-right corner handle
                Positioned(
                  left: _right - 20,
                  top: _top,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _right += details.delta.dx;
                        _top += details.delta.dy;
                        if (_right > _imageDisplayWidth) _right = _imageDisplayWidth;
                        if (_top < 0) _top = 0;
                        if (_right < _left + 20) _right = _left + 20;
                        if (_top > _bottom - 20) _top = _bottom - 20;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ),
                // Bottom-left corner handle
                Positioned(
                  left: _left,
                  top: _bottom - 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _left += details.delta.dx;
                        _bottom += details.delta.dy;
                        if (_left < 0) _left = 0;
                        if (_bottom > _imageDisplayHeight) _bottom = _imageDisplayHeight;
                        if (_left > _right - 20) _left = _right - 20;
                        if (_bottom < _top + 20) _bottom = _top + 20;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ),
                // Bottom-right corner handle
                Positioned(
                  left: _right - 20,
                  top: _bottom - 20,
                  child: GestureDetector(
                    onPanUpdate: (details) {
                      setState(() {
                        _right += details.delta.dx;
                        _bottom += details.delta.dy;
                        if (_right > _imageDisplayWidth) _right = _imageDisplayWidth;
                        if (_bottom > _imageDisplayHeight) _bottom = _imageDisplayHeight;
                        if (_right < _left + 20) _right = _left + 20;
                        if (_bottom < _top + 20) _bottom = _top + 20;
                      });
                    },
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
