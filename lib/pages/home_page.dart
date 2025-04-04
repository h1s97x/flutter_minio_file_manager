// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../services/minio_service.dart';
import '../models/file_item.dart';
import '../pages/file_list_Item.dart';
import '../services/download_service.dart';
import '../services/upload_service.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import '../services/web_upload_helper.dart';
import '../services/web_file_picker.dart';
import 'dart:typed_data';

class HomePage extends StatefulWidget {
  final Function(int)? onPageChange;
  
  const HomePage({
    Key? key,
    this.onPageChange,
  }) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _currentPrefix = '';
  final List<String> _pathStack = [];
  late List<FileItem> files = [];
  bool _isLoading = true;
  int selectedIndex = 0; // 用于切换页面
  
  // 多选相关
  final Set<String> _selectedFiles = {};
  bool _isMultiSelectMode = false;

  @override
  void initState() {
    super.initState();
    _initializeMinIO();
  }

  Future<void> _initializeMinIO() async {
    setState(() => _isLoading = true);
    try {
      await MinioService().initialize();
      await _refreshObjects();
    } catch (e) {
      _showErrorDialog('初始化失败', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _refreshObjects() async {
    try {
      final fileNames = await MinioService().getFiles();
      setState(() {
        files = fileNames.map((name) => FileItem(
          name: name,
          size: 0, // 这里可以通过 statObject 获取实际大小
          type: name.contains('.') ? name.split('.').last : null,
        )).toList();
        
        // 刷新时清除选择
        if (_isMultiSelectMode) {
          _toggleMultiSelectMode();
        }
      });
    } catch (e) {
      _showErrorDialog('获取文件列表失败', e.toString());
    }
  }

  // 切换多选模式
  void _toggleMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = !_isMultiSelectMode;
      if (!_isMultiSelectMode) {
        _selectedFiles.clear();
      }
    });
  }

  // 选择或取消选择文件
  void _toggleFileSelection(String fileName) {
    setState(() {
      if (_selectedFiles.contains(fileName)) {
        _selectedFiles.remove(fileName);
      } else {
        _selectedFiles.add(fileName);
      }
      
      // 如果没有选中的文件，退出多选模式
      if (_selectedFiles.isEmpty && _isMultiSelectMode) {
        _isMultiSelectMode = false;
      }
    });
  }

  // 下载选中的文件
  void _downloadSelectedFiles() {
    if (_selectedFiles.isEmpty) return;
    
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    
    for (final fileName in _selectedFiles) {
      downloadService.enqueueDownload(fileName);
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已将 ${_selectedFiles.length} 个文件加入下载队列'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // 切换到下载队列页面
    if (widget.onPageChange != null) {
      widget.onPageChange!(2); // 下载队列页面索引
    }
    
    // 退出多选模式
    _toggleMultiSelectMode();
  }

  // 删除选中的文件
  void _deleteSelectedFiles() async {
    if (_selectedFiles.isEmpty) return;
    
    // 确认删除
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('确认删除'),
        content: Text('确定要删除选中的 ${_selectedFiles.length} 个文件吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('删除'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    // 执行删除
    setState(() => _isLoading = true);
    
    int successCount = 0;
    List<String> failedFiles = [];
    
    for (final fileName in _selectedFiles) {
      try {
        await MinioService().deleteFile(fileName);
        successCount++;
      } catch (e) {
        print('删除文件失败: $fileName, 错误: $e');
        failedFiles.add(fileName);
      }
    }
    
    // 刷新文件列表
    await _refreshObjects();
    
    setState(() => _isLoading = false);
    
    // 显示结果
    if (failedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('成功删除 $successCount 个文件'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _showErrorDialog(
        '部分文件删除失败',
        '成功: $successCount 个\n失败: ${failedFiles.length} 个\n${failedFiles.join('\n')}',
      );
    }
    
    // 退出多选模式
    _toggleMultiSelectMode();
  }

  Future<void> _uploadFile() async {
    try {
      print('开始选择文件...');
      
      if (kIsWeb) {
        // Web平台使用自定义文件选择器支持多文件
        final filesData = await WebFilePicker().pickFiles();
        
        if (filesData != null && filesData.isNotEmpty) {
          print('Web平台: 选择了 ${filesData.length} 个文件');
          
          int successCount = 0;
          
          // 直接上传所有文件
          for (final fileData in filesData) {
            final fileName = fileData['name'] as String;
            final fileSize = fileData['size'] as int;
            final fileBytes = fileData['bytes'] as Uint8List;
            
            print('Web平台: 处理文件: $fileName, 大小: $fileSize 字节');
            
            try {
              // 直接上传文件
              final etag = await MinioService().uploadWebFile(fileName, fileBytes, (progress) {
                print('上传进度: ${(progress * 100).toStringAsFixed(2)}%');
              });
              
              print('文件上传成功，etag: $etag');
              successCount++;
            } catch (e) {
              print('文件上传失败: $e');
              // 继续上传其他文件
            }
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('成功上传 $successCount/${filesData.length} 个文件'),
              duration: Duration(seconds: 2),
            ),
          );
          
          // 刷新文件列表
          await _refreshObjects();
        } else {
          print('Web平台: 用户取消了文件选择');
        }
      } else {
        // 移动端或桌面端使用FilePicker支持多文件
        final result = await FilePicker.platform.pickFiles(allowMultiple: true);
        
        if (result != null && result.files.isNotEmpty) {
          print('选择了 ${result.files.length} 个文件');
          
          final uploadService = Provider.of<UploadService>(context, listen: false);
          int validFiles = 0;
          
          for (final file in result.files) {
            if (file.path != null) {
              print('处理文件: ${file.name}, 大小: ${file.size} 字节');
              uploadService.enqueueUpload(file.path!);
              validFiles++;
            }
          }
          
          if (validFiles > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('已将 $validFiles 个文件加入上传队列'),
                duration: Duration(seconds: 2),
              ),
            );
            
            // 自动切换到上传队列页面
            if (widget.onPageChange != null) {
              widget.onPageChange!(1); // 切换到上传队列页面
            }
          } else {
            _showErrorDialog('上传失败', '无法获取文件路径');
          }
        } else {
          print('用户取消了文件选择');
        }
      }
    } catch (e) {
      print('文件选择/上传过程中出错: $e');
      _showErrorDialog('上传失败', e.toString());
    }
  }

