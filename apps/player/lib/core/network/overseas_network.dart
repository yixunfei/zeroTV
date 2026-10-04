import 'dart:io';

import 'package:iptv_core/iptv_core.dart';

/// Returns true when a stream host is likely outside a local Chinese route.
/// This is a low-level classification helper; the player uses the channel
/// metadata based [needsOverseasNetworkHint] below for user-facing prompts.
bool isLikelyOverseasStream(String streamUrl) {
  final uri = Uri.tryParse(streamUrl);
  final host = uri?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;
  if (host == 'localhost' || host.endsWith('.cn') || host.endsWith('.中国')) {
    return false;
  }
  final address = InternetAddress.tryParse(host);
  if (address != null && _isPrivate(address)) return false;
  if (!(uri!.isScheme('http') || uri.isScheme('https'))) return false;
  final labels = host.split('.');
  if (labels.length < 2) return false;
  final tld = labels.last;
  return _overseasTlds.contains(tld);
}

/// Returns whether the channel is explicitly in the international source
/// group. Hostnames are intentionally ignored because domestic channels can
/// be delivered by globally routed CDNs.
bool needsOverseasNetworkHint(Channel channel) {
  final group = channel.groupTitle?.trim().toLowerCase();
  return group == '国际' || group?.startsWith('国际 ·') == true;
}

const _overseasTlds = <String>{
  'au',
  'ca',
  'ch',
  'de',
  'es',
  'fr',
  'hk',
  'ie',
  'in',
  'it',
  'jp',
  'kr',
  'my',
  'nl',
  'nz',
  'ph',
  'pl',
  'ru',
  'sg',
  'tw',
  'uk',
  'us',
};

bool _isPrivate(InternetAddress address) {
  if (address.type == InternetAddressType.IPv4) {
    final octets = address.address.split('.').map(int.parse).toList();
    return octets[0] == 10 ||
        (octets[0] == 172 && octets[1] >= 16 && octets[1] <= 31) ||
        (octets[0] == 192 && octets[1] == 168) ||
        octets[0] == 127;
  }
  return address.address == '::1' ||
      address.address.startsWith('fc') ||
      address.address.startsWith('fd') ||
      address.address.startsWith('fe80:');
}
