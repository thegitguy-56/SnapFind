import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('About'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App name + logo placeholder
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.cover, // or BoxFit.contain if logo has padding
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'SnapFind',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'See it, Snap it, Find it.',
                      style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 111, 197, 255)),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            const Text(
              'Version',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '1.0.0',
              style: TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 16),

            const Text(
              'Developer',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Built by the SnapFind team.\nContact 1: volapurohan@gmail.com \nContact 2: cdasarath777@gmail.com',
              style: TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 16),

            const Text(
              'About SnapFind',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'SnapFind helps people report found items with photos and AI tags, '
              'and connect safely with owners through an in‑app chat.',
              style: TextStyle(fontSize: 13),
            ),

            const SizedBox(height: 16),

            const Text(
              'Privacy & data',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This app stores data in Google Firebase. Information is used only '
              'to power lost‑and‑found features and chat between users.',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}