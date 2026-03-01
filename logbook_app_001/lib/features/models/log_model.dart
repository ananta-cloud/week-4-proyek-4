import 'package:flutter/material.dart';
class LogModel {
  final String title;
  final String date;
  final String description;
  final String kategori;

  LogModel({
    required this.title,
    required this.date,
    required this.description, 
    required this.kategori,
  });

  Color get categoryColor {
    switch (kategori) {
      case 'Urgent':
        return Colors.red;
      case 'Kerja':
        return Colors.blue;
      case 'Pribadi':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      title: map['title'],
      date: map['date'],
      description: map['description'],
      kategori: map['kategori'] ?? "Kerja",
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'description': description,
      'kategori': kategori
    };
  }
}
