import 'dart:io';
import 'package:flutter/foundation.dart';

enum TaskType { upload, download }
enum TaskStatus { queued, inProgress, completed, failed }

class FileTask {
  final String id;
  final TaskType type;
  final String filePath;
  final String remotePath;
  final DateTime createdAt;
  
  TaskStatus status;
  double progress;
  String? error;
  
  Function()? onCompleted;
  Function(String)? onProgress;
  Function(String)? onError;

  FileTask({
    required this.id,
    required this.type,
    required this.filePath,
    required this.remotePath,
    this.onCompleted,
    this.onProgress,
    this.onError,
    this.status = TaskStatus.queued,
    this.progress = 0.0,
    DateTime? createdAt,
  }) : this.createdAt = createdAt ?? DateTime.now();

  String get displayName => remotePath.split('/').last;
  
  // 工厂方法，创建上传任务
  static FileTask createUploadTask({
    required String filePath,
    required Function() onCompleted,
    required Function(String) onProgress,
    required Function(String) onError,
  }) {
    final fileName = filePath.split(Platform.pathSeparator).last;
    return FileTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TaskType.upload,
      filePath: filePath,
      remotePath: fileName,
      onCompleted: onCompleted,
      onProgress: onProgress,
      onError: onError,
    );
  }
  
  // 工厂方法，创建下载任务
  static FileTask createDownloadTask({
    required String fileName,
    required Function() onCompleted,
    required Function(String) onProgress,
    required Function(String) onError,
  }) {
    return FileTask(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: TaskType.download,
      filePath: fileName,
      remotePath: fileName,
      onCompleted: onCompleted,
      onProgress: onProgress,
      onError: onError,
    );
  }
} 