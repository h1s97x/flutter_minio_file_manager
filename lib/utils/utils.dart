import 'dart:math';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

Future<String> getDictionaryPath({String? filename}) async {
  // 获取外部存储目录
  final directory = await getExternalStorageDirectory();

  // 检查目录是否为空
  if (directory == null) {
    throw Exception('无法获取外部存储目录');
  }

  // 如果未传入文件名，返回目录路径
  if (filename == null) {
    return directory.path;
  }

  // 拼接文件路径并返回
  final filePath = '${directory.path}/$filename';
  return filePath;
}

/// 格式化文件大小（B/KB/MB/GB）
String formatFileSize(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return "0 B";
  const suffixes = ["B", "KB", "MB", "GB"];
  final i = (log(bytes) / log(1024)).floor();
  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

String formatDate(DateTime date) {
  return DateFormat('yyyy-MM-dd HH:mm').format(date);
}

String getFileName(String path) {
  return path.split('/').last;
}
