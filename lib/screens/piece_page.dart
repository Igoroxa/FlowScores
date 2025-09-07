import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/piece.dart';
import 'creation_page.dart';
import 'video_page.dart';
import 'pages_edit_page.dart';

class PiecePage extends StatefulWidget {
  final Piece piece;
  const PiecePage({super.key, required this.piece});

  @override
  State<PiecePage> createState() => _PiecePageState();
}

class _PiecePageState extends State<PiecePage> {
  late Piece _piece;

  // Metronome
  final List<AudioPlayer> _metronomePlayers = List.generate(4, (_) => AudioPlayer());
  int _playerIndex = 0;
  Timer? _metronomeTimer;
  bool _isPlayingMetronome = false;
  double _bpm = 200;

  // Auto-scroll
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollTimer;
  bool _isScrolling = false;
  double _scrollDurationSec = 120; // 30–600 seconds (30 seconds to 10 minutes)

  // UI State
  bool _showBottomControls = true;
  bool _showMetronome = false;
  bool _showAutoScroll = false;

  @override
  void initState() {
    super.initState();
    _piece = widget.piece;
    _preloadMetronomeAudio();
  }

  Future<void> _preloadMetronomeAudio() async {
    // Preload the click sound to all metronome players for instant playback
    for (final player in _metronomePlayers) {
      try {
        await player.setAsset('assets/click_sound.wav');
      } catch (e) {
        // Handle error silently
      }
    }
  }


  @override
  void dispose() {
    _metronomeTimer?.cancel();
    _scrollTimer?.cancel();
    for (final p in _metronomePlayers) {
      p.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _toggleMetronome() {
    if (_isPlayingMetronome) {
      _stopMetronome();
      return;
    }
    if (_bpm < 1) return; // 0 bpm = off
    _startMetronome();
  }

  void _startMetronome() {
    if (_bpm < 1) return;
    
    // Calculate the exact interval in milliseconds
    final intervalMs = (60000 / _bpm).round();
    
    // Use a timer that fires at the exact BPM interval
    _metronomeTimer = Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (!_isPlayingMetronome) return;
      _playMetronomeClick();
    });
    
    setState(() => _isPlayingMetronome = true);
  }

  void _playMetronomeClick() {
    // Use just_audio for better timing and performance
    _metronomePlayers[_playerIndex].seek(Duration.zero);
    _metronomePlayers[_playerIndex].play();
    _playerIndex = (_playerIndex + 1) % _metronomePlayers.length;
  }

  void _stopMetronome() {
    _metronomeTimer?.cancel();
    for (final p in _metronomePlayers) {
      p.stop();
    }
    setState(() => _isPlayingMetronome = false);
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
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => VideoPage(videoPath: path, pieceName: _piece.name)),
    );
  }

  // **New: Navigate to the page selection screen for cropping**
  Future<void> _onCrop() async {
    final updatedPiece = await Navigator.push<Piece?>(
      context,
      MaterialPageRoute(builder: (_) => PagesEditPage(piece: _piece)),
    );
    if (updatedPiece != null) {
      setState(() => _piece = updatedPiece);
    }
  }

  String _formatTime(double seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = (seconds % 60).round();
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildBottomControls() {
    return Container(
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main control buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: _buildControlButton(
                    text: 'Metronome',
                    onPressed: () {
                      setState(() {
                        _showMetronome = !_showMetronome;
                        _showAutoScroll = false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildControlButton(
                    text: 'Auto Scroll',
                    onPressed: () {
                      setState(() {
                        _showAutoScroll = !_showAutoScroll;
                        _showMetronome = false;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Expandable sections
          if (_showMetronome) _buildMetronomeSection(),
          if (_showAutoScroll) _buildAutoScrollSection(),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required String text,
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
        padding: const EdgeInsets.symmetric(vertical: 16),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.2),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildMetronomeSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Metronome header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() => _showMetronome = false);
                },
              ),
              const Expanded(
                child: Text(
                  'Metronome',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.black),
                onPressed: () {}, // (metronome settings placeholder)
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isPlayingMetronome ? _toggleMetronome : null,
                icon: const Icon(Icons.pause, color: Colors.black, size: 32),
              ),
              const SizedBox(width: 20),
              Text(
                _bpm.round().toString(),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: _isPlayingMetronome ? null : _toggleMetronome,
                icon: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // BPM Slider
          Slider(
            value: _bpm,
            min: 30,
            max: 500,
            divisions: 470,
            onChanged: (value) {
              setState(() {
                _bpm = value;
              });
              if (_isPlayingMetronome) {
                _stopMetronome();
                _startMetronome();
              }
            },
            activeColor: Colors.grey[600],
            inactiveColor: Colors.grey[300],
          ),
        ],
      ),
    );
  }

  Widget _buildAutoScrollSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Auto Scroll header
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black),
                onPressed: () {
                  setState(() => _showAutoScroll = false);
                },
              ),
              const Expanded(
                child: Text(
                  'Auto Scroll',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.black),
                onPressed: () {}, // (auto-scroll settings placeholder)
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Playback controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: _isScrolling ? _toggleScroll : null,
                icon: const Icon(Icons.pause, color: Colors.black, size: 32),
              ),
              const SizedBox(width: 20),
              Text(
                _formatTime(_scrollDurationSec),
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black),
              ),
              const SizedBox(width: 20),
              IconButton(
                onPressed: _isScrolling ? null : _toggleScroll,
                icon: const Icon(Icons.play_arrow, color: Colors.black, size: 32),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Duration slider
          Slider(
            value: _scrollDurationSec,
            min: 30,
            max: 600,
            divisions: 57,
            onChanged: (value) {
              setState(() {
                _scrollDurationSec = value;
              });
            },
            activeColor: Colors.grey[600],
            inactiveColor: Colors.grey[300],
          ),
        ],
      ),
    );
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
        title: Text(
          _piece.name,
          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          if (_piece.videoPath != null)
            IconButton(
              icon: const Icon(Icons.play_circle_fill, color: Colors.black),
              onPressed: _playVideo,
              tooltip: 'Play Performance Video',
            ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _onCrop,
              icon: const Icon(Icons.crop, color: Colors.white, size: 18),
              label: const Text(
                'Crop',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                elevation: 2,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black),
            onPressed: _editPiece,
            tooltip: 'Settings',
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          if (_showBottomControls) {
            setState(() {
              _showBottomControls = false;
              _showMetronome = false;
              _showAutoScroll = false;
            });
          }
        },
        child: Stack(
          children: [
            // Sheet music content (all pages images)
            SingleChildScrollView(
              controller: _scrollController,
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
                        'No sheet images found for this Work.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom controls overlay
            if (_showBottomControls)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildBottomControls(),
              ),
            // Tap-to-show-controls hint
            if (!_showBottomControls)
              Positioned(
                bottom: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showBottomControls = true;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Tap to Show Controls',
                        style: TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
