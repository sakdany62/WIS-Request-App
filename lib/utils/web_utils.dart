// lib/utils/web_utils.dart
import 'package:universal_html/html.dart' as html;
import 'dart:typed_data';
import 'dart:convert';

void downloadFileWeb(List<int> fileBytes, String fileName, String mimeType) {
  final base64 = base64Encode(fileBytes);
  final anchor = html.AnchorElement(
    href: 'data:$mimeType;base64,$base64'
  )
    ..setAttribute('download', fileName)
    ..style.display = 'none'
    ..click();
}