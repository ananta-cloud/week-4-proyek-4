import 'package:flutter/material.dart';
import 'log_controller.dart';
import '../onboarding/onboarding_view.dart';
import '../models/log_model.dart';
import '../auth/login_controller.dart';
import '../widgets/search_log.dart';
import '../widgets/empty_log.dart';

class LogView extends StatefulWidget {
  final User user;

  const LogView({super.key, required this.user});

  @override
  State<LogView> createState() => _LogViewState();
}

class _LogViewState extends State<LogView> {
  final LogController _controller = LogController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.loadFromDisk();
  }

  // DIALOG EDIT
  void _showEditLogDialog(LogModel log) {
    _titleController.text = log.title;
    _contentController.text = log.description;
    String tempKategori = log.kategori; // Simpan kategori saat ini

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder( // WAJIB ada agar dropdown bisa berubah
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
                onChanged: (val) {
                  setDialogState(() {
                    tempKategori = val!;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
            ElevatedButton(
              onPressed: () {
                _controller.updateLog(
                  log, 
                  _titleController.text, 
                  _contentController.text, 
                  tempKategori
                );
                _titleController.clear();
                _contentController.clear();
                Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }

  // DIALOG TAMBAH
  void _showAddLogDialog() {
    _titleController.clear();
    _contentController.clear();
    String tempKategori = "Kerja"; // Default kategori

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text("Tambah Catatan Baru"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: _titleController, decoration: const InputDecoration(hintText: "Judul Catatan")),
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
              onPressed: () {
                if (_titleController.text.isNotEmpty) {
                  _controller.addLog(
                    _titleController.text, 
                    _contentController.text, 
                    tempKategori);
                  _titleController.clear();
                  _contentController.clear();
                  Navigator.pop(context);
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
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => _showLogoutConfirmation(),
          ),
        ],
      ),
      body: Column(
        children: [
          SearchBarWidget(onSearch: (value) => _controller.searchLogs(value)),
          Expanded(
            child: ValueListenableBuilder<List<LogModel>>(
              valueListenable: _controller.filteredLogsNotifier,
              builder: (context, currentLogs, child) {

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
                      key: Key(log.date), // Menggunakan date sebagai ID unik
                      direction: DismissDirection.endToStart, // Swipe dari kanan ke kiri
                      background: Container(
                        margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10), // Samakan dengan margin Card
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(8), // Biar rapi mengikuti lengkungan Card
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (direction) {
                        // PENTING: Hapus berdasarkan objek log, bukan index!
                        _controller.removeLog(log); 
                        
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Catatan '${log.title}' dihapus"),
                            action: SnackBarAction(
                              label: "OK",
                              onPressed: () {},
                            ),
                          ),
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: IntrinsicHeight(
                          child: Row(
                            children: [
                              Container(width: 6, color: log.categoryColor), // Garis warna kategori
                              Expanded(
                                child: ListTile(
                                  leading: const Icon(Icons.note),
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
                                        onPressed: () => _controller.removeLog(log), 
                                      ),
                                    ],
                                  ),
                                ),
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