// lib/screens/piece_page.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;  // for Image
import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
// import 'package:photo_view/photo_view_gallery.dart';
// import 'package:photo_view/photo_view.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
// import 'package:pdf_render/pdf_render.dart';
// import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../models/piece.dart';
import 'creation_page.dart';
import 'video_page.dart';  // new screen for video playback

class PiecePage extends StatefulWidget {
  final Piece piece;
  const PiecePage({Key? key, required this.piece}) : super(key: key);

  @override
  State<PiecePage> createState() => _PiecePageState();
}

class _PiecePageState extends State<PiecePage> {
  late Piece _piece;
  // Use multiple audio players for metronome ticks (allow overlapping sounds)
  final List<AudioPlayer> _players = [];
  int _playerIndex = 0;
  Timer? _metronomeTimer;
  bool _isPlayingMetronome = false;
  double _bpm = 60.0;  // BPM slider value

  // Auto-scroll (two-line view) state
  bool _twoLineMode = false;
  bool _isScrolling = false;
  double _scrollSpeed = 0.0;
  Timer? _scrollTimer;
  final ScrollController _scrollController = ScrollController();
  bool _loadingPages = false;            // true while PDF pages are being rendered
  List<ui.Image> _pageImages = [];      // rendered images of PDF pages for two-line mode

  @override
  void initState() {
    super.initState();
    _piece = widget.piece;
    // Initialize multiple AudioPlayers for the metronome sound
    for (int i = 0; i < 4; i++) {
      _players.add(AudioPlayer());
    }
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _scrollTimer?.cancel();
    // Dispose all audio players
    for (var player in _players) {
      player.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  // Toggle metronome on/off
  void _toggleMetronome() {
    if (_isPlayingMetronome) {
      // Stop metronome
      _metronomeTimer?.cancel();
      for (var player in _players) {
        player.stop();
      }
      setState(() {
        _isPlayingMetronome = false;
      });
    } else {
      if (_bpm < 1) return;  // do nothing if BPM is 0
      // Play tick on a regular interval (ms per beat)
      int intervalMs = (60000 / _bpm).floor();
      _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
        _players[_playerIndex].play(AssetSource('click.MP3'));
        _playerIndex = (_playerIndex + 1) % _players.length;
      });
      setState(() {
        _isPlayingMetronome = true;
      });
    }
  }

  // Toggle auto-scroll on/off (in two-line mode)
  void _toggleScroll() {
    if (_isScrolling) {
      // Pause scrolling
      _scrollTimer?.cancel();
      setState(() {
        _isScrolling = false;
      });
    } else {
      if (_bpm < 1) return;
      if (!_scrollController.hasClients) return;
      double maxDistance = _scrollController.position.maxScrollExtent;
      if (maxDistance <= 0) return;  // nothing to scroll
      // Calculate scroll speed (px per second) from BPM (assumes ~32 bars/page)
      int pagesCount = (_piece.type == PieceType.pdf)
          ? (_pageImages.isNotEmpty ? _pageImages.length : 1)
          : (_piece.imagePaths?.length ?? 1);
      double totalBars = 32.0 * pagesCount;
      double totalTimeSec = (totalBars * 60.0 * 4.0) / _bpm;  // 4 beats per bar assumed
      if (totalTimeSec <= 0) return;
      _scrollSpeed = maxDistance / totalTimeSec;
      // Start periodic scrolling
      _scrollTimer = Timer.periodic(Duration(milliseconds: 30), (timer) {
        if (!_scrollController.hasClients) return;
        double currentOffset = _scrollController.position.pixels;
        double newOffset = currentOffset + _scrollSpeed * 0.03;  // move per 30ms
        if (newOffset >= maxDistance) {
          // Reached bottom – stop scrolling
          _scrollController.jumpTo(maxDistance);
          _scrollTimer?.cancel();
          setState(() {
            _isScrolling = false;
          });
        } else {
          _scrollController.jumpTo(newOffset);
        }
      });
      setState(() {
        _isScrolling = true;
      });
    }
  }

