import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

String formatTimestamp(dynamic ts) {
  if (ts == null) return '';
  DateTime date;
  if (ts is Timestamp) {
    date = ts.toDate();
  } else if (ts is DateTime) {
    date = ts;
  } else {
    return ts.toString();
  }
  return DateFormat('dd MMM yyyy, hh:mm a').format(date);
}