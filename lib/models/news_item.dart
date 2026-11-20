import 'dart:convert';

class NewsItem {
  const NewsItem({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.contentHtml,
    required this.plainBody,
    required this.imageUrl,
    required this.dateIso,
    required this.linkUrl,
    required this.isInternal,
  });

  final String id;
  final String title;
  final String excerpt;
  final String contentHtml;
  final String plainBody;
  final String imageUrl;
  final String dateIso;
  final String linkUrl;
  final bool isInternal;

  String get displayDate {
    final parsed = DateTime.tryParse(dateIso);
    if (parsed == null) return dateIso;
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = parsed.toLocal();
    return '${local.day.toString().padLeft(2, '0')} ${months[local.month - 1]} ${local.year}';
  }

  factory NewsItem.fromWordPress(Map<String, dynamic> json) {
    final rawTitle = (json['title'] is Map)
        ? (json['title']['rendered'] ?? '').toString()
        : (json['title'] ?? '').toString();
    final rawContent = (json['content'] is Map)
        ? (json['content']['rendered'] ?? '').toString()
        : (json['content'] ?? '').toString();
    final rawExcerpt = (json['excerpt'] is Map)
        ? (json['excerpt']['rendered'] ?? '').toString()
        : (json['excerpt'] ?? '').toString();

    final mediaId = json['featured_media'];
    var thumb = '';
    if (mediaId != null && mediaId.toString() != '0' && mediaId.toString().isNotEmpty) {
      thumb = 'https://bungtemin.net/btapi/img/thumb/$mediaId';
    } else {
      thumb = _extractFirstImage(rawContent);
    }

    final cleanBody = _htmlToReadableText(rawContent);
    final cleanExcerpt = _htmlToReadableText(
      rawExcerpt.isNotEmpty ? rawExcerpt : rawContent,
    );

    return NewsItem(
      id: (json['id'] ?? '').toString(),
      title: _decodeHtmlEntities(_stripTags(rawTitle)).trim(),
      excerpt: cleanExcerpt.length > 150
          ? '${cleanExcerpt.substring(0, 150).trim()}...'
          : cleanExcerpt,
      contentHtml: rawContent,
      plainBody: cleanBody,
      imageUrl: thumb,
      dateIso: (json['modified'] ?? json['date'] ?? '').toString(),
      linkUrl: (json['link'] ?? '').toString(),
      isInternal: true,
    );
  }

  factory NewsItem.fromBlogger(Map<String, dynamic> json) {
    final rawTitle = (json['title'] ?? '').toString();
    final rawContent = (json['content'] ?? '').toString();
    var thumb = (json['image_url'] ?? '').toString();
    if (thumb.isEmpty && json['images'] is List && (json['images'] as List).isNotEmpty) {
      final first = (json['images'] as List).first;
      if (first is Map && first['url'] != null) {
        thumb = first['url'].toString();
      }
    }
    if (thumb.isEmpty) {
      thumb = _extractFirstImage(rawContent);
    }

    final cleanBody = _htmlToReadableText(rawContent);

    return NewsItem(
      id: (json['id'] ?? '').toString(),
      title: _decodeHtmlEntities(_stripTags(rawTitle)).trim(),
      excerpt: cleanBody.length > 150
          ? '${cleanBody.substring(0, 150).trim()}...'
          : cleanBody,
      contentHtml: rawContent,
      plainBody: cleanBody,
      imageUrl: thumb,
      dateIso: (json['published'] ?? json['updated'] ?? '').toString(),
      linkUrl: (json['url'] ?? '').toString(),
      isInternal: false,
    );
  }

  static String _extractFirstImage(String html) {
    final match = RegExp(
      r'''<img[^>]+src=["']([^"']+)["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return match?.group(1) ?? '';
  }

  static String _stripTags(String input) {
    return input.replaceAll(RegExp(r'<[^>]*>'), ' ');
  }

  static String _htmlToReadableText(String html) {
    var text = html
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(p|div|h1|h2|h3|h4|li|tr)>', caseSensitive: false), '\n\n')
        .replaceAll(RegExp(r'<li[^>]*>', caseSensitive: false), '• ')
        .replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = _decodeHtmlEntities(text);
    text = text
        .replaceAll(RegExp(r'[ \t]+\n'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t]{2,}'), ' ')
        .trim();
    return text;
  }

  static String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#8211;', '–')
        .replaceAll('&#8212;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&mdash;', '—')
        .replaceAll('&#8216;', '‘')
        .replaceAll('&#8217;', '’')
        .replaceAll('&#8220;', '“')
        .replaceAll('&#8221;', '”')
        .replaceAll('&#8230;', '...');
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'excerpt': excerpt,
        'contentHtml': contentHtml,
        'plainBody': plainBody,
        'imageUrl': imageUrl,
        'dateIso': dateIso,
        'linkUrl': linkUrl,
        'isInternal': isInternal,
      };

  factory NewsItem.fromCacheJson(Map<String, dynamic> json) => NewsItem(
        id: (json['id'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        excerpt: (json['excerpt'] ?? '').toString(),
        contentHtml: (json['contentHtml'] ?? '').toString(),
        plainBody: (json['plainBody'] ?? '').toString(),
        imageUrl: (json['imageUrl'] ?? '').toString(),
        dateIso: (json['dateIso'] ?? '').toString(),
        linkUrl: (json['linkUrl'] ?? '').toString(),
        isInternal: json['isInternal'] == true,
      );

  static String encodeList(List<NewsItem> items) =>
      jsonEncode(items.map((e) => e.toJson()).toList());

  static List<NewsItem> decodeList(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((e) => NewsItem.fromCacheJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }
}
