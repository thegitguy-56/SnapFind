import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class LostItemScreen extends StatefulWidget {
  const LostItemScreen({super.key});

  @override
  State<LostItemScreen> createState() => _LostItemScreenState();
}

class _LostItemScreenState extends State<LostItemScreen> {
  File? _selectedImage;
  DateTime? _lostDate;

  final ImagePicker _picker = ImagePicker();

  final TextEditingController _itemNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String? _selectedCategory;

  final List<String> _categories = [
    'Electronics',
    'Jewelry',
    'Documents',
    'Clothing',
    'Accessories',
    'Keys',
    'Wallet',
    'Phone',
    'Watch',
    'Other',
  ];

  @override
  void dispose() {
    _itemNameController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickImageFromGallery() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return;

    setState(() {
      _selectedImage = File(xfile.path);
    });
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        _lostDate = pickedDate;
      });
    }
  }

  bool _isFormValid() {
    final itemName = _itemNameController.text.trim();
    final location = _locationController.text.trim();
    return itemName.isNotEmpty &&
        _selectedCategory != null &&
        location.isNotEmpty &&
        _lostDate != null;
  }

  void _submitReport() {
    if (!_isFormValid()) {
      return;
    }

    // Placeholder for form submission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Lost item reported successfully!')),
    );

    // Reset form
    setState(() {
      _itemNameController.clear();
      _locationController.clear();
      _notesController.clear();
      _selectedImage = null;
      _lostDate = null;
      _selectedCategory = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Image container
          if (_selectedImage != null)
            SizedBox(
              height: 250,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            )
          else
            Container(
              height: 250,
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade100),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Colors.orange.shade300,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No image selected',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tap "Pick Image" to add a photo (optional)',
                    style: TextStyle(
                      color: Colors.orange.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          const SizedBox(height: 16),

          // Pick Image button
          ElevatedButton.icon(
            onPressed: _pickImageFromGallery,
            icon: const Icon(Icons.image),
            label: const Text('Pick Image'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black12,
              foregroundColor: Colors.black87,
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

          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.only(top: 12.0),
              child: ElevatedButton.icon(
                onPressed: _removeImage,
                icon: const Icon(Icons.close),
                label: const Text('Remove Image'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade50,
                  foregroundColor: Colors.red.shade700,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: Colors.red.shade200),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // Form card
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
                  // Item name field
                  TextField(
                    controller: _itemNameController,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Item Name *',
                      hintText: 'e.g., Black Wallet',
                    ),
                  ),
                  if (_itemNameController.text.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Item name is required',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Category dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select Category *'),
                    items: _categories.map((category) {
                      return DropdownMenuItem<String>(
                        value: category,
                        child: Text(category),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    },
                    decoration: const InputDecoration(labelText: 'Category *'),
                  ),
                  if (_selectedCategory == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Category is required',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Last known location field
                  TextField(
                    controller: _locationController,
                    maxLines: 2,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Last Known Location *',
                      hintText: 'e.g., Main Street Station',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (_locationController.text.trim().isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        'Location is required',
                        style: TextStyle(
                          color: Colors.red.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ),

                  const SizedBox(height: 12),

                  // Lost date picker
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _lostDate != null
                                  ? 'Lost Date: ${_lostDate!.toLocal().toString().split(' ')[0]}'
                                  : 'Lost Date: Not selected',
                              style: const TextStyle(fontSize: 14),
                            ),
                            if (_lostDate == null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text(
                                  'Lost date is required',
                                  style: TextStyle(
                                    color: Colors.red.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _selectDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade50,
                          foregroundColor: Colors.blue.shade700,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        child: const Text('Pick Date'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Notes field
                  TextField(
                    controller: _notesController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                      hintText: 'Any additional details about the item...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Submit button
          ElevatedButton(
            onPressed: _isFormValid() ? _submitReport : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade300,
              disabledForegroundColor: Colors.grey.shade600,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('Report Lost Item'),
          ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
