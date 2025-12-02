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
  List<String> logs = [];
  double progress = 0.0;
  bool finished = false;
  String finalPath = "";

  @override
  void initState() {
    super.initState();
    startService();
  }

  void startService() {
    final service = FlutterBackgroundService();
    service.startService();
    
    // Delay biar service siap
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
          if (event['log'] != null) logs.add(event['log']);
          if (event['progress'] != null) progress = event['progress'];
        });
      }
    });

    service.on('completed').listen((event) {
      if (mounted) {
        setState(() {
          finished = true;
          finalPath = event?['path'] ?? "";
          logs.add("✅ FILE SAVED: $finalPath");
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Processing...")),
      body: Column(
        children: [
          LinearProgressIndicator(value: progress, minHeight: 10),
          Expanded(
            child: Container(
              color: Colors.black,
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (ctx, i) => Text(logs[i], style: const TextStyle(color: Colors.greenAccent, fontFamily: 'monospace')),
              ),
            ),
          ),
          if (finished) 
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green,
              width: double.infinity,
              child: Text("SELESAI! Cek folder Download.\n$finalPath", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), 
                  textAlign: TextAlign.center),
            )
        ],
      ),
    );
  }
}
