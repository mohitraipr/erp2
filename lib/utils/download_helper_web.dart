import 'dart:convert';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<bool> saveCsvToDevice(String filename, String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = web.Blob(
    (<Object>[bytes.buffer]) as dynamic,
    web.BlobPropertyBag(type: 'text/csv'),
  );
  final url = web.URL.createObjectURL(blob);

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor
    ..href = url
    ..download = filename
    ..style.display = 'none';

  web.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
