import 'package:ndk/ndk.dart';

String shortenNpub(String pubkey) {
  final npub = Nip19.encodePubKey(pubkey);
  return '${npub.substring(0, 8)}...${npub.substring(npub.length - 4)}';
}
