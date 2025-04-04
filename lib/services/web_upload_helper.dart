import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class WebUploadHelper {
  static final WebUploadHelper _instance = WebUploadHelper._internal();
  factory WebUploadHelper() => _instance;
  WebUploadHelper._internal();
  
  // 存储文件数据的映射
  final Map<String, Uint8List> _fileBytes = {};
  
  void saveFileBytes(Uint8List bytes, {String? fileName}) {
    final name = fileName ?? 'file_${DateTime.now().millisecondsSinceEpoch}';
    print('WebUploadHelper: 保存文件字节，文件名: $name, 大小: ${bytes.length}');
    _fileBytes[name] = bytes;
  }
  
  Uint8List? getFileBytes(String fileName) {
    if (!_fileBytes.containsKey(fileName)) {
      print('WebUploadHelper: 找不到文件: $fileName');
      return null;
    }
    print('WebUploadHelper: 返回文件字节，文件名: $fileName, 大小: ${_fileBytes[fileName]!.length}');
    return _fileBytes[fileName];
  }
  
  // 兼容旧代码
  Uint8List? getLastFileBytes() {
    if (_fileBytes.isEmpty) {
      print('WebUploadHelper: 没有保存的文件字节');
      return null;
    }
    final fileName = _fileBytes.keys.last;
    print('WebUploadHelper: 返回最后保存的文件字节，文件名: $fileName, 大小: ${_fileBytes[fileName]!.length}');
    return _fileBytes[fileName];
  }
  
  void clearFileBytes([String? fileName]) {
    if (fileName != null) {
      print('WebUploadHelper: 清除文件字节，文件名: $fileName');
      _fileBytes.remove(fileName);
    } else {
      print('WebUploadHelper: 清除所有文件字节');
      _fileBytes.clear();
    }
  }
  
  // 使用FormData上传文件到MinIO
  Future<bool> uploadFileToMinIO(String url, String fileName, Uint8List bytes) async {
    if (!kIsWeb) return false;
    
    try {
      // 创建FormData
      final formData = html.FormData();
      final blob = html.Blob([bytes]);
      formData.appendBlob('file', blob, fileName);
      
      // 创建XMLHttpRequest
      final request = html.HttpRequest();
      request.open('POST', url);
      
      // 创建进度监听
      final completer = Completer<bool>();
      request.upload.onProgress.listen((event) {
        if (event.lengthComputable) {
          final progress = (event.loaded ?? 0) / (event.total ?? 1);
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        }
      });
      
      request.onLoad.listen((event) {
        if (request.status == 200) {
          completer.complete(true);
        } else {
          completer.completeError('Upload failed with status: ${request.status}');
        }
      });
      
      request.onError.listen((event) {
        completer.completeError('Upload error: $event');
      });
      
      // 发送请求
      request.send(formData);
      
      return await completer.future;
    } catch (e) {
      print('Web upload error: $e');
      return false;
    }
  }
} 