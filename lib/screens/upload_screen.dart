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
  File? _image;
  bool _loading = false;
  Map<String, dynamic>? _tags;
  String? _location;

  final ImagePicker _picker = ImagePicker();

  Future<void> _pickCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;
    setState(() {
      _image = File(xfile.path);
      _tags = null;
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
    if (_image == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick an image first')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      final tags = await GeminiService.analyzeImage(_image!);
      setState(() {
        _tags = tags;
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
    if (_image == null || _tags == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyze first before saving')),
      );
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseService.saveItem(
        image: _image!,
        tags: _tags!,
        location: _location ?? 'Unknown',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Item saved!')),
      );
      setState(() {
        _image = null;
        _tags = null;
        _location = null;
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
          if (_image != null)
            SizedBox(
              height: 250,
              child: Image.file(_image!, fit: BoxFit.cover),
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
          if (_image != null)
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
                    Text('Object: ${_tags!['object_type'] ?? ''}'),
                    Text('Color: ${_tags!['color'] ?? ''}'),
                    Text('Brand: ${_tags!['brand'] ?? ''}'),
                    if (_location != null)
                      Text('Location: $_location'),
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
