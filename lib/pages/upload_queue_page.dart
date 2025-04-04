import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/upload_service.dart';

class UploadQueuePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final uploadService = Provider.of<UploadService>(context);
    final uploadRecords = uploadService.uploadRecords;

    return Scaffold(
      appBar: AppBar(
        title: Text('上传队列'),
      ),
      body: uploadRecords.isEmpty
          ? Center(child: Text('没有上传任务'))
          : ListView.builder(
              itemCount: uploadRecords.length,
              itemBuilder: (context, index) {
                final file = uploadRecords[index];
                return Card(
                  margin: EdgeInsets.all(8.0),
                  child: Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                file.fileName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              file.uploadStatus,
                              style: TextStyle(
                                color: _getStatusColor(file.uploadStatus),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: file.uploadProgress,
                          backgroundColor: Colors.grey[200],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '上传时间: ${file.uploadTime}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (file.uploadMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              file.uploadMessage,
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case '成功':
        return Colors.green;
      case '失败':
        return Colors.red;
      case '已存在':
        return Colors.orange;
      case '正在上传':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }
} 