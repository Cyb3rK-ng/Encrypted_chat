import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:p42/functions.dart';
import 'package:p42/pages/sendMsg.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:convert';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _localdb = Hive.box('LocalDB');
  final _firestore = FirebaseFirestore.instance;
  String userId = "";
  String userName = "";
  RSAPublicKey? publicKey;
  RSAPrivateKey? privateKey;
  double draggerHeight = 60;
  List<Map<String, dynamic>> messages = [];
  List<Map<String, String>> contacts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeProfile();
  }

  Future<void> _initializeProfile() async {
    await profileSetup();
    if (userId.isNotEmpty) {
      _setupMessageListener();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> profileSetup() async {
    try {
      userName = _localdb.get('userName', defaultValue: "");
      if (userName.isEmpty) {
        userName = getRandomNickname();
        await _localdb.put('userName', userName);
      }
      userId = _localdb.get('userId', defaultValue: "");
      if (userId.isEmpty) {
        userId = await generateUniqueUserId();
        final keyPair = generateRSAKeyPair();
        publicKey = keyPair.publicKey as RSAPublicKey?;
        privateKey = keyPair.privateKey as RSAPrivateKey?;
        await _localdb.put('userId', userId);
        await _localdb.put('publicKey', serializeRSAPublicKey(publicKey!));
        await _localdb.put('privateKey', serializeRSAPrivateKey(privateKey!));
        await _firestore.collection('users').doc(userId).set({
          'userId': userId,
          'publicKey': serializeRSAPublicKey(publicKey!),
        });
      } else {
        final publicKeyString = _localdb.get('publicKey', defaultValue: '');
        final privateKeyString = _localdb.get('privateKey', defaultValue: '');
        if (publicKeyString.isNotEmpty && privateKeyString.isNotEmpty) {
          publicKey = deserializeRSAPublicKey(publicKeyString);
          privateKey = deserializeRSAPrivateKey(privateKeyString);
        }
      }
      final storedContacts =
          _localdb.get('contacts', defaultValue: []).cast<String>();
      if (storedContacts.isNotEmpty) {
        contacts = storedContacts
            .map((e) => Map<String, String>.from(jsonDecode(e)))
            .toList();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error initializing Hive: $e")),
      );
    }
  }

  void _setupMessageListener() {
    _firestore
        .collection('messages')
        .doc(userId)
        .collection('inbox')
        .snapshots()
        .listen(
      (snapshot) {
        final loadedMessages = snapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'messageId': doc.id,
            'senderId': data['senderId'] ?? 'Unknown',
            'message': data['message'] ?? '',
          };
        }).toList();
        setState(() {
          messages = loadedMessages;
        });
      },
      onError: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching messages: $error")),
        );
      },
    );
  }

  void sendMessage(String receiverId, String message) {
    final contact = contacts.firstWhere((c) => c['receiverId'] == receiverId,
        orElse: () => {});
    final receiverPublicKey = contact['publicKey'];
    if (receiverPublicKey != null) {
      final encryptedMessage = encryptText(message, receiverPublicKey);
      _firestore
          .collection('messages')
          .doc(receiverId)
          .collection('inbox')
          .add({
        'senderId': userId,
        'message': encryptedMessage,
        'timestamp': FieldValue.serverTimestamp(),
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error sending message: $error")),
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Contact public key not found")),
      );
    }
  }

  void deleteMessage(String messageId) {
    _firestore
        .collection('messages')
        .doc(userId)
        .collection('inbox')
        .doc(messageId)
        .delete()
        .catchError((error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error deleting message: $error")),
      );
    });
  }

  void storeContact(String receiverId, String publicKey, String nickname) {
    if (!contacts.any((c) => c['receiverId'] == receiverId)) {
      final contact = {
        'receiverId': receiverId,
        'publicKey': publicKey,
        'nickname': nickname
      };
      contacts.add(contact);
      _localdb.put('contacts', contacts.map((c) => jsonEncode(c)).toList());
      setState(() {});
    }
  }

  void scanQRCode() async {
    if (await Permission.camera.request().isGranted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          content: SizedBox(
            width: 300,
            height: 300,
            child: MobileScanner(
              onDetect: (barcodeCapture) {
                final data = barcodeCapture.barcodes.first.rawValue;
                if (data != null) {
                  try {
                    final decoded = jsonDecode(data);
                    storeContact(decoded['userId'], decoded['publicKey'],
                        getRandomNickname());
                    Navigator.pop(context);
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Invalid QR code")),
                    );
                  }
                }
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Camera permission denied")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white10,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 40, right: 40, top: 20),
                  child: Column(
                    children: [
                      Expanded(
                        child: messages.isNotEmpty
                            ? messageCard(
                                context, messages, deleteMessage, privateKey)
                            : const Center(
                                child: Text(
                                  "No Messages",
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 18),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: GestureDetector(
                    onVerticalDragUpdate: (details) {
                      setState(() {
                        draggerHeight = (draggerHeight - details.delta.dy)
                            .clamp(60.0, 550.0);
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: draggerHeight,
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.8),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(30),
                          topRight: Radius.circular(30),
                        ),
                      ),
                      child: Column(
                        children: [
                          const ListTile(
                            title: Icon(
                              Icons.drag_handle,
                              size: 30,
                              color: Colors.indigo,
                            ),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 25),
                                      width: MediaQuery.of(context).size.width -
                                          80,
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(24),
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.indigo.withOpacity(0.2),
                                            spreadRadius: 20,
                                            blurRadius: 30,
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(
                                            width: 80,
                                            child: Icon(
                                              Icons.person,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                "ID: $userId",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                userName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                "Contacts: ${contacts.length}",
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    Wrap(
                                      spacing: 20,
                                      runSpacing: 20,
                                      alignment: WrapAlignment.center,
                                      children: [
                                        cardMenuButton(
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SendMsgPage(
                                                  onSend: sendMessage,
                                                  contacts: contacts,
                                                ),
                                              ),
                                            );
                                          },
                                          title: "Send Message",
                                          icon: const Icon(
                                            Icons.send,
                                            size: 40,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        cardMenuButton(
                                          onTap: scanQRCode,
                                          title: "Add Contact",
                                          icon: const Icon(
                                            Icons.person_add,
                                            size: 40,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        cardMenuButton(
                                          onTap: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title:
                                                    const Text("My Contacts"),
                                                content: SizedBox(
                                                  width: 300,
                                                  height: 300,
                                                  child: contacts.isEmpty
                                                      ? const Center(
                                                          child: Text(
                                                              "No contacts"))
                                                      : ListView.builder(
                                                          itemCount:
                                                              contacts.length,
                                                          itemBuilder:
                                                              (context, index) {
                                                            return ListTile(
                                                              title: Text(
                                                                contacts[index][
                                                                        'nickname'] ??
                                                                    'Unknown',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .black,
                                                                  fontSize: 16,
                                                                ),
                                                              ),
                                                              subtitle: Text(
                                                                'ID: ${contacts[index]['receiverId'] ?? 'Unknown'}',
                                                                style:
                                                                    const TextStyle(
                                                                  color: Colors
                                                                      .black54,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        ),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                    child: const Text("Close"),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                          title: "My Contacts",
                                          icon: const Icon(
                                            Icons.contacts,
                                            size: 40,
                                            color: Colors.white70,
                                          ),
                                        ),
                                        cardMenuButton(
                                          onTap: () {
                                            if (publicKey != null &&
                                                userId.isNotEmpty) {
                                              showDialog(
                                                context: context,
                                                builder: (context) =>
                                                    AlertDialog(
                                                  title:
                                                      const Text("My QR Code"),
                                                  content: SizedBox(
                                                    width: 200,
                                                    height: 200,
                                                    child: QrImageView(
                                                      data: generateQRData(
                                                          userId, publicKey!),
                                                      version: QrVersions.auto,
                                                      size: 200,
                                                    ),
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                              context),
                                                      child:
                                                          const Text("Close"),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            } else {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                const SnackBar(
                                                    content: Text(
                                                        "Profile not initialized")),
                                              );
                                            }
                                          },
                                          title: "My QR Code",
                                          icon: const Icon(
                                            Icons.qr_code,
                                            size: 40,
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: "Share",
        onPressed: () {},
        child: const Icon(
          Icons.share,
          color: Colors.indigo,
          size: 30,
        ),
      ),
    );
  }
}

Widget messageCard(BuildContext context, List<Map<String, dynamic>> msglist,
    Function deleteFun, RSAPrivateKey? privateKey) {
  return ListView.builder(
    itemCount: msglist.length,
    itemBuilder: (context, index) {
      String decryptedMessage = 'Error decrypting message';
      if (privateKey != null) {
        try {
          decryptedMessage = decryptText(msglist[index]['message'], privateKey);
        } catch (e) {
          decryptedMessage = 'Failed to decrypt: $e';
        }
      }
      return GestureDetector(
        onTap: () => showMsgPopup(
          context,
          decryptedMessage,
          msglist[index]['messageId'],
          deleteFun,
          msglist[index]['senderId'],
        ),
        child: Card(
          elevation: 4,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          color: const Color.fromARGB(255, 102, 160, 207),
          child: ListTile(
            leading: const Icon(Icons.message, color: Colors.white),
            title: Text(
              msglist[index]['senderId'] ?? 'Unknown',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              decryptedMessage.length > 20
                  ? '${decryptedMessage.substring(0, 20)}...'
                  : decryptedMessage,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    },
  );
}

void showMsgPopup(BuildContext context, String msg, String msgId,
    Function deleteFun, String? senderId) {
  showDialog(
    context: context,
    builder: (context) {
      Future.delayed(const Duration(seconds: 5), () {
        deleteFun(msgId);
        Navigator.of(context).pop();
      });
      return AlertDialog(
        title: Text(senderId ?? 'Unknown'),
        content: SingleChildScrollView(child: Text(msg)),
        actions: [
          TextButton(
            child: const Text('Delete'),
            onPressed: () {
              deleteFun(msgId);
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}

Widget cardMenuButton({
  required String title,
  required Widget icon,
  VoidCallback? onTap,
  Color fontColor = Colors.white70,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 140,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.2),
            spreadRadius: 2,
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: fontColor,
              fontSize: 14,
            ),
          ),
        ],
      ),
    ),
  );
}
