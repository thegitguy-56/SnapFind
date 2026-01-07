import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _messageCtrl = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'message': _messageCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'userId': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks for your feedback!')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send: $e')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Feedback'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _sending ? null : _submit,
            child: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Send',
                    style: TextStyle(color: Colors.blue),
                  ),
          ),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'For other issues like spam or scams, please contact support from the Help section.',
                style: TextStyle(fontSize: 13, color: Color.fromARGB(255, 0, 0, 0)),
              ),
              const SizedBox(height: 16),

              // Describe issue card
              Text(
                'Describe the issue',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color.fromARGB(255, 0, 0, 0).withOpacity(0.0),
                ), // invisible label to match spacing
              ),
              Container(
                decoration: BoxDecoration(
                  color:  const Color.fromARGB(255, 141, 182, 228),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(12),
                height: 160,
                child: TextFormField(
                  controller: _messageCtrl,
                  maxLines: null,
                  expands: true,
                  style: const TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  decoration: const InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText: 'Describe the technical issue',
                    hintStyle: TextStyle(color: Color.fromARGB(255, 0, 0, 0)),
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Please enter something' : null,
                ),
              ),

              const SizedBox(height: 20),

              // Screenshots placeholder (optional)
              const Text(
                'Screenshots (optional)',
                style: TextStyle(fontSize: 14, color: Color.fromARGB(255, 0, 0, 0)),
              ),
              const SizedBox(height: 8),
              Container(
                height: 120,
                width: double.infinity,
                decoration: BoxDecoration(
                  color:  const Color.fromARGB(255, 141, 182, 228),
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 0, 0, 0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'You can attach screenshots in a future version of the app.',
                        style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 0, 0, 0)),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              const Text(
                'By sending, you allow SnapFind to review technical info to help address your feedback.',
                style: TextStyle(fontSize: 12, color: Color.fromARGB(255, 0, 0, 0)),
              ),
            ],
          ),
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 255, 255, 255), // dark style like WhatsApp
    );
  }
}
