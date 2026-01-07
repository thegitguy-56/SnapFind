import 'package:flutter/material.dart';

import '../services/firebase_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _results = [];

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    try {
      final res = await FirebaseService.searchItems(query);
      setState(() => _results = res);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Search error: $e')));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Search',
          style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.blue),
        foregroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText:
                    'Search by type/color/brand (e.g., "blue bottle")',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_loading) const CircularProgressIndicator(),
            if (!_loading)
              Expanded(
                child: _results.isEmpty
                    ? const Center(child: Text('No results yet'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];

                          // Support both new imageUrls list and older imageUrl field
                          String? thumbUrl;
                          if (item['imageUrls'] != null) {
                            final urlsDynamic =
                                item['imageUrls'] as List<dynamic>;
                            if (urlsDynamic.isNotEmpty) {
                              thumbUrl = urlsDynamic.first.toString();
                            }
                          } else if (item['imageUrl'] != null) {
                            thumbUrl = item['imageUrl'].toString();
                          }

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              leading: thumbUrl != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 56,
                                        height: 56,
                                        child: Image.network(
                                          thumbUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              Container(
                                            color: Colors.grey.shade200,
                                            alignment: Alignment.center,
                                            child: const Icon(
                                              Icons.image_not_supported,
                                              size: 24,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.image_not_supported,
                                        size: 24,
                                        color: Colors.grey,
                                      ),
                                    ),
                              title: Text(item['objectType'] ?? ''),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Color: ${item['color'] ?? ''}'),
                                  Text('Brand: ${item['brand'] ?? ''}'),
                                  Text(
                                      'Location: ${item['location'] ?? ''}'),
                                ],
                              ),
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => AlertDialog(
                                    title: const Text('Item found!'),
                                    content: Text(
                                      'Owner email: ${item['userEmail'] ?? 'Unknown'}\n\nIn real app, we would send them a notification.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: const Text('Close'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
