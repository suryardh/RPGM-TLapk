import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'process_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TextEditingController> keyControllers = [TextEditingController()];
  Map<String, bool> scope = {
    'Story': true,
    'Database': true,
    'System': true,
    'Enemies': false,
  };
  bool _isKeysExpanded = true;

  void addKey() {
    if (keyControllers.length < 5) {
      setState(() => keyControllers.add(TextEditingController()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Maksimal 5 API Key!"), backgroundColor: Colors.orange));
    }
  }

  void removeKey(int index) {
    if (keyControllers.length > 1) {
      setState(() => keyControllers.removeAt(index));
    }
  }

  void pickFolder() async {
    var status = await Permission.storage.request();
    var manage = await Permission.manageExternalStorage.request();
    if (status.isGranted || manage.isGranted) {
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        List<String> keys = keyControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (keys.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Masukkan minimal 1 API Key!"), backgroundColor: Colors.red));
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessScreen(path: path, keys: keys, scope: scope)));
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Izin penyimpanan wajib diberikan!"), backgroundColor: Colors.red));
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("RPGM Translator", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [Colors.blueGrey.shade900, Colors.deepPurple.shade900]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [Icon(Icons.info_outline, color: Colors.cyanAccent), SizedBox(width: 10), Text("Panduan Singkat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))]),
                  SizedBox(height: 8),
                  Text("1. Siapkan Gemini API Key.\n2. Pilih folder data game.\n3. Aplikasi akan membuat file Patch ZIP.\n4. Ekstrak ZIP ke folder game.", style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    ListTile(
                      title: const Text("Konfigurasi API", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      trailing: Icon(_isKeysExpanded ? Icons.expand_less : Icons.expand_more, color: Colors.grey),
                      onTap: () => setState(() => _isKeysExpanded = !_isKeysExpanded),
                    ),
                    if (_isKeysExpanded) ...[
                      ...keyControllers.asMap().entries.map((entry) {
                        int idx = entry.key;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: keyControllers[idx],
                                  style: const TextStyle(color: Colors.white),
                                  decoration: InputDecoration(
                                    labelText: "API Key ${idx + 1}",
                                    labelStyle: const TextStyle(color: Colors.grey),
                                    prefixIcon: const Icon(Icons.key, color: Colors.deepPurpleAccent, size: 18),
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                    filled: true,
                                    fillColor: Colors.black26,
                                  ),
                                ),
                              ),
                              if (keyControllers.length > 1)
                                IconButton(icon: const Icon(Icons.remove_circle, color: Colors.redAccent), onPressed: () => removeKey(idx))
                            ],
                          ),
                        );
                      }).toList(),
                      TextButton.icon(
                        onPressed: addKey,
                        icon: const Icon(Icons.add_circle, color: Colors.greenAccent),
                        label: const Text("Tambah Key", style: TextStyle(color: Colors.greenAccent)),
                      )
                    ]
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Card(
              color: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: scope.keys.map((key) {
                  return CheckboxListTile(
                    title: Text(key, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    value: scope[key],
                    activeColor: Colors.deepPurpleAccent,
                    checkColor: Colors.white,
                    onChanged: (val) => setState(() => scope[key] = val!),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: pickFolder,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurpleAccent,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 5,
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, color: Colors.white),
                  SizedBox(width: 10),
                  Text("Pilih Folder & Mulai", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Center(child: Text("v1.0.0 Alpha", style: TextStyle(color: Colors.grey, fontSize: 10))),
          ],
        ),
      ),
    );
  }
}
