import 'package:flutter/material.dart';
import 'package:flutter_mjpeg/flutter_mjpeg.dart'; // ✅ สำคัญ

class VideoStreamingPage extends StatelessWidget {
  const VideoStreamingPage({super.key});

  final String streamUrl =
      'http://10.110.38.217:81/stream'; // เปลี่ยนตาม IP จริง

  @override
  Widget build(BuildContext context) {
    final List<String> recordedVideos = ['Record 1', 'Record 2', 'Record 3'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Monitoring'),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // LIVE VIEW AREA
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              child: Mjpeg(
                stream: streamUrl,
                isLive: true,
                fit: BoxFit.cover,
                error: (context, error, stackTrace) {
                  return const Center(
                    child: Text(
                      'ไม่สามารถโหลดภาพจากกล้องได้',
                      style: TextStyle(color: Colors.white),
                    ),
                  );
                },
                loading: (context) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // RECORDED VIDEO LIST
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: recordedVideos.length,
              itemBuilder: (context, index) {
                return ListTile(
                  leading: const Icon(Icons.videocam),
                  title: Text(recordedVideos[index]),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('ยังไม่ได้เชื่อมต่อวิดีโอย้อนหลัง'),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
