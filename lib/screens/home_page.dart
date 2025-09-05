import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../models/piece.dart';
import 'creation_page.dart';
import 'piece_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final List<Piece> _pieces = [];         // list of pieces added
  final ImagePicker _imagePicker = ImagePicker();
  String _searchQuery = "";               // current search text for filtering
  late TabController _tabController;      // controller for difficulty filter tabs
  final List<String> _difficulties = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _difficulties.length, vsync: this);
    _tabController.addListener(() {
      setState(() {
        // refresh list when tab changes
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Filter pieces by current search text and selected difficulty tab
  List<Piece> get _filteredPieces {
    String query = _searchQuery.toLowerCase();
    String selectedDiff = _difficulties[_tabController.index];
    return _pieces.where((piece) {
      bool matchesQuery = query.isEmpty ||
          piece.name.toLowerCase().contains(query) ||
          (piece.composer?.toLowerCase().contains(query) ?? false);
      bool matchesDiff = piece.difficulty == selectedDiff;
      return matchesQuery && matchesDiff;
    }).toList();
  }

  // Navigate to the creation page to add a new piece
  void _onAddNewWork() async {
    Piece? newPiece = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => CreationPage()),  // no initial file, user will choose inside
    );
    if (newPiece != null) {
      setState(() {
        _pieces.add(newPiece);
        // Sorting within a difficulty group (optional): sort by name
        _pieces.sort((a, b) {
          if (a.difficulty != b.difficulty) {
            // Keep pieces grouped by difficulty (Beginner/Intermediate/Advanced)
            return _difficultyRank(a.difficulty).compareTo(_difficultyRank(b.difficulty));
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      });
    }
  }

  // Difficulty ranking helper (for sorting, if needed)
  int _difficultyRank(String difficulty) {
    switch (difficulty) {
      case 'Beginner': return 0;
      case 'Intermediate': return 1;
      case 'Advanced': return 2;
      default: return 3;
    }
  }

  // Remove a piece from the list (used for swipe-to-delete)
  void _deletePiece(int index) {
    setState(() {
      _pieces.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    bool hasPieces = _pieces.isNotEmpty;
    return Scaffold(
      appBar: AppBar(
        title: const Text('FlowScores'),
        bottom: TabBar(
          controller: _tabController,
          tabs: _difficulties.map((level) => Tab(text: level)).toList(),
        ),
      ),
      body: Column(
        children: [
          // Search field at top
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by title or composer',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Piece list (within Expanded)
          Expanded(
            child: hasPieces ? _buildPieceList() : _buildEmptyState(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onAddNewWork,
        icon: const Icon(Icons.add),
        label: const Text('Add New Work'),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildEmptyState() {
    // Shown when no pieces have been added yet
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Add your first piece',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add New Work'),
            onPressed: _onAddNewWork,
          ),
        ],
      ),
    );
  }

  Widget _buildPieceList() {
    final filtered = _filteredPieces;
    if (filtered.isEmpty) {
      // No pieces match filter
      return Center(child: Text('No pieces found', style: TextStyle(fontSize: 16)));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),  // add bottom padding for FAB space
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final piece = filtered[index];
        return Dismissible(
          key: ValueKey(piece.name + piece.difficulty + (piece.pdfPath ?? piece.imagePaths.toString())),
          direction: DismissDirection.endToStart,
          onDismissed: (_) => _deletePiece(_pieces.indexOf(piece)),
          background: Container(
            color: Colors.red, 
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          child: Card(
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            child: ListTile(
              title: Text(piece.name),
              subtitle: Text(
                (piece.composer != null && piece.composer!.isNotEmpty)
                  ? '${piece.composer} • ${piece.difficulty} • ${piece.progress}'
                  : '${piece.difficulty} • ${piece.progress}'
              ),
              trailing: Icon(piece.type == PieceType.pdf ? Icons.picture_as_pdf : Icons.image),
              onTap: () async {
                // Open piece view
                await Navigator.push(context, MaterialPageRoute(builder: (_) => PiecePage(piece: piece)));
                // After returning, if difficulty or progress may have changed, sort list
                setState(() {
                  _pieces.sort((a, b) {
                    if (a.difficulty != b.difficulty) {
                      return _difficultyRank(a.difficulty).compareTo(_difficultyRank(b.difficulty));
                    }
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                });
              },
              // Optional: edit inline button
              // trailing: IconButton(
              //   icon: Icon(Icons.edit),
              //   onPressed: () {
              //     Navigator.push(context, MaterialPageRoute(builder: (_) => CreationPage(piece: piece)))
              //       .then((updatedPiece) {
              //         if (updatedPiece != null) {
              //           setState(() {}); // piece list will reflect changes since we're editing in place
              //         }
              //       });
              //   },
              // ),
            ),
          ),
        );
      },
    );
  }
}
