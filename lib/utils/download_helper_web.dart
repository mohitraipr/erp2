import 'dart:convert';
import 'dart:js_util' as js_util;
import 'dart:typed_data';

Future<bool> saveCsvToDevice(String filename, String content) async {
  final bytes = Uint8List.fromList(utf8.encode(content));
  final blob = js_util.callConstructor(
    js_util.getProperty(js_util.globalThis, 'Blob'),
    [
      <Object>[bytes.buffer],
      js_util.jsify({'type': 'text/csv'}),
    ],
  );
  final url = js_util.callMethod(
    js_util.getProperty(js_util.globalThis, 'URL'),
    'createObjectURL',
    [blob],
  ) as String;

  final Object document =
      js_util.getProperty(js_util.globalThis, 'document');
  final Object anchor = js_util.callMethod(document, 'createElement', ['a']);
  js_util.setProperty(anchor, 'href', url);
  js_util.setProperty(anchor, 'download', filename);
  final style = js_util.getProperty(anchor, 'style');
  js_util.setProperty(style, 'display', 'none');

  final Object? body = js_util.getProperty(document, 'body');
  if (body != null) {
    js_util.callMethod(body, 'appendChild', [anchor]);
    js_util.callMethod(anchor, 'click', []);
    js_util.callMethod(body, 'removeChild', [anchor]);
  } else {
    js_util.callMethod(anchor, 'click', []);
  }

  js_util.callMethod(
    js_util.getProperty(js_util.globalThis, 'URL'),
    'revokeObjectURL',
    [url],
  );
  return true;
}
