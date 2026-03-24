import 'package:flutter/material.dart';

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status});
  final String status;

  Color _color() {
    switch (status.toLowerCase()) {
      case 'contacted':
        return Colors.blue;
      case 'scheduling':
        return Colors.amber;
      case 'scheduled':
        return Colors.orange;
      case 'briefed':
        return Colors.green;
      case 'follow_up_needed':
      case 'follow-up needed':
        return Colors.red;
      case 'inactive':
        return Colors.grey;
      default:
        return Colors.black54;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(status),
      backgroundColor: _color().withOpacity(0.15),
      side: BorderSide(color: _color()),
    );
  }
}
