import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';
import 'package:intl/intl.dart';

class DownloadQueuePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final downloadService = Provider.of<DownloadService>(context);
    final downloadRecords = downloadService.downloadRecords;

    return Scaffold(
      appBar: AppBar(
        title: Text('下载队列'),
      ),
      body: downloadRecords.isEmpty
          ? Center(child: Text('没有下载任务'))
          : ListView.builder(
              itemCount: downloadRecords.length,
              itemBuilder: (context, index) {
                final file = downloadRecords[index];
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
                              file.downloadStatus,
                              style: TextStyle(
                                color: _getStatusColor(file.downloadStatus),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: file.downloadProgress,
                          backgroundColor: Colors.grey[200],
                        ),
                        SizedBox(height: 4),
                        Text(
                          '下载时间: ${file.downloadTime}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (file.downloadMessage.isNotEmpty)
                          Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Text(
                              file.downloadMessage,
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
      case '正在下载':
        return Colors.blue;
      default:
        return Colors.black;
    }
  }
} 