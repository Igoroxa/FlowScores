import 'package:flutter/material.dart';
import '../models/piece.dart';
import 'creation_page.dart';
import 'piece_page.dart';
import '../services/onboarding_service.dart';
import '../services/piece_storage_service.dart';
import '../widgets/onboarding_popups.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  final List<Piece> _pieces = [];         // list of pieces added
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
    // Load saved pieces when the page initializes
    _loadPieces();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Dismiss keyboard when home page becomes visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).unfocus();
      // Show first app launch popup if needed
      _checkAndShowFirstAppLaunchPopup();
    });
  }

  Future<void> _checkAndShowFirstAppLaunchPopup() async {
    final shouldShow = await OnboardingService.shouldShowFirstAppLaunch();
    if (shouldShow && mounted) {
      OnboardingPopups.showFirstAppLaunchPopup(context);
      await OnboardingService.markFirstAppLaunchShown();
    }
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
    // Dismiss keyboard before navigating
    FocusScope.of(context).unfocus();
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
      // Save pieces after adding a new one
      await _savePieces();
    }
  }

  // Load pieces from local storage
  Future<void> _loadPieces() async {
    try {
      final savedPieces = await PieceStorageService.loadPieces();
      setState(() {
        _pieces.clear();
        _pieces.addAll(savedPieces);
        // Sort pieces after loading
        _pieces.sort((a, b) {
          if (a.difficulty != b.difficulty) {
            return _difficultyRank(a.difficulty).compareTo(_difficultyRank(b.difficulty));
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
      });
    } catch (e) {
      print('Error loading pieces: $e');
    }
  }

  // Save pieces to local storage
  Future<void> _savePieces() async {
    try {
      await PieceStorageService.savePieces(_pieces);
    } catch (e) {
      print('Error saving pieces: $e');
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


  @override
  Widget build(BuildContext context) {
    bool hasPieces = _pieces.isNotEmpty;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              // Logo
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/FlowScores_Logo.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // App name
              const Text(
                'FlowScores',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(25),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorPadding: const EdgeInsets.symmetric(horizontal: -12, vertical: 4),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey[600],
              tabs: _difficulties.map((level) => Tab(text: level)).toList(),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () {
          // Dismiss keyboard when tapping outside text fields
          FocusScope.of(context).unfocus();
        },
        child: Column(
          children: [
            // Search field at top
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  hintText: 'Search',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(25),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
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
      ),
      floatingActionButton: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton(
          onPressed: _onAddNewWork,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            padding: const EdgeInsets.symmetric(vertical: 16),
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.3),
          ),
          child: const Text(
            'Add New Work',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
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
          Text(
            'Add your First Work',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _onAddNewWork,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              elevation: 4,
              shadowColor: Colors.black.withOpacity(0.3),
            ),
            child: const Text(
              'Add New Work',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieceList() {
    final filtered = _filteredPieces;
    if (filtered.isEmpty) {
      // No pieces match filter
      return Center(child: Text('No pieces found', style: TextStyle(fontSize: 16, color: Colors.grey[600])));
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 100, left: 16, right: 16, top: 8),  // add bottom padding for FAB space
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final piece = filtered[index];
        return Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text(
              piece.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              (piece.composer != null && piece.composer!.isNotEmpty)
                ? '${piece.composer} • ${piece.difficulty}'
                : piece.difficulty,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 14,
              ),
            ),
            trailing: Icon(
              piece.type == PieceType.pdf ? Icons.picture_as_pdf : Icons.image,
              color: Colors.white,
            ),
            onTap: () async {
              // Dismiss keyboard before navigating
              FocusScope.of(context).unfocus();
              // Open piece view
              final result = await Navigator.push<Piece?>(context, MaterialPageRoute(builder: (_) => PiecePage(piece: piece)));
              
              // Check if the piece was deleted
              if (result != null) {
                // Piece was deleted, remove it from the list
                setState(() {
                  _pieces.removeWhere((p) => p.name == result.name && p.difficulty == result.difficulty);
                });
                // Save pieces after deletion
                await _savePieces();
              } else {
                // After returning, if difficulty or progress may have changed, sort list
                setState(() {
                  _pieces.sort((a, b) {
                    if (a.difficulty != b.difficulty) {
                      return _difficultyRank(a.difficulty).compareTo(_difficultyRank(b.difficulty));
                    }
                    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
                  });
                });
                // Save pieces after any potential updates
                await _savePieces();
              }
            },
          ),
        );
      },
    );
  }
}
