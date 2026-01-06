import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';

import '../services/gemini_service.dart';
import '../services/firebase_service.dart';
import '../services/location_service.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  List<File> _images = [];
  bool _isAnalyzing = false;
  bool _isSaving = false;
  Map<String, dynamic>? _tags;
  String? _location;
  String? _locationName;

  final ImagePicker _picker = ImagePicker();
  final LocationService _locationService = LocationService();

  final TextEditingController _objectController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();

  bool get _isBusy => _isAnalyzing || _isSaving;

  @override
  void dispose() {
    _objectController.dispose();
    _colorController.dispose();
    _brandController.dispose();
    _noteController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _pickCamera() async {
    final xfile = await _picker.pickImage(source: ImageSource.camera);
    if (xfile == null) return;

    setState(() {
      _images.add(File(xfile.path));
      _tags = null;
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

    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Use LocationService to get human-readable location name
      final locationName = await _locationService.resolveLocationName(pos);

      setState(() {
        _location = '${pos.latitude}, ${pos.longitude}';
        _locationName = locationName;
        _locationController.text = locationName;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  Future<void> _analyze() async {
    if (_images.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Pick an image first')));
      return;
    }
    setState(() => _isAnalyzing = true);
    try {
      final tags = await GeminiService.analyzeImages(_images);
      setState(() {
        _tags = tags;
        _objectController.text = tags['object_type'] ?? '';
        _colorController.text = tags['color'] ?? '';
        _brandController.text = tags['brand'] ?? '';
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('AI error: $e')));
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  Future<void> _save() async {
    if (_images.isEmpty || _tags == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Analyze first before saving')),
      );
      return;
    }

    final finalLocation = _locationController.text.trim();
    if (finalLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm or enter a location')),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final manualTags = {
        'object_type': _objectController.text.trim(),
        'color': _colorController.text.trim(),
        'brand': _brandController.text.trim(),
        'note': _noteController.text.trim(),
      };

      await FirebaseService.saveItem(
        images: _images,
        tags: manualTags,
        location: finalLocation,
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved!')));
      setState(() {
        _images = [];
        _tags = null;
        _location = null;
        _locationName = null;
        _objectController.clear();
        _colorController.clear();
        _brandController.clear();
        _noteController.clear();
        _locationController.clear();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Save error: $e')));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Camera / image box (rounded, neat)
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
                      borderRadius: BorderRadius.circular(16),
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
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 48,
                    color: Colors.blue.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No image selected',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Take Photo" to capture an item',
                    style: TextStyle(color: Colors.blue.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Take Photo button (rounded, light black transparent)
          ElevatedButton.icon(
            onPressed: _pickCamera,
            icon: const Icon(Icons.camera_alt),
            label: const Text('Take Photo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black12, // light black, semi-transparent
              foregroundColor: Colors.black87, // icon + text
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: const BorderSide(color: Colors.black26),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_images.isNotEmpty)
            ElevatedButton.icon(
              onPressed: _isBusy ? null : _analyze,
              icon: _isAnalyzing
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.smart_toy),
              label: _isAnalyzing
                  ? const Text('Analyzing...')
                  : const Text('Analyze with AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade50,
                foregroundColor: Colors.deepPurple.shade800,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),

          const SizedBox(height: 16),

          if (_tags != null)
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 2,
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
                      decoration: const InputDecoration(labelText: 'Color'),
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
                    const SizedBox(height: 12),
                    // Location confirmation field
                    TextField(
                      controller: _locationController,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: 'Confirm or edit location',
                        hintText:
                            'Tap to confirm GPS location or type a landmark',
                        border: const OutlineInputBorder(),
                        helperText: _location != null
                            ? 'GPS: $_location'
                            : 'No location captured yet',
                        helperStyle: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 16),

          if (_tags != null)
            ElevatedButton(
              onPressed: _isBusy ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Save to database'),
            ),
        ],
      ),
    );
  }
}
