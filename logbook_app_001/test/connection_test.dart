import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logbook_app_001/services/mongo_service.dart';
import 'package:logbook_app_001/helpers/log_helper.dart';

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback = (X509Certificate cert, String host, int port) => true;
  }
}

void main() {
  const String sourceFile = "connection_test.dart";

  setUpAll(() async {
    // 1. Inisialisasi Binding Flutter Test
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // 2. Pasang HttpOverrides SETELAH binding (Agar tidak di-reset ke status 400)
    HttpOverrides.global = MyHttpOverrides();

    // 3. Muat .env
    await dotenv.load(fileName: ".env");
    
    print("DEBUG: ENV Loaded. Keys: ${dotenv.env.keys}");
  });

  test('Memastikan koneksi ke MongoDB Atlas berhasil via MongoService', () async {
    final mongoService = MongoService();
    final String? mongoUri = dotenv.env['MONGODB_URI'] ?? dotenv.env['MONGO_URI'];

    await LogHelper.writeLog("--- START CONNECTION TEST ---", source: sourceFile);

    try {
      if (mongoUri == null || mongoUri.isEmpty) {
        fail("Error: MONGODB_URI tidak ditemukan di file .env");
      }

      // Melakukan koneksi asli
      await mongoService.connect(mongoUri);

      // Verifikasi status dari driver
      expect(mongoService.db, isNotNull);
      expect(mongoService.db!.isConnected, true);

      await LogHelper.writeLog("SUCCESS: Koneksi Atlas Terverifikasi", source: sourceFile, level: 2);
    } catch (e) {
      await LogHelper.writeLog("ERROR: Kegagalan koneksi - $e", source: sourceFile, level: 1);
      fail("Koneksi gagal: $e");
    } finally {
      await mongoService.close();
      await LogHelper.writeLog("--- END TEST ---", source: sourceFile);
    }
  });
}