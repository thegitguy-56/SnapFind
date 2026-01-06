import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/firebase_service.dart';
import 'item_detail_screen.dart';

class ReturnedItemsScreen extends StatelessWidget {
  const ReturnedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Returned Items',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        foregroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService.getItemsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          var items = snapshot.data ?? [];

          // Filter to only returned items
          items = items.where((item) {
            final statusStr = (item['status']?.toString() ?? '')
                .trim()
                .toLowerCase();
            return statusStr == 'returned';
          }).toList();

          if (items.isEmpty) {
            return const Center(child: Text('No returned items'));
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
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'RETURNED',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),

                            // Display color if available
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

                            // Display brand if available
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
                                crossAxisAlignment: CrossAxisAlignment.start,
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
                            Text(
                              'Posted by: ${item['userEmail'] ?? item['reportedBy'] ?? ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
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
    );
  }
}
