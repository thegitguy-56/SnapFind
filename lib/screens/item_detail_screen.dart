import 'package:flutter/material.dart';

class ItemDetailScreen extends StatelessWidget {
  final Map<String, dynamic> item;

  const ItemDetailScreen({super.key, required this.item});

  void _onAlertPressed(BuildContext context) {
    // TODO: implement Firestore alert logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Alert button pressed")),
    );
  }

  void _onChatPressed(BuildContext context) {
    // TODO: implement Firestore chat logic
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Chat button pressed")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> urlsDynamic = item['imageUrls'] ?? <dynamic>[];
    final List<String> urls = urlsDynamic.cast<String>();
    final note = (item['note'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Item details'),
      ),
      body: Column(
        children: [
          Expanded(
            child: Column(
              children: [
                if (urls.isNotEmpty)
                  SizedBox(
                    height: 260,
                    width: double.infinity,
                    child: PageView.builder(
                      itemCount: urls.length,
                      itemBuilder: (context, index) {
                        final url = urls[index];
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Main heading bigger
                        Text(
                          item['objectType'] ?? '',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Bold labels for fields
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Color: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (item['color'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Brand: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (item['brand'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black,
                            ),
                            children: [
                              const TextSpan(
                                text: 'Location: ',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextSpan(
                                text: (item['location'] ?? '').toString(),
                              ),
                            ],
                          ),
                        ),
                        if (note.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                              ),
                              children: [
                                const TextSpan(
                                  text: 'Note: ',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                                TextSpan(text: note),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        Text(
                          'Posted by: ${item['userEmail'] ?? ''}',
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(12,16,12,24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orangeAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _onAlertPressed(context),
                    child: const Text(
                      "I'm looking for this",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _onChatPressed(context),
                    child: const Text(
                      "Chat with finder",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
