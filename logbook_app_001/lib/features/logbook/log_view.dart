import 'package:bson/src/classes/object_id.dart';
import  'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';
import 'log_controller.dart';
import '../onboarding/onboarding_view.dart';
import '../models/log_model.dart';
import '../auth/login_controller.dart';
import '../widgets/search_log.dart';
import '../widgets/empty_log.dart';
import '../../helpers/log_helper.dart';
import '../../services/mongo_service.dart';

class LogView extends StatefulWidget {
  final User user;

  const LogView({super.key, required this.user});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  late LogController _controller;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = LogController();
    Future.microtask(() => _initDatabase());
  }

  Future<void> _initDatabase() async {
    setState(() => _isLoading = true);
    try {
      await LogHelper.writeLog("UI: Memulai inisialisasi...", source: "log_view.dart");

      // 1. Ambil URI dari dotenv
      final String? mongoUri = dotenv.env['MONGODB_URI'];
      
      if (mongoUri == null) {
        throw Exception("MONGODB_URI tidak ditemukan di .env");
      }

      // 2. Kirim mongoUri ke fungsi connect()
      // PERBAIKAN: Sekarang connect() menerima 1 argumen
      await MongoService().connect(mongoUri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw Exception("Koneksi Cloud Timeout."),
      );

      await LogHelper.writeLog("UI: Koneksi Berhasil.", source: "log_view.dart");

      // 3. Memuat data
      await _controller.loadFromDisk();
    } catch (e) {
      await LogHelper.writeLog("UI: Error - $e", source: "log_view.dart", level: 1);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Masalah: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // DIALOG EDIT - PERBAIKAN: Menggunakan ID/Objek, bukan Index
  void _showEditLogDialog(LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    String tempKategori = log.kategori;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Edit Catatan"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Judul")),
              TextField(controller: _contentController, decoration: const InputDecoration(labelText: "Deskripsi")),
              const SizedBox(height: 15),
              DropdownButton<String>(
                value: tempKategori,
                isExpanded: true,
                items: ["Kerja", "Pribadi", "Urgent"].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setDialogState(() => tempKategori = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                // PERBAIKAN: Mencari index terbaru dari list controller agar akurat
                int currentIndex = _controller.logsNotifier.value.indexOf(log);
                
                await _controller.updateLog(
                  currentIndex,
                  _titleController.text, 
                  _contentController.text, 
                  tempKategori
                );
                
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG TAMBAH (Sudah benar)
  void _showAddLogDialog() {
    _titleController.clear();
    _contentController.clear();
    String tempKategori = "Kerja";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Catatan Baru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(hintText: "Judul")),
              TextField(controller: _contentController, decoration: const InputDecoration(hintText: "Isi Deskripsi")),
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: tempKategori,
                isExpanded: true,
                items: ["Kerja", "Pribadi", "Urgent"].map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                onChanged: (val) => setDialogState(() => tempKategori = val!),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () async {
                if (_titleController.text.isNotEmpty) {
                  await _controller.addLog(
                    _titleController.text,
                    _contentController.text,
                    tempKategori,
                  );
                  if (mounted) Navigator.pop(context);
                }
              },
              child: const Text("Simpan"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("LogBook: ${widget.user.username}"),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: _showLogoutConfirmation),
        ],
      ),
      body: Column(
        children: [
          SearchBarWidget(onSearch: (value) => _controller.searchLogs(value)),
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.filteredLogsNotifier,
              builder: (context, currentLogs, child) {
                if (_isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (_controller.logsNotifier.value.isEmpty) {
                  return const EmptyLog(isSearchMode: false);
                }

                if (currentLogs.isEmpty && _controller.lastQuery.isNotEmpty) {
                  return EmptyLog(isSearchMode: true, searchQuery: _controller.lastQuery);
                }

                return ListView.builder(
                  itemCount: currentLogs.length,
                  itemBuilder: (context, index) {
                    final log = currentLogs[index];
                    return Dismissible(
                      key: Key(log.id?.toHexString() ?? log.date.toString()), // Gunakan ID yang unik
                      direction: DismissDirection.endToStart,
                      background: _buildDeleteBackground(),
                      onDismissed: (direction) => _controller.removeLog(log), // PERBAIKAN: Kirim Objek log
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: ListTile(
                          leading: VerticalDivider(color: log.categoryColor, thickness: 6),
                          title: Text(log.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(log.description),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.blue),
                                onPressed: () => _showEditLogDialog(log),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _controller.removeLog(log), // PERBAIKAN: Kirim Objek log
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddLogDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDeleteBackground() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white),
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Apakah Anda yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const OnboardingView()),
              (route) => false,
            ),
            child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}