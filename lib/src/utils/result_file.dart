import '../services/api_service.dart';

class ResultFile {
  final String url;
  final ResultFileKind kind;

  const ResultFile({required this.url, required this.kind});

  factory ResultFile.fromUrl(String raw) {
    final url = _absoluteUrl(raw);
    return ResultFile(url: url, kind: kindFromUrl(url));
  }

  static String _absoluteUrl(String url) {
    if (url.startsWith('http')) return url;
    if (url.startsWith('/')) return '${ApiService.baseUrl}$url';
    return '${ApiService.baseUrl}/$url';
  }

  static ResultFileKind kindFromUrl(String url) {
    final path = url.split('?').first.toLowerCase();
    if (path.endsWith('.pdf')) return ResultFileKind.pdf;
    if (path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.heic') ||
        path.endsWith('.bmp')) {
      return ResultFileKind.image;
    }
    return ResultFileKind.other;
  }

  String get extension {
    final path = url.split('?').first;
    final dot = path.lastIndexOf('.');
    if (dot < 0 || dot == path.length - 1) return '';
    return path.substring(dot + 1).toUpperCase();
  }
}

enum ResultFileKind { image, pdf, other }
