import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../services/auth_service.dart';
import '../services/firebase_service.dart';
import 'upload_screen.dart';
import 'search_screen.dart';
import 'lost_item_screen.dart';
import 'item_detail_screen.dart';
import 'alerts_screen.dart';
import 'history_screen.dart';
import 'returned_items_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  final _pages = const [FeedScreen(), UploadScreen(), LostItemScreen()];

  Stream<bool> _bellHasUnreadStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Stream<bool>.empty();
    }

    final alertsStream = FirebaseFirestore.instance
        .collection('alerts')
        .where('finderId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'pending')
        .snapshots();

    final finderChatsStream = FirebaseFirestore.instance
        .collection('chats')
        .where('finderId', isEqualTo: user.uid)
        .snapshots();

    final seekerChatsStream = FirebaseFirestore.instance
        .collection('chats')
        .where('seekerId', isEqualTo: user.uid)
        .snapshots();

    return Stream<bool>.multi((controller) {
      bool hasAlert = false;
      bool hasFinderUnread = false;
      bool hasSeekerUnread = false;

      void emit() => controller.add(hasAlert || hasFinderUnread || hasSeekerUnread);

      final alertSub = alertsStream.listen(
        (snapshot) {
          hasAlert = snapshot.docs.isNotEmpty;
          emit();
        },
        onError: controller.addError,
      );

      final finderSub = finderChatsStream.listen(
        (snapshot) {
          hasFinderUnread = _countUnreadChats(snapshot, 'finder') > 0;
          emit();
        },
        onError: controller.addError,
      );

      final seekerSub = seekerChatsStream.listen(
        (snapshot) {
          hasSeekerUnread = _countUnreadChats(snapshot, 'seeker') > 0;
          emit();
        },
        onError: controller.addError,
      );

      controller.onCancel = () {
        alertSub.cancel();
        finderSub.cancel();
        seekerSub.cancel();
      };
    });
  }

  int _countUnreadChats(
    QuerySnapshot<Map<String, dynamic>> snapshot,
    String myRole,
  ) {
    int count = 0;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final String lastSenderRole = (data['lastSenderRole'] ?? '').toString();
      final Timestamp? lastMessageAt = data['lastMessageAt'] as Timestamp?;
      if (lastMessageAt == null) continue;

      final Timestamp? lastReadAt = data[myRole == 'finder'
              ? 'finderLastReadAt'
              : 'seekerLastReadAt']
          as Timestamp?;

      final bool fromOtherSide =
          lastSenderRole.isEmpty || lastSenderRole != myRole;
      final bool unreadByTime = lastReadAt == null ||
          lastMessageAt.toDate().isAfter(lastReadAt.toDate());

      if (fromOtherSide && unreadByTime) {
        count++;
      }
    }

    return count;
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
          StreamBuilder<bool>(
            stream: _bellHasUnreadStream(),
            builder: (context, snapshot) {
              final bool hasUnread = snapshot.data ?? false;

              return IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Icon(Icons.notifications_none),
                    if (hasUnread)
                      Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
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
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const DrawerHeader(
                decoration: BoxDecoration(color: Colors.blue),
                child: Text(
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
                leading: const Icon(Icons.check_circle),
                title: const Text('Returned Items'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ReturnedItemsScreen(),
                    ),
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
  String _selectedStatusFilter = 'found'; // found, lost

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedStatusFilter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedStatusFilter = value);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : Colors.blue,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
            child: Row(
              children: [
                _buildTab('Found', 'found'),
                _buildTab('Lost', 'lost'),
              ],
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onHorizontalDragEnd: (details) {
              if (details.primaryVelocity! > 0) {
                if (_selectedStatusFilter == 'lost') {
                  setState(() => _selectedStatusFilter = 'found');
                }
              } else if (details.primaryVelocity! < 0) {
                if (_selectedStatusFilter == 'found') {
                  setState(() => _selectedStatusFilter = 'lost');
                }
              }
            },
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: FirebaseService.getItemsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 8),
                        Text(
                          'Loading items…',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }

                var items = snapshot.data ?? [];

                items = items.where((item) {
                  final statusStr = (item['status']?.toString() ?? '')
                      .trim()
                      .toLowerCase();
                  if (statusStr.isEmpty) return false;
                  return statusStr == _selectedStatusFilter;
                }).toList();

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        'No ${_selectedStatusFilter.toUpperCase()} items found',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    List<String> urls = [];
                    if (item['imageUrls'] != null) {
                      final urlsDynamic = item['imageUrls'] as List<dynamic>;
                      urls = urlsDynamic.cast<String>();
                    } else if (item['imageUrl'] != null) {
                      urls = [item['imageUrl'] as String];
                    }

                    final note =
                        (item['note'] ?? item['notes'] ?? '').toString();

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
                                    allowImplicitScrolling: true,
                                    itemBuilder: (context, pageIndex) {
                                      final url = urls[pageIndex];
                                      return Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          Container(
                                            color: Colors.grey.shade200,
                                          ),
                                          CachedNetworkImage(
                                            imageUrl: url,
                                            fit: BoxFit.cover,
                                            placeholder: (context, _) =>
                                                const Center(
                                              child: SizedBox(
                                                width: 32,
                                                height: 32,
                                                child:
                                                    CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              ),
                                            ),
                                            errorWidget:
                                                (context, _, __) => Center(
                                              child: Icon(
                                                Icons.broken_image,
                                                color: Colors.grey.shade500,
                                                size: 40,
                                              ),
                                            ),
                                          ),
                                        ],
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                          borderRadius:
                                              BorderRadius.circular(12),
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
                                                TextSpan(
                                                    text: displayLocation),
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
                                        OutlinedButton.icon(
                                          style: OutlinedButton.styleFrom(
                                            backgroundColor:
                                                Colors.green.shade50,
                                            foregroundColor:
                                                Colors.green.shade800,
                                            side: BorderSide(
                                              color: Colors.green.shade400,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
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
                                          label:
                                              const Text('Mark as returned'),
                                          onPressed: () async {
                                            final String? docId =
                                                item['docId'] as String?;
                                            if (docId == null) return;

                                            await FirebaseFirestore.instance
                                                .collection('items')
                                                .doc(docId)
                                                .update(
                                                    {'status': 'returned'});
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
        ),
      ],
    );
  }
}