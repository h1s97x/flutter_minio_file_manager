import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:universal_html/html.dart' as html;

class WebFilePicker {
  static final WebFilePicker _instance = WebFilePicker._internal();
  factory WebFilePicker() => _instance;
  WebFilePicker._internal();
  
  Future<Map<String, dynamic>?> pickFile() async {
    if (!kIsWeb) return null;
    
    final completer = Completer<Map<String, dynamic>?>();
    
    // 创建一个隐藏的文件输入元素
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = '*/*'
      ..multiple = false
      ..style.display = 'none';
    
    // 添加到DOM
    html.document.body?.append(input);
    
    // 监听文件选择
    input.onChange.listen((event) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final file = files[0];
        final reader = html.FileReader();
        
        reader.onLoad.listen((event) {
          // 获取文件内容
          final result = reader.result;
          if (result is Uint8List) {
            completer.complete({
              'name': file.name,
              'size': file.size,
              'bytes': result,
              'type': file.type,
            });
          } else {
            completer.completeError('无法读取文件内容');
          }
          
          // 清理DOM
          input.remove();
        });
        
        reader.onError.listen((event) {
          completer.completeError('读取文件失败: ${reader.error}');
          input.remove();
        });
        
        // 读取文件为ArrayBuffer
        reader.readAsArrayBuffer(file);
      } else {
        completer.complete(null); // 用户取消了选择
        input.remove();
      }
    });
    
    // 触发文件选择对话框
    input.click();
    
    return completer.future;
  }
  
  // 新增多文件选择方法
  Future<List<Map<String, dynamic>>?> pickFiles() async {
    if (!kIsWeb) return null;
    
    final completer = Completer<List<Map<String, dynamic>>?>();
    
    // 创建一个隐藏的文件输入元素，允许多选
    final html.FileUploadInputElement input = html.FileUploadInputElement()
      ..accept = '*/*'
      ..multiple = true
      ..style.display = 'none';
    
    // 添加到DOM
    html.document.body?.append(input);
    
    // 监听文件选择
    input.onChange.listen((event) async {
      final files = input.files;
      if (files != null && files.isNotEmpty) {
        final result = <Map<String, dynamic>>[];
        final futures = <Future>[];
        
        for (var i = 0; i < files.length; i++) {
          final file = files[i];
          final completer = Completer();
          futures.add(completer.future);
          
          final reader = html.FileReader();
          
          reader.onLoad.listen((event) {
            // 获取文件内容
            final fileData = reader.result;
            if (fileData is Uint8List) {
              result.add({
                'name': file.name,
                'size': file.size,
                'bytes': fileData,
                'type': file.type,
              });
              completer.complete();
            } else {
              completer.completeError('无法读取文件内容');
            }
          });
          
          reader.onError.listen((event) {
            completer.completeError('读取文件失败: ${reader.error}');
          });
          
          // 读取文件为ArrayBuffer
          reader.readAsArrayBuffer(file);
        }
        
        try {
          // 等待所有文件读取完成
          await Future.wait(futures);
          completer.complete(result);
        } catch (e) {
          completer.completeError('读取文件失败: $e');
        } finally {
          // 清理DOM
          input.remove();
        }
      } else {
        completer.complete(null); // 用户取消了选择
        input.remove();
      }
    });
    
    // 触发文件选择对话框
    input.click();
    
    return completer.future;
  }
}