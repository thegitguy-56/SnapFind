import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/gemini_service.dart';
import '../services/firebase_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File> _images = []; // multiple images
  bool _loading = false;
  Map<String, dynamic>? _tags;
  String? _location;

  final ImagePicker _picker = ImagePicker();

  // Controllers for manual edit
  final TextEditingController _objectController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _objectController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    setState(() {
      _images.add(File(xfile.path)); // add new photo
      _tags = null; // clear old AI tags
      _objectController.clear();
      _colorController.clear();
      _brandController.clear();
      _noteController.clear();
    });

    await _getLocation();
  }

  Future<void> _getLocation() async {
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permission denied')),
      );
      return;
    }

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    setState(() {
      _location = '${pos.latitude}, ${pos.longitude}';
    });
  }

  Future<void> _analyze() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an image first')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final tags = await GeminiService.analyzeImages(_images);
      setState(() {
        _tags = tags;
        _objectController.text = tags['object_type'] ?? '';
        _colorController.text = tags['color'] ?? '';
        _brandController.text = tags['brand'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_images.isEmpty || _tags == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyze first before saving')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final manualTags = {
        'object_type': _objectController.text.trim(),
        'color': _colorController.text.trim(),
        'brand': _brandController.text.trim(),
        'note': _noteController.text.trim(),
      };

      await FirebaseService.saveItem(
        images: _images, // pass all images
        tags: manualTags,
        location: _location ?? 'Unknown',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item saved!')),
      );
      setState(() {
        _images = [];
        _tags = null;
        _location = null;
        _objectController.clear();
        _colorController.clear();
        _brandController.clear();
        _noteController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save error: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_images.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  final file = _images[index];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        file,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 250,
              color: Colors.grey[300],
              child: const Center(child: Text('No image selected')),
            ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _pickCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
          ),
          const SizedBox(height: 16),
          if (_images.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _loading ? null : _analyze,
              icon: const Icon(Icons.smart_toy),
              label: const Text('Analyze with AI'),
            ),
          const SizedBox(height: 16),
          if (_tags != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _objectController,
                      decoration: const InputDecoration(
                        labelText: 'Object type',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _colorController,
                      decoration: const InputDecoration(
                        labelText: 'Color',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _brandController,
                      decoration: const InputDecoration(
                        labelText: 'Brand (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _noteController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Additional notes (optional)',
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_location != null)
                      Text('Location (from GPS): $_location'),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          if (_tags != null)
            ElevatedButton(
              onPressed: _loading ? null : _save,
              child: _loading
                  ? const CircularProgressIndicator()
                  : const Text('Save to database'),
            ),
        ],
      ),
    );
  }
}
