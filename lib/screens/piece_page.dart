import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart'; // <-- fixes FilePickerResult undefined

import '../models/piece.dart';
import 'creation_page.dart';
import 'video_page.dart';

class PiecePage extends StatefulWidget {
  final Piece piece;
  const PiecePage({Key? key, required this.piece}) : super(key: key);

  @override
  State<PiecePage> createState() => _PiecePageState();
}

class _PiecePageState extends State<PiecePage> {
  late Piece _piece;

  // Metronome
  final List<AudioPlayer> _players = List.generate(4, (_) => AudioPlayer());
  int _playerIndex = 0;
  Timer? _metronomeTimer;
  bool _isPlayingMetronome = false;
  double _bpm = 60;

  // Auto-scroll
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;
  double _scrollDurationSec = 60; // 10–300 via slider

  @override
  void initState() {
    super.initState();
    _piece = widget.piece;
  }

  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _scrollTimer?.cancel();
    for (final p in _players) {
      p.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleMetronome() {
    if (_isPlayingMetronome) {
      _metronomeTimer?.cancel();
      for (final p in _players) {
        p.stop();
      }
      setState(() => _isPlayingMetronome = false);
      return;
    }

    if (_bpm < 1) return; // 0 bpm = off
    final interval = Duration(milliseconds: (60000 / _bpm).floor());
    _metronomeTimer = Timer.periodic(interval, (_) {
      _players[_playerIndex].play(AssetSource('click_sound.wav'));
      _playerIndex = (_playerIndex + 1) % _players.length;
    });
    setState(() => _isPlayingMetronome = true);
  }

  void _toggleScroll() {
    if (_isScrolling) {
      _scrollTimer?.cancel();
      setState(() => _isScrolling = false);
      return;
    }
    if (!_scrollController.hasClients || _scrollDurationSec < 1) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _scrollController.jumpTo(0); // start from top

    final speedPerSec = maxScroll / _scrollDurationSec; // px/s
    _scrollTimer = Timer.periodic(const Duration(milliseconds: 33), (t) {
      if (!_scrollController.hasClients) return;
      final current = _scrollController.position.pixels;
      final next = current + speedPerSec * 0.033;
      if (next >= maxScroll) {
        _scrollController.jumpTo(maxScroll);
        _scrollTimer?.cancel();
        setState(() => _isScrolling = false);
      } else {
        _scrollController.jumpTo(next);
      }
    });
    setState(() => _isScrolling = true);
  }

  Future<void> _editPiece() async {
    final updated = await Navigator.push<Piece?>(
      context,
      MaterialPageRoute(builder: (_) => CreationPage(piece: _piece)),
    );
    if (updated != null) {
      setState(() => _piece = updated);
    }
  }

  void _playVideo() {
    final path = _piece.videoPath;
    if (path == null) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => VideoPage(videoPath: path),
    ));
  }

  @override
  Widget build(BuildContext context) {
    var title = _piece.name;
    if ((_piece.composer ?? '').isNotEmpty) {
      title += ' — ${_piece.composer}';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _editPiece),
        ],
      ),
      body: Column(
        children: [
          // Sheet images
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  if ((_piece.imagePaths ?? []).isNotEmpty)
                    for (final path in _piece.imagePaths!)
                      Image.file(
                        File(path),
                        width: MediaQuery.of(context).size.width,
                        fit: BoxFit.fitWidth,
                      )
                  else
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'No sheet images found for this work.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Controls
          Container(
            color: Colors.grey[200],
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Column(
              children: [
                // Performance video
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_piece.videoPath == null)
                      ElevatedButton.icon(
                        icon: const Icon(Icons.video_library),
                        label: const Text('Upload Performance'),
                        onPressed: () async {
                          final FilePickerResult? result =
                              await FilePicker.platform.pickFiles(type: FileType.video);
                          if (result != null && result.files.isNotEmpty) {
                            setState(() {
                              _piece.videoPath = result.files.single.path!;
                            });
                          }
                        },
                      )
                    else
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_circle_fill),
                        label: const Text('Play Performance'),
                        onPressed: _playVideo,
                      ),
                  ],
                ),
                const SizedBox(height: 8),

                // Sliders
                Row(
                  children: [
                    const Text('Tempo:'),
                    Expanded(
                      child: Slider(
                        min: 0,
                        max: 300,
                        divisions: 300,
                        label: _bpm.round().toString(),
                        value: _bpm,
                        onChanged: (v) => setState(() => _bpm = v),
                        onChangeEnd: (v) {
                          if (_isPlayingMetronome) {
                            _metronomeTimer?.cancel();
                            if (v < 1) {
                              for (final p in _players) p.stop();
                              setState(() => _isPlayingMetronome = false);
                            } else {
                              final interval =
                                  Duration(milliseconds: (60000 / v).floor());
                              _metronomeTimer = Timer.periodic(interval, (_) {
                                _players[_playerIndex]
                                    .play(AssetSource('click_sound.wav'));
                                _playerIndex =
                                    (_playerIndex + 1) % _players.length;
                              });
                            }
                          }
                        },
                      ),
                    ),
                    Text('${_bpm.round()} BPM'),
                  ],
                ),
                Row(
                  children: [
                    const Text('Scroll Duration:'),
                    Expanded(
                      child: Slider(
                        min: 10,
                        max: 300,
                        divisions: 58,
                        label: _scrollDurationSec.round().toString(),
                        value: _scrollDurationSec,
                        onChanged: (v) => setState(() => _scrollDurationSec = v),
                      ),
                    ),
                    Text('${_scrollDurationSec.round()}s'),
                  ],
                ),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _toggleMetronome,
                      icon: Icon(_isPlayingMetronome ? Icons.pause : Icons.play_arrow),
                      label: Text(_isPlayingMetronome ? 'Pause Metronome' : 'Play Metronome'),
                    ),
                    ElevatedButton.icon(
                      onPressed: _toggleScroll,
                      icon: Icon(_isScrolling ? Icons.pause : Icons.play_arrow),
                      label: Text(_isScrolling ? 'Pause Scroll' : 'Auto-Scroll'),
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
