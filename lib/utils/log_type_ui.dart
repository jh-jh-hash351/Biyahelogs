import 'package:flutter/material.dart';

import '../models/log_entry.dart';

extension LogTypeUi on LogType {
  IconData get icon {
    switch (this) {
      case LogType.fuel:
        return Icons.local_gas_station;
      case LogType.oilChange:
        return Icons.oil_barrel;
      case LogType.repair:
        return Icons.build;
      case LogType.other:
        return Icons.receipt_long;
    }
  }

  Color get color {
    switch (this) {
      case LogType.fuel:
        return const Color(0xFFEA8C00);
      case LogType.oilChange:
        return const Color(0xFF2563EB);
      case LogType.repair:
        return const Color(0xFFDC2626);
      case LogType.other:
        return const Color(0xFF7C3AED);
    }
  }

  String get title {
    switch (this) {
      case LogType.fuel:
        return 'Fuel fill-up';
      case LogType.oilChange:
        return 'Oil change';
      case LogType.repair:
        return 'Repair';
      case LogType.other:
        return 'Other expense';
    }
  }
}