  Future<void> _downloadFile(String fileName) async {
    final downloadService = Provider.of<DownloadService>(context, listen: false);
    downloadService.enqueueDownload(fileName);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('文件已加入下载队列: $fileName'),
        duration: Duration(seconds: 2),
      ),
    );
    
    // 自动切换到下载队列页面
    if (widget.onPageChange != null) {
      widget.onPageChange!(2); // 切换到下载队列页面
    }
  }

  Future<void> _deleteFile(String fileName) async {
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('确认删除'),
          content: Text('确定要删除文件 "$fileName" 吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('删除'),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            ),
          ],
        ),
      );
      
      if (confirmed == true) {
        await MinioService().deleteFile(fileName);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('文件已删除: $fileName'),
            duration: Duration(seconds: 2),
          ),
        );
        
        await _refreshObjects();
      }
    } catch (e) {
      _showErrorDialog('删除失败', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('MinIO 文件管理器'),
        actions: [
          // 多选模式切换按钮
          IconButton(
            icon: Icon(_isMultiSelectMode ? Icons.cancel : Icons.select_all),
            onPressed: _toggleMultiSelectMode,
            tooltip: _isMultiSelectMode ? '取消多选' : '多选模式',
          ),
          // 多选模式下的操作按钮
          if (_isMultiSelectMode && _selectedFiles.isNotEmpty) ...[
            IconButton(
              icon: Icon(Icons.download),
              onPressed: _downloadSelectedFiles,
              tooltip: '下载选中文件',
            ),
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: _deleteSelectedFiles,
              tooltip: '删除选中文件',
            ),
          ],
          // 刷新按钮
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _refreshObjects,
            tooltip: '刷新',
          ),
          if (kIsWeb)
            IconButton(
              icon: Icon(Icons.bug_report),
              onPressed: _debugWebUpload,
              tooltip: '调试Web上传',
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? Center(child: Text('没有文件'))
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    final file = files[index];
                    final isSelected = _selectedFiles.contains(file.name);
                    
                    return ListTile(
                      leading: _isMultiSelectMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleFileSelection(file.name),
                            )
                          : Icon(Icons.insert_drive_file),
                      title: Text(file.name),
                      subtitle: Text(file.type ?? '未知类型'),
                      onTap: _isMultiSelectMode
                          ? () => _toggleFileSelection(file.name)
                          : null,
                      trailing: _isMultiSelectMode
                          ? null
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.download),
                                  onPressed: () => _downloadFile(file.name),
                                  tooltip: '下载',
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete),
                                  onPressed: () => _deleteFile(file.name),
                                  tooltip: '删除',
                                ),
                              ],
                            ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _uploadFile,
        tooltip: '上传文件',
        child: Icon(Icons.upload_file),
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String error) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(error),
          actions: <Widget>[
            TextButton(
              child: Text('确定'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // 添加调试方法
  // void _debugWebUpload() async {
  //   try {
  //     final bytes = Uint8List.fromList(List.generate(1024, (index) => index % 256));
  //     final fileName = 'debug_file.bin';
      
  //     print('调试Web上传: 创建测试文件，大小: ${bytes.length} 字节');
      
  //     // 保存文件字节
  //     WebUploadHelper().saveFileBytes(bytes);
      
  //     // 使用UploadService进行上传
      // final uploadService = Provider.of<UploadService>(context, listen: false);
      // uploadService.enqueueUpload(fileName);
      
  //     ScaffoldMessenger.of(context).showSnackBar(
  //       SnackBar(
  //         content: Text('调试文件已加入上传队列'),
  //         duration: Duration(seconds: 2),
  //       ),
  //     );
      
  //     // 自动切换到上传队列页面
  //     if (widget.onPageChange != null) {
  //       widget.onPageChange!(1);
  //     }
  //   } catch (e) {
  //     print('创建调试文件失败: $e');
  //     _showErrorDialog('上传失败', e.toString());
  //   }
  // }
// 添加调试方法
void _debugWebUpload() async {
  try {
    final bytes = Uint8List.fromList(List.generate(1024, (index) => index % 256));
    final fileName = 'debug_file.bin';
    
    print('调试Web上传: 创建测试文件，大小: ${bytes.length} 字节');
    
    // 保存文件字节
    WebUploadHelper().saveFileBytes(bytes);
    
    try {
      // 直接上传文件
      final etag = await MinioService().uploadWebFile(fileName, bytes, (progress) {
        print('上传进度: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // final uploadService = Provider.of<UploadService>(context, listen: false);
      // uploadService.enqueueUpload(fileName);
      
      print('调试文件上传成功，etag: $etag');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('调试文件上传成功'),
          duration: Duration(seconds: 2),
        ),
      );
      
      // 刷新文件列表
      await _refreshObjects();
    } catch (e) {
      print('调试文件上传失败: $e');
      _showErrorDialog('上传失败', e.toString());
    }
  } catch (e) {
    print('创建调试文件失败: $e');
    _showErrorDialog('上传失败', e.toString());
  }
}
}

