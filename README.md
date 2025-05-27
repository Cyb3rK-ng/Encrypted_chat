# Encrypted_chat - Secure Communication App

<div align="center">

[![Flutter](https://img.shields.io/badge/Flutter-3.5.4-blue)](https://flutter.dev)
[![License](https://img.shields.io/badge/License-MIT-green)](LICENSE)

End-to-end encrypted messaging with RSA-2048 and AES-CBC

</div>

## Core Tech Stack

- **Encryption**: RSA-2048 (key exchange) + AES-CBC (message encryption)
- **Storage**: Hive (encrypted local) + Firebase (cloud sync)
- **Auth**: QR-based key exchange + Anonymous IDs
- **Platform**: Flutter (Android/iOS)

## Key Features

- 🔐 End-to-end encryption with perfect forward secrecy
- 🔑 Secure key exchange via QR codes
- 💾 Encrypted local storage with cloud backup
- 👤 Anonymous user system with random nicknames
- 📱 Cross-platform with Material Design 3

## Quick Start

```bash
# Clone & Setup
git clone https://github.com/Sd-Shiivam/Encrypted_chat.git
cd Encrypted_chat
flutter pub get

# Run
flutter run
```

## Dependencies

```yaml
dependencies:
  pointycastle: ^3.9.1 # RSA/AES crypto
  encrypt: ^5.0.1 # AES implementation
  hive: ^2.2.3 # Encrypted storage
  firebase_core: ^2.4.0 # Backend
  cloud_firestore: ^4.3.0 # Database
  qr_flutter: ^4.0.0 # QR generation
  mobile_scanner: ^6.0.10 # QR scanning
```

## Security Implementation

- RSA-2048 for secure key exchange
- AES-CBC with unique session keys
- Fortuna secure random generation
- Encrypted local storage (Hive)
- Private keys never leave device
- Secure cloud sync (Firebase)

## Development

```bash
# Setup
flutter pub get

# Code run
flutter run
# Test
flutter test
```

## License

MIT License - See [LICENSE](LICENSE)

---

<div align="center">
Built with ❤️ by P42 Team
</div>
