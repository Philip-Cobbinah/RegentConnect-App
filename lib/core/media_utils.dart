class MediaUtils {
  static String sanitizeFileName(String value, {String fallback = 'file'}) {
    final sanitized = value.trim().replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
    return sanitized.isEmpty ? fallback : sanitized;
  }

  static String contentTypeForName(String fileName, {String? fallback}) {
    final extension = fileName.toLowerCase().split('.').last;
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'webm':
        return 'video/webm';
      case 'm4a':
        return 'audio/mp4';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'ogg':
        return 'audio/ogg';
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
        return 'application/vnd.ms-excel';
      case 'xlsx':
        return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'txt':
        return 'text/plain';
      default:
        return fallback ?? 'application/octet-stream';
    }
  }

  static String folderForType(String type) {
    switch (type) {
      case 'image':
        return 'images';
      case 'video':
        return 'videos';
      case 'audio':
        return 'audio';
      default:
        return 'files';
    }
  }
}
