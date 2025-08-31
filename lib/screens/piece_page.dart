// lib/screens/piece_page.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_cached_pdfview/flutter_cached_pdfview.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:photo_view/photo_view.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/piece.dart';
import 'creation_page.dart';

class PiecePage extends StatefulWidget {
  final Piece piece;
  const PiecePage({Key? key, required this.piece}) : super(key: key);

  @override
  State<PiecePage> createState() => _PiecePageState();
}

class _PiecePageState extends State<PiecePage> {
  late Piece _piece;
  late AudioPlayer _audioPlayer;
  Timer? _metronomeTimer;
  bool _isPlayingMetronome = false;
  double _bpm = 60.0;  // use double for slider value

  @override
  void initState() {
    super.initState();
    _piece = widget.piece;
    _audioPlayer = AudioPlayer();
    // Ensure the audio player stops any sound on complete (no looping)
    // (By default, playing an asset will play it once. We will manually loop via Timer.)
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  // Toggle the metronome on/off
  void _toggleMetronome() {
    if (_isPlayingMetronome) {
      // Stop the metronome
      _metronomeTimer?.cancel();
      _audioPlayer.stop();
      setState(() {
        _isPlayingMetronome = false;
      });
    } else {
      if (_bpm < 1) {
        // If BPM is 0 (or very low), do nothing
        return;
      }
      // Calculate interval in milliseconds for the given BPM
      int intervalMs = (60000 / _bpm).floor();
      _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
        _audioPlayer.play(AssetSource('click.wav.mp3'));  // play tick sound:contentReference[oaicite:7]{index=7}
      });
      setState(() {
        _isPlayingMetronome = true;
      });
    }
  }

  // Open the edit page
  Future<void> _editPiece() async {
    Piece? updatedPiece = await Navigator.push(context, MaterialPageRoute(
      builder: (_) => CreationPage(piece: _piece),
    ));
    if (updatedPiece != null) {
      setState(() {
        // Update local reference (the list in HomePage already has the same object updated)
        _piece = updatedPiece;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Display piece name (and optionally composer) in the AppBar
    String title = _piece.name;
    if (_piece.composer != null && _piece.composer!.isNotEmpty) {
      title += ' — ${_piece.composer}';
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Piece',
            onPressed: _editPiece,
          ),
        ],
      ),
      body: Column(
        children: [
          // Expanded viewer for PDF or images
          Expanded(
            child: _piece.type == PieceType.pdf
                ? PDF().fromPath(_piece.pdfPath!)  // PDF viewer widget:contentReference[oaicite:8]{index=8}
                : PhotoViewGallery.builder(
                    itemCount: _piece.imagePaths!.length,
                    builder: (context, index) {
                      final imagePath = _piece.imagePaths![index];
                      return PhotoViewGalleryPageOptions(
                        imageProvider: FileImage(File(imagePath)),
                        initialScale: PhotoViewComputedScale.contained,
                        minScale: PhotoViewComputedScale.contained,
                        maxScale: PhotoViewComputedScale.covered * 2,
                      );
                    },
                    scrollPhysics: const BouncingScrollPhysics(),
                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                  ),
          ),
          // Metronome controls
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Column(
              children: [
                // BPM slider and display
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
                          if (_isPlayingMetronome) {
                            // If metronome is running, restart with new tempo
                            _metronomeTimer?.cancel();
                            if (value < 1) {
                              // treat BPM 0 as stop
                              _audioPlayer.stop();
                              _isPlayingMetronome = false;
                            } else {
                              int intervalMs = (60000 / value).floor();
                              _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (timer) {
                                _audioPlayer.play(AssetSource('click.wav.mp3'));
                              });
                            }
                          }
                        },
                      ),
                    ),
                    Text('${_bpm.round()} BPM'),
                  ],
                ),
                // Play/Pause button
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleMetronome,
                      icon: Icon(_isPlayingMetronome ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlayingMetronome ? 'Pause' : 'Play'),
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
