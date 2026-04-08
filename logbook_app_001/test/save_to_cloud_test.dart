import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/features/models/log_model.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

// Bypass Sertifikat HTTP untuk testing
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  late MongoService mongoService;
  late ObjectId testId;       // ID khusus untuk satu siklus test
  late LogModel originalLog;  // Data sebelum diubah

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    HttpOverrides.global = MyHttpOverrides();
    await dotenv.load(fileName: ".env");
    
    mongoService = MongoService();
    testId = ObjectId(); 
  });

  // Karena ini adalah proses berurutan (Koneksi -> Insert -> Read -> Update -> Delete), 
  // kita masukkan ke dalam satu Group agar state-nya terjaga.
  group('MongoService Cloud Operations Test Suite', () {
    
    test('Test 1: Gagal terhubung jika URI kosong/salah', () async {
      // Ekspektasi fungsi connect() akan melempar (throw) Exception
      expect(
        () async => await mongoService.connect("format salah"), 
        throwsA(anything)
      );
    });

    test('Test 2: Berhasil terhubung ke MongoDB Atlas dengan kredensial valid', () async {
      final mongoUri = dotenv.env['MONGODB_URI'] ?? dotenv.env['MONGO_URI'];
      expect(mongoUri, isNotNull, reason: "Variabel MONGODB_URI kosong di .env");
      
      await mongoService.connect(mongoUri);
      
      expect(mongoService.db, isNotNull);
      expect(mongoService.db!.isConnected, true);
    });

    test('Test 3: Gagal Update jika LogModel tidak memiliki ObjectId', () async {
      final badLog = LogModel(
        id: null, // ID sengaja dikosongkan
        title: "Test",
        description: "Test Desc",
        kategori: "Pribadi",
        date: DateTime.now(),
      );

      // Ekspektasi fungsi updateLog() akan melempar Exception sesuai kode Anda
      expect(
        () async => await mongoService.updateLog(badLog), 
        throwsException
      );
    });

    test('Test 4: Berhasil menyimpan data baru (Insert) ke Cloud', () async {
      originalLog = LogModel(
        id: testId,
        title: "Log Unit Test Asli",
        description: "Ini adalah deskripsi sebelum di-update.",
        kategori: "Testing",
        date: DateTime.now(),
      );

      // Pastikan fungsi berjalan tanpa melempar error
      await expectLater(mongoService.insertLog(originalLog), completes);
    });

    test('Test 5: Berhasil mengambil semua data (Read) dari Cloud', () async {
      final logs = await mongoService.getLogs();
      expect(logs, isNotEmpty, reason: "Koleksi logs di Cloud tidak boleh kosong setelah proses insert");
    });

    test('Test 6: Memastikan data yang baru disimpan muncul di hasil Read dengan akurat', () async {
      final logs = await mongoService.getLogs();
      
      // Cari data yang ID-nya sama dengan ID testing kita
      final testLogFromCloud = logs.firstWhere((log) => log.id == testId);
      
      // Verifikasi integritas datanya
      expect(testLogFromCloud.title, "Log Unit Test Asli");
      expect(testLogFromCloud.kategori, "Testing");
    });

    test('Test 7: Berhasil melakukan Update data di Cloud', () async {
      final updatedLog = LogModel(
        id: testId,
        title: "Log Unit Test (UPDATED)", // Judul kita ubah
        description: "Deskripsi telah diubah melalui Unit Test.",
        kategori: "Urgent", // Kategori kita ubah
        date: DateTime.now(),
      );

      await expectLater(mongoService.updateLog(updatedLog), completes);
    });

    test('Test 8: Memastikan perubahan data Update berhasil tersimpan di Cloud', () async {
      final logs = await mongoService.getLogs();
      final updatedLogFromCloud = logs.firstWhere((log) => log.id == testId);
      
      // Verifikasi bahwa datanya benar-benar berubah di database
      expect(updatedLogFromCloud.title, "Log Unit Test (UPDATED)");
      expect(updatedLogFromCloud.kategori, "Urgent");
      expect(updatedLogFromCloud.description, contains("telah diubah"));
    });

    test('Test 9: Berhasil menghapus (Delete) data dari Cloud', () async {
      await expectLater(mongoService.deleteLog(testId), completes);
    });

    test('Test 10: Memastikan data benar-benar hilang dari Cloud setelah Delete', () async {
      final logs = await mongoService.getLogs();
      
      // Periksa apakah ID test kita masih ada di dalam kumpulan data
      final isStillExists = logs.any((log) => log.id == testId);
      
      expect(isStillExists, false, reason: "Data masih ditemukan di Cloud padahal sudah dihapus");
    });

    test('Test 11: Berhasil menutup koneksi ke Database', () async {
      await mongoService.close();
      
      // Setelah di-close, pastikan property db bernilai null sesuai yang ada di kode mongo_service.dart
      expect(mongoService.db, isNull);
    });

  });
}