  // Toggle two-line orientation mode on/off
  void _toggleOrientationMode() async {
    if (_twoLineMode) {
      // Exiting two-line mode
      if (_isScrolling) {
        _scrollTimer?.cancel();
        _isScrolling = false;
      }
      setState(() {
        _twoLineMode = false;
        _pageImages.clear();  // free memory if needed
      });
    } else {
      // Entering two-line mode
      setState(() {
        _twoLineMode = true;
        _loadingPages = true;
      });
      if (_piece.type == PieceType.pdf) {
        // For now, disable two-line mode for PDFs due to package compatibility issues
        setState(() {
          _loadingPages = false;
          _twoLineMode = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Two-line mode is temporarily disabled for PDFs'))
        );
      } else {
        // For image pieces, no extra loading needed
        _loadingPages = false;
      }
      _scrollController.jumpTo(0);  // start at top
      setState(() {});  // refresh UI
    }
  }

  // Pick a performance video file (for attaching in view mode)
  Future<void> _pickVideo() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result != null && result.files.isNotEmpty) {
      String videoPath = result.files.single.path!;
      setState(() {
        _piece.videoPath = videoPath;
      });
    }
  }

  // Open the performance video playback page
  void _playVideo() {
    if (_piece.videoPath != null) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => VideoPage(videoPath: _piece.videoPath!),
      ));
    }
  }

  // Open the edit piece page
  Future<void> _editPiece() async {
    Piece? updated = await Navigator.push(context,
      MaterialPageRoute(builder: (_) => CreationPage(piece: _piece))
    );
    if (updated != null) {
      setState(() {
        _piece = updated;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display piece title and composer in AppBar
    String title = _piece.name;
    if (_piece.composer != null && _piece.composer!.isNotEmpty) {
      title += ' — ${_piece.composer}';
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          // Orientation toggle button
          IconButton(
            icon: Icon(_twoLineMode ? Icons.fullscreen_exit : Icons.fullscreen),
            tooltip: _twoLineMode ? 'Normal View' : 'Two-Line View',
            onPressed: _toggleOrientationMode,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Piece',
            onPressed: _editPiece,
          ),
        ],
      ),
      body: Column(
        children: [
          // Viewer area (PDF/Images or two-line scroll view)
          Expanded(
            child: _twoLineMode
                ? (_loadingPages 
                    ? Center(child: CircularProgressIndicator())
                    : SingleChildScrollView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          children: [
                            if (_piece.type == PieceType.pdf)
                              for (ui.Image img in _pageImages)
                                SizedBox(
                                  width: MediaQuery.of(context).size.width,
                                  child: RawImage(image: img, fit: BoxFit.fitWidth),
                                )
                            else
                              for (String path in _piece.imagePaths ?? [])
                                Image.file(
                                  File(path),
                                  width: MediaQuery.of(context).size.width,
                                  fit: BoxFit.fitWidth,
                                ),
                          ],
                        ),
                      )
                  )
                : (_piece.type == PieceType.pdf
                    ? PDF().fromPath(_piece.pdfPath!)
                    : PageView.builder(
                        itemCount: _piece.imagePaths?.length ?? 0,
                        itemBuilder: (context, index) {
                          final imagePath = _piece.imagePaths![index];
                          return Container(
                            color: Colors.black,
                            child: Center(
                              child: Image.file(
                                File(imagePath),
                                fit: BoxFit.contain,
                              ),
                            ),
                          );
                        },
                      )
                  ),
          ),
          // Bottom controls: video, tempo, metronome, scroll
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              children: [
                // Performance video button (Upload or Play)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_piece.videoPath == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text('Upload Performance'),
                        onPressed: _pickVideo,
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('Play Performance'),
                        onPressed: _playVideo,
                      ),
                  ],
                ),
                const SizedBox(height: 8.0),
                // Tempo slider
                Row(
                  children: [
                    const Text('Tempo:'),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 500,
                        divisions: 500,
                        label: _bpm.round().toString(),
                        value: _bpm,
                        onChanged: (double value) {
                          setState(() {
                            _bpm = value;
                          });
                        },
                        onChangeEnd: (double value) {
                          // If metronome is running, update its tempo
                          if (_isPlayingMetronome) {
                            _metronomeTimer?.cancel();
                            if (value < 1) {
                              for (var player in _players) {
                                player.stop();
                              }
                              _isPlayingMetronome = false;
                            } else {
                              int intervalMs = (60000 / value).floor();
                              _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
                                _players[_playerIndex].play(AssetSource('click.MP3'));
                                _playerIndex = (_playerIndex + 1) % _players.length;
                              });
                            }
                          }
                          // If auto-scroll is running, update scroll speed
                          if (_isScrolling) {
                            if (value < 1) {
                              _scrollTimer?.cancel();
                              _isScrolling = false;
                            } else {
                              if (_scrollController.hasClients) {
                                double maxDistance = _scrollController.position.maxScrollExtent;
                                int pagesCount = (_piece.type == PieceType.pdf)
                                    ? (_pageImages.isNotEmpty ? _pageImages.length : 1)
                                    : (_piece.imagePaths?.length ?? 1);
                                double totalBars = 32.0 * pagesCount;
                                double totalTimeSec = (totalBars * 60.0 * 4.0) / value;
                                double newSpeed = totalTimeSec > 0 ? maxDistance / totalTimeSec : 0;
                                _scrollSpeed = newSpeed;
                              }
                            }
                          }
                        },
                      ),
                    ),
                    Text('${_bpm.round()} BPM'),
                  ],
                ),
                // Play/Pause buttons for metronome and scroll
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleMetronome,
                      icon: Icon(_isPlayingMetronome ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlayingMetronome ? 'Pause' : 'Play'),
                    ),
                    if (_twoLineMode)
                      ElevatedButton.icon(
                        onPressed: _toggleScroll,
                        icon: Icon(_isScrolling ? Icons.pause : Icons.play_arrow),
                        label: Text(_isScrolling ? 'Pause Scroll' : 'Scroll'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
