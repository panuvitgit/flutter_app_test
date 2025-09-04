import 'package:flutter/material.dart';

class VideoStreamingPage extends StatelessWidget {
  const VideoStreamingPage({super.key});

  @override
  Widget build(BuildContext context) {
    // ลิสต์ชื่อวิดีโอ mockup
    final List<String> recordedVideos = [
      'Record 1',
      'Record 2',
      'Record 3',
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Video Monitoring'),
        backgroundColor: const Color.fromRGBO(86, 3, 229, 1),
      ),
      body: Column(
        children: [
          // LIVE VIEW AREA (mock)
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              color: Colors.black,
              alignment: Alignment.center,
              child: const Text(
                'LIVE STREAM HERE',
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
            ),
          ),

          const Divider(),

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
                    // ยังไม่ทำอะไรตอนนี้ (mockup เฉย ๆ)
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