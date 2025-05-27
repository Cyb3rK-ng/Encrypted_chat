import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';
import 'dart:io';

class SendMsgPage extends StatefulWidget {
  final Function(String, String) onSend;
  final List<Map<String, String>> contacts;

  const SendMsgPage({super.key, required this.onSend, required this.contacts});

  @override
  State<SendMsgPage> createState() => _SendMsgPageState();
}

class _SendMsgPageState extends State<SendMsgPage> {
  final TextEditingController _messageController = TextEditingController();
  String? _selectedReceiverId;
  String? _base64Image;

  Future<bool> _requestPermissions() async {
    final status = await [Permission.camera, Permission.photos].request();
    return status[Permission.camera]!.isGranted &&
        status[Permission.photos]!.isGranted;
  }

  void _pickImage() async {
    if (await _requestPermissions()) {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        final bytes = await File(pickedFile.path).readAsBytes();
        setState(() {
          _base64Image = base64Encode(bytes);
        });
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera or photos permission denied")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Send Message"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            DropdownButton<String>(
              hint: const Text("Select Contact"),
              value: _selectedReceiverId,
              isExpanded: true,
              items: widget.contacts.map((contact) {
                return DropdownMenuItem<String>(
                  value: contact['receiverId'],
                  child: Text(contact['nickname'] ?? 'Unknown'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedReceiverId = value;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: "Message",
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text("Pick Image"),
            ),
            if (_base64Image != null)
              const Text("Image selected",
                  style: TextStyle(color: Colors.green)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                if (_selectedReceiverId != null &&
                    (_messageController.text.isNotEmpty ||
                        _base64Image != null)) {
                  final message = _base64Image != null
                      ? jsonEncode({'type': 'image', 'data': _base64Image})
                      : jsonEncode(
                          {'type': 'text', 'data': _messageController.text});
                  widget.onSend(_selectedReceiverId!, message);
                  Navigator.pop(context);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            "Please select a contact and enter a message or image")),
                  );
                }
              },
              child: const Text("Send"),
            ),
          ],
        ),
      ),
    );
  }
}
