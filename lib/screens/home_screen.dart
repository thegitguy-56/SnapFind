import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';
import 'search_screen.dart';
import 'lost_item_screen.dart';
import 'item_detail_screen.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [FeedScreen(), UploadScreen(), LostItemScreen()];

  Stream<QuerySnapshot<Map<String, dynamic>>> _alertsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream.empty();
    }
    return FirebaseFirestore.instance
        .collection('alerts')
        .where('finderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SnapFind',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        foregroundColor: Colors.blue,
        actions: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _alertsStream(),
            builder: (context, snapshot) {
              int count = 0;
              if (snapshot.hasData) {
                count = snapshot.data!.docs.length;
              }

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (count > 0)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          child: Text(
                            count.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AlertsScreen()),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(color: Colors.blue),
              child: const Text(
                'Menu',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
              },
            ),
          ],
        ),
      ),
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        backgroundColor: Colors.blue,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.black,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: 'Feed'),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warning_amber),
            label: 'Lost',
          ),
        ],
      ),
    );
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  String _selectedStatusFilter = 'found'; // found, lost, returned

  Widget _buildTab(String label, String value, int count) {
    final isSelected = _selectedStatusFilter == value;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedStatusFilter = value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.blue : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.blue : Colors.grey,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        // Tab navigation with live counts
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService.getItemsStream(),
            builder: (context, statsSnap) {
              final allItems = statsSnap.data ?? [];
              final foundCount = allItems.where((d) {
                final s = d['status']?.toString() ?? '';
                return s.trim().toLowerCase() == 'found';
              }).length;
              final lostCount = allItems.where((d) {
                final s = d['status']?.toString() ?? '';
                return s.trim().toLowerCase() == 'lost';
              }).length;
              final returnedCount = allItems.where((d) {
                final s = d['status']?.toString() ?? '';
                return s.trim().toLowerCase() == 'returned';
              }).length;
              return Row(
                children: [
                  Expanded(child: _buildTab('Found', 'found', foundCount)),
                  const SizedBox(width: 8),
                  Expanded(child: _buildTab('Lost', 'lost', lostCount)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildTab('Returned', 'returned', returnedCount),
                  ),
                ],
              );
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: FirebaseService.getItemsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var items = snapshot.data ?? [];

              // Filter items by selected status (normalize status string)
              items = items.where((item) {
                final statusStr = (item['status']?.toString() ?? '')
                    .trim()
                    .toLowerCase();
                if (statusStr.isEmpty) return false;
                return statusStr == _selectedStatusFilter;
              }).toList();

              if (items.isEmpty) {
                return Center(child: Text('No $_selectedStatusFilter items'));
              }
              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];

                  // Handle both found items (imageUrls) and lost items (imageUrl)
                  List<String> urls = [];
                  if (item['imageUrls'] != null) {
                    final urlsDynamic = item['imageUrls'] as List<dynamic>;
                    urls = urlsDynamic.cast<String>();
                  } else if (item['imageUrl'] != null) {
                    urls = [item['imageUrl'] as String];
                  }

                  // Handle both found items (note) and lost items (notes)
                  final note = (item['note'] ?? item['notes'] ?? '').toString();

                  // Determine display fields based on item type
                  final String displayTitle =
                      item['objectType'] ?? item['itemName'] ?? 'Item';
                  final String displayColor = item['color'] ?? '';
                  final String displayBrand = item['brand'] ?? '';
                  final String displayLocation =
                      item['location'] ?? item['lastKnownLocation'] ?? '';

                  final String? finderId = item['userId'] as String?;
                  final String status =
                      (item['status']?.toString().trim().toLowerCase()) ?? '';
                  final bool isFinder =
                      currentUser != null && finderId == currentUser.uid;

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ItemDetailScreen(item: item),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (urls.isNotEmpty)
                            ClipRRect(
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(16),
                                topRight: Radius.circular(16),
                              ),
                              child: SizedBox(
                                height: 200,
                                width: double.infinity,
                                child: PageView.builder(
                                  itemCount: urls.length,
                                  itemBuilder: (context, pageIndex) {
                                    final url = urls[pageIndex];
                                    return Image.network(
                                      url,
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    );
                                  },
                                ),
                              ),
                            ),

                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayTitle,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: status == 'returned'
                                            ? Colors.green.shade50
                                            : status == 'lost'
                                            ? Colors.red.shade50
                                            : Colors.orange.shade50,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        status == 'lost'
                                            ? 'LOST'
                                            : status == 'returned'
                                            ? 'RETURNED'
                                            : 'FOUND',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: status == 'returned'
                                              ? Colors.green.shade800
                                              : status == 'lost'
                                              ? Colors.red.shade800
                                              : Colors.orange.shade800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // Display color if available (found items)
                                if (displayColor.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.color_lens,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Color: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(text: displayColor),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (displayColor.isNotEmpty)
                                  const SizedBox(height: 2),

                                // Display brand if available (found items)
                                if (displayBrand.isNotEmpty)
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.sell,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Brand: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(text: displayBrand),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                if (displayBrand.isNotEmpty)
                                  const SizedBox(height: 2),

                                // Display location
                                if (displayLocation.isNotEmpty)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.location_on,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: RichText(
                                          text: TextSpan(
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: Colors.black87,
                                            ),
                                            children: [
                                              const TextSpan(
                                                text: 'Location: ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              TextSpan(text: displayLocation),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                if (note.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                      ),
                                      children: [
                                        const TextSpan(
                                          text: 'Note: ',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        TextSpan(text: note),
                                      ],
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Posted by: ${item['userEmail'] ?? item['reportedBy'] ?? ''}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Colors.blue,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (isFinder && status == 'found')
                                      // Styled button
                                      OutlinedButton.icon(
                                        style: OutlinedButton.styleFrom(
                                          backgroundColor: Colors.green.shade50,
                                          foregroundColor:
                                              Colors.green.shade800,
                                          side: BorderSide(
                                            color: Colors.green.shade400,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          textStyle: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.check_circle_outline,
                                          size: 18,
                                        ),
                                        label: const Text('Mark as returned'),
                                        onPressed: () async {
                                          final String? docId =
                                              item['docId'] as String?;
                                          if (docId == null) return;

                                          await FirebaseFirestore.instance
                                              .collection('items')
                                              .doc(docId)
                                              .update({'status': 'returned'});
                                        },
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
