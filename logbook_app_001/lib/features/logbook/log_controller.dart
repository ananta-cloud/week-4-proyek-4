import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'dart:convert';
import '../models/log_model.dart';

class LogController {
  final ValueNotifier<List<LogModel>> logsNotifier = ValueNotifier([]);
  final ValueNotifier<List<LogModel>> filteredLogsNotifier = ValueNotifier([]);
  static const String _storageKey = 'user_logs_data';
  final List<LogModel> _logs = [];
  String lastQuery = "";

  LogController() {
    loadFromDisk();
  }

  void searchLogs(String query) {
    lastQuery = query;
    if (query.isEmpty) {
      filteredLogsNotifier.value = logsNotifier.value;
    } else {
      filteredLogsNotifier.value = logsNotifier.value
          .where((log) => log.title.toLowerCase().contains(query.toLowerCase()))
          .toList();
    }
  }

  void _updateFilteredLogs() {
    if (lastQuery.isEmpty) {
      filteredLogsNotifier.value = List<LogModel>.from(logsNotifier.value);
    } else {
      filteredLogsNotifier.value = logsNotifier.value
          .where(
            (log) => log.title.toLowerCase().contains(lastQuery.toLowerCase()),
          )
          .toList();
    }
  }

  void addLog(String title, String desc, String kategori) {
    final newLog = LogModel(
      title: title,
      description: desc,
      kategori: kategori,
      date: DateTime.now().toString(),
    );
    logsNotifier.value = [...logsNotifier.value, newLog];
    _updateFilteredLogs();
    saveToDisk();
  }

  void updateLog(LogModel oldLog, String title, String desc, String kategori) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    final index = currentLogs.indexOf(oldLog);
    
    if (index != -1) {
      currentLogs[index] = LogModel(
        title: title,
        description: desc,
        kategori: kategori, 
        date: DateTime.now().toString(),
      );
      
      logsNotifier.value = currentLogs;
      _updateFilteredLogs();
      saveToDisk(); 
    }
  }

  void removeLog(LogModel log) {
    final currentLogs = List<LogModel>.from(logsNotifier.value);
    currentLogs.remove(log);
    logsNotifier.value = currentLogs;
    _updateFilteredLogs();
    saveToDisk();
  }

  Future<void> saveToDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String encodedData = jsonEncode(
      logsNotifier.value.map((e) => e.toMap()).toList(),
    );
    await prefs.setString(_storageKey, encodedData);
  }

  Future<void> loadFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List decoded = jsonDecode(data);
      logsNotifier.value = decoded.map((e) => LogModel.fromMap(e)).toList();
      filteredLogsNotifier.value = logsNotifier.value;
      _updateFilteredLogs();
    }
  }
}
