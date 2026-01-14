# Noti

Lightweight Nostr notifications - DMs, mentions, zaps, reposts & reactions.

## Features

- **Desktop Notifications** - Receive native Linux notifications for Nostr events
- **Multiple Accounts** - Monitor notifications for multiple Nostr accounts
- **Notification Types**:
  - Direct Messages (NIP-17 encrypted DMs)
  - Mentions
  - Zaps (Lightning payments)
  - Reposts
  - Reactions
- **System Tray** - Runs quietly in your system tray
- **Launch at Startup** - Optional auto-start on login
- **Start Minimized** - Launch directly to tray
- **Notification History** - View past notifications in the app
- **Internationalization** - English and French supported
- **System Theme** - Follows your desktop accent color

## Requirements

- Linux desktop environment
- Flutter SDK 3.10.4+

## Installation

```bash
# Clone the repository
git clone https://github.com/your-username/noti.git
cd noti

# Install dependencies
flutter pub get

# Build
flutter build linux --release

# The executable will be at build/linux/x64/release/bundle/noti
```

## Usage

```bash
# Run normally
./noti

# Run minimized to tray
./noti --minimized
```

## Development

```bash
# Run in debug mode
flutter run -d linux

# Generate localizations
flutter gen-l10n
```

## License

See [LICENSE](LICENSE) file.
