class FileItem {
  final String name;
  final int size;
  final String? type;
  final DateTime? lastModified;
  final bool isDir;

  const FileItem({
    required this.name,
    required this.size,
    this.type,
    this.lastModified,
    this.isDir = false,
  });

  String get displayName => name;
  String get path => name;

  factory FileItem.fromMinioObject(Map<String, dynamic> obj) {
    return FileItem(
      name: obj['name'] as String,
      size: obj['size'] as int,
      type: obj['contentType'] as String?,
      lastModified: obj['lastModified'] as DateTime?,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'size': size,
    'type': type,
    'lastModified': lastModified?.toIso8601String(),
    'isDir': isDir,
  };
}