import 'dart:async';
import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:intl/intl.dart';
import 'package:minio/minio.dart';
import 'package:universal_html/html.dart' as html;
import '../services/minio_service.dart';
import '../config.dart';
import '../models/file_task.dart';
import '../services/web_upload_helper.dart';

/// 上传文件记录
class UploadRecord {
  String fileName;
  String uploadStatus;
  String uploadMessage;
  String uploadTime;
  double uploadProgress;

  UploadRecord({
    required this.fileName,
    required this.uploadStatus,
    required this.uploadMessage,
    required this.uploadTime,
    this.uploadProgress = 0.0,
  });
}

/// 文件上传服务
class UploadService extends ChangeNotifier {
  // 单例模式
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;
  UploadService._internal();

  final List<UploadRecord> _uploadRecords = [];
  final List<FileTask> _uploadQueue = [];
  int _activeUploads = 0;
  final int _maxConcurrent = MinioConfig.maxConcurrent;

  List<UploadRecord> get uploadRecords => _uploadRecords;

  void addRecord(UploadRecord record) {
    // 检查是否已存在相同文件名的记录
    final existingIndex = _uploadRecords.indexWhere((r) => r.fileName == record.fileName);
    
    if (existingIndex >= 0) {
      // 更新现有记录
      _uploadRecords[existingIndex] = record;
    } else {
      // 添加新记录
      _uploadRecords.add(record);
    }
    
    notifyListeners();
  }

  void clearRecords() {
    _uploadRecords.clear();
    notifyListeners();
  }

  /// 将文件加入上传队列
  void enqueueUpload(String filePath) {
    final task = FileTask.createUploadTask(
      filePath: filePath,
      onCompleted: () {
        print("Upload completed: $filePath");
      },
      onProgress: (progress) {
        print("Upload progress: $progress");
      },
      onError: (error) {
        print("Upload error: $error");
      },
    );
    
    _uploadQueue.add(task);
    _processQueue();
  }

  void _processQueue() {
    while (_activeUploads < _maxConcurrent && _uploadQueue.isNotEmpty) {
      final task = _uploadQueue.removeAt(0);
      _activeUploads++;
      _startUpload(task);
    }
  }

  Future<void> _startUpload(FileTask task) async {
    String fileName = path.basename(task.filePath);
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

    UploadRecord uploadHistory = UploadRecord(
      fileName: fileName,
      uploadStatus: "正在上传",
      uploadMessage: "",
      uploadTime: formattedDate,
      uploadProgress: 0.0,
    );

    addRecord(uploadHistory);
    notifyListeners(); // 确保立即显示上传记录

    try {
      // 监听上传进度
      MinioService().uploadProgress(fileName).listen((progress) {
        updateFileProgress(fileName, progress);
        if (task.onProgress != null) {
          task.onProgress!('${(progress * 100).toStringAsFixed(2)}%');
        }
      });

      String? etag;
      
      if (kIsWeb) {
        // Web平台特殊处理
        etag = await _uploadFileForWeb(fileName, task.filePath, (progress) {
          updateFileProgress(fileName, progress);
          if (task.onProgress != null) {
            task.onProgress!('${(progress * 100).toStringAsFixed(2)}%');
          }
        });
      } else {
        // 移动端或桌面端上传
        etag = await MinioService().uploadFile(fileName, task.filePath);
      }
      
      if (etag != null && etag.isNotEmpty) {
        uploadHistory.uploadStatus = "成功";
        uploadHistory.uploadMessage = "文件上传成功: $etag";
        uploadHistory.uploadProgress = 1.0;
        
        if (task.onCompleted != null) {
          task.onCompleted!();
        }
      } else {
        uploadHistory.uploadStatus = "失败";
        uploadHistory.uploadMessage = "文件上传失败: 未收到有效响应";
        
        if (task.onError != null) {
          task.onError!("上传失败: 未收到有效响应");
        }
      }
    } catch (e) {
      print('上传过程中出错: $e');
      uploadHistory.uploadStatus = "失败";
      uploadHistory.uploadMessage = "文件上传失败: $e";
      if (task.onError != null) {
        task.onError!(e.toString());
      }
    }

    _uploadCompleted();
    notifyListeners();
  }

  // Web平台专用上传方法
  Future<String?> _uploadFileForWeb(String fileName, String filePath, Function(double) onProgress) async {
    if (!kIsWeb) return null;
    
    try {
      print('准备上传Web文件: $fileName');
      
      // 从WebUploadHelper获取文件字节
      final fileBytes = WebUploadHelper().getLastFileBytes();
    //   final fileBytes = WebUploadHelper().getFileBytes(fileName);
      if (fileBytes == null) {
        print('无法获取文件数据，文件名: $fileName');
        throw Exception('无法读取文件数据');
      }
      
      print('获取到文件数据，大小: ${fileBytes.length} 字节');
      
      // 使用MinioService上传二进制数据
      final etag = await MinioService().uploadWebFile(fileName, fileBytes, onProgress);
      print('文件上传成功，etag: $etag');
      
      // 上传成功后清除缓存的文件数据
      WebUploadHelper().clearFileBytes(fileName);
      
      return etag;
    } catch (e) {
      print('Web上传文件失败: $e');
      rethrow;
    }
  }
  
  // 从Web文件路径获取字节数据
  Future<Uint8List?> _getWebFileBytes(String filePath) async {
    if (!kIsWeb) return null;
    return WebUploadHelper().getLastFileBytes();
  }

  void _uploadCompleted() {
    _activeUploads--;
    _processQueue();
  }

  Future<String> computeFileHash(String path) async {
    if (kIsWeb) {
      // Web平台使用简单哈希
      return DateTime.now().millisecondsSinceEpoch.toString();
    } else {
      final bytes = await File(path).readAsBytes();
      final digest = sha256.convert(bytes);
      return digest.toString();
    }
  }

  Future<bool> _checkFileExists(String fileHash) async {
    try {
      // 检查文件是否存在
      await MinioService().statObject(fileHash);
      return true;
    } catch (e) {
      return false;
    }
  }

  void updateFileProgress(String fileName, double progress) {
    for (var file in _uploadRecords) {
      if (file.fileName == fileName) {
        file.uploadProgress = progress;
        notifyListeners();
        break;
      }
    }
  }
} 