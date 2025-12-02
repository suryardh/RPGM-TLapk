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
  Map<String, bool> scope = {'Story': true, 'Items': true, 'System': true};

  void addKey() {
    if (keyControllers.length < 5) setState(() => keyControllers.add(TextEditingController()));
  }

  void pickFolder() async {
    if (await Permission.storage.request().isGranted || 
        await Permission.manageExternalStorage.request().isGranted) {
      
      String? path = await FilePicker.platform.getDirectoryPath();
      if (path != null) {
        List<String> keys = keyControllers.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList();
        if (keys.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Isi minimal 1 API Key!")));
          return;
        }

        Navigator.push(context, MaterialPageRoute(builder: (_) => ProcessScreen(
          path: path, keys: keys, scope: scope
        )));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("RPGM Translator")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text("Gemini API Keys", style: TextStyle(fontWeight: FontWeight.bold)),
          ...keyControllers.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(controller: c, decoration: const InputDecoration(border: OutlineInputBorder(), hintText: "AIza...")),
          )),
          TextButton.icon(onPressed: addKey, icon: const Icon(Icons.add), label: const Text("Tambah Key")),
          const Divider(),
          const Text("Target Terjemahan", style: TextStyle(fontWeight: FontWeight.bold)),
          ...scope.keys.map((k) => CheckboxListTile(
            title: Text(k), value: scope[k], 
            onChanged: (v) => setState(() => scope[k] = v!)
          )),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: pickFolder,
            child: const Padding(padding: EdgeInsets.all(16), child: Text("Pilih Folder & Mulai")),
          )
        ],
      ),
    );
  }
}
