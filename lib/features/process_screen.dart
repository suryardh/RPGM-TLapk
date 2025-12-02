import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class ProcessScreen extends StatefulWidget {
  final String path;
  final List<String> keys;
  final Map<String, bool> scope;

  const ProcessScreen({super.key, required this.path, required this.keys, required this.scope});

  @override
  State<ProcessScreen> createState() => _ProcessScreenState();
}

class _ProcessScreenState extends State<ProcessScreen> {
  List<Map<String, String>> logs = []; 
  double progress = 0.0;
  bool finished = false;
  String finalPath = "";
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    startService();
  }

  void startService() {
    final service = FlutterBackgroundService();
    service.startService();
    
    Future.delayed(const Duration(seconds: 1), () {
      service.invoke("startTranslation", {
        "path": widget.path,
        "apiKeys": widget.keys,
        "scope": widget.scope
      });
    });

    service.on('update').listen((event) {
      if (event != null && mounted) {
        setState(() {
          if (event['log'] != null) {
            logs.add({
              "msg": event['log'],
              "status": event['status'] ?? "processing"
            });
            if (_scrollController.hasClients) {
              _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
            }
          }
          if (event['progress'] != null) progress = event['progress'];
        });
      }
    });

    service.on('completed').listen((event) {
      if (mounted) {
        setState(() {
          finished = true;
          finalPath = event?['path'] ?? "";
          logs.add({"msg": "FILE SAVED: $finalPath", "status": "completed"});
        });
      }
    });
  }

  Color getLogColor(String status) {
    if (status == 'error') return Colors.redAccent;
    if (status == 'warning') return Colors.yellowAccent;
    if (status == 'completed') return Colors.greenAccent;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Processing...")),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 8, color: Colors.deepPurpleAccent),
          Expanded(
            child: Container(
              color: const Color(0xFF1E1E1E),
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: logs.length,
                itemBuilder: (ctx, i) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Text(
                      logs[i]['msg']!,
                      style: TextStyle(
                        color: getLogColor(logs[i]['status']!),
                        fontFamily: 'Fira Code', 
                        fontSize: 12
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (finished) 
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green,
              width: double.infinity,
              child: Column(
                children: [
                  const Text("FINISHED", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const SizedBox(height: 5),
                  Text(finalPath, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
                ],
              ),
            )
        ],
      ),
    );
  }
}
