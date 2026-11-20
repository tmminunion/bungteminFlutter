class TontonVideo {
  const TontonVideo({
    required this.id,
    required this.videoId,
    required this.title,
    required this.description,
    required this.category,
    this.channelTitle = 'Bungtemin Official',
  });

  final String id;
  final String videoId;
  final String title;
  final String description;
  final String category;
  final String channelTitle;

  String get thumbnailHq =>
      videoId.isNotEmpty ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg' : '';

  String get thumbnailMax => videoId.isNotEmpty
      ? 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg'
      : '';

  String get youtubeUrl =>
      videoId.isNotEmpty ? 'https://youtu.be/$videoId' : 'https://bungtemin.net';

  TontonVideo copyWith({
    String? title,
    String? description,
    String? channelTitle,
  }) {
    return TontonVideo(
      id: id,
      videoId: videoId,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category,
      channelTitle: channelTitle ?? this.channelTitle,
    );
  }

  factory TontonVideo.fromJson(Map<String, dynamic> json) {
    final rawTitle = _stripTags((json['title'] ?? '').toString());
    final rawDesc = _stripTags(
      (json['content'] ?? json['description'] ?? '').toString(),
    );
    final rawCat = (json['category'] ?? json['kategori'] ?? '').toString().trim();
    final inferredCat = rawCat.isNotEmpty ? rawCat : _inferCategory(rawTitle);

    return TontonVideo(
      id: (json['id'] ?? json['playlist_id'] ?? '').toString(),
      videoId: (json['playlist_id'] ?? json['videoId'] ?? json['id'] ?? '')
          .toString()
          .trim(),
      title: rawTitle.isEmpty ? 'Video Bungtemin' : rawTitle,
      description: rawDesc,
      category: inferredCat,
      channelTitle:
          (json['channelTitle'] ?? 'Bungtemin Official').toString().trim(),
    );
  }

  static String _inferCategory(String title) {
    final lower = title.toLowerCase();
    if (lower.contains('mars')) return 'Mars';
    if (lower.contains('sarasehan')) return 'Sarasehan';
    if (lower.contains('spsi') || lower.contains('lem')) return 'SPSI';
    if (lower.contains('tmmin')) return 'TMMIN';
    return 'Edukasi';
  }

  static String _stripTags(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
