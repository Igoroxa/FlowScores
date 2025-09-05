import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class VideoPage extends StatefulWidget {
  final String videoPath;
  const VideoPage({Key? key, required this.videoPath}) : super(key: key);

  @override
  State<VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<VideoPage> {
  late VideoPlayerController _videoController;
  late Future<void> _initializeFuture;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.file(File(widget.videoPath));
    _videoController.addListener(() {
      if (mounted) {
        setState(() {}); // update UI on controller state changes
      }
    });
    _initializeFuture = _videoController.initialize().then((_) {
      _videoController.play();
      setState(() {}); 
    });
  }

  @override
  void dispose() {
    _videoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Performance Video'),
      ),
      body: FutureBuilder(
        future: _initializeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            // Video initialized
            return Center(
              child: AspectRatio(
                aspectRatio: _videoController.value.aspectRatio,
                child: VideoPlayer(_videoController),
              ),
            );
          } else {
            // Loading
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          setState(() {
            if (_videoController.value.isPlaying) {
              _videoController.pause();
            } else {
              _videoController.play();
            }
          });
        },
        child: Icon(
          _videoController.value.isPlaying ? Icons.pause : Icons.play_arrow
        ),
      ),
    );
  }
}
