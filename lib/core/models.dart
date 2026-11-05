import 'package:intl/intl.dart';

typedef Json = Map<String, dynamic>;
const statusNames = {
  'PENDING': 'Menunggu',
  'IN_PROGRESS': 'Diproses',
  'COMPLETED': 'Selesai',
  'REJECTED': 'Ditolak',
};
const categoryNames = {
  'ORGANIC': 'Organik',
  'PLASTIC': 'Plastik',
  'PAPER': 'Kertas',
  'GLASS': 'Kaca',
  'METAL': 'Logam',
  'CARDBOARD': 'Kardus',
  'CLOTHES': 'Pakaian',
  'FOOTWEAR': 'Alas kaki',
  'BATTERY': 'Baterai',
  'OTHER': 'Lainnya',
};
String dateLabel(String value) => DateFormat(
  'd MMM yyyy, HH.mm',
  'id_ID',
).format(DateTime.parse(value).toLocal());

class AppUser {
  final String id, name, email, role;
  AppUser.fromJson(Json j)
    : id = j['id'],
      name = j['name'],
      email = j['email'],
      role = j['role'];
}

class WasteReport {
  final String id, description, status, createdAt;
  final double latitude, longitude;
  final Json? prediction;
  final List<Json> history;
  WasteReport.fromJson(Json j)
    : id = j['id'],
      description = j['description'],
      status = j['status'],
      createdAt = j['createdAt'],
      latitude = (j['latitude'] as num).toDouble(),
      longitude = (j['longitude'] as num).toDouble(),
      prediction = j['prediction'] as Json?,
      history = (j['statusHistory'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
}

class ReportPage {
  final List<WasteReport> items;
  final int total;
  ReportPage.fromJson(Json j)
    : items = (j['items'] as List)
          .map((x) => WasteReport.fromJson(Map<String, dynamic>.from(x)))
          .toList(),
      total = j['total'];
}
