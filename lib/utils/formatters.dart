import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final NumberFormat _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final NumberFormat _compact =
    NumberFormat.compactCurrency(symbol: '₱', decimalDigits: 0);
final NumberFormat _whole = NumberFormat('#,##0');
final NumberFormat _decimal = NumberFormat('#,##0.##');
final DateFormat _date = DateFormat('MMM d, yyyy');
final DateFormat _longDate = DateFormat('EEEE, MMM d, yyyy');
final DateFormat _month = DateFormat('MMM');
final DateFormat _monthYear = DateFormat('MMM yyyy');

String formatMoney(num value) => _money.format(value);

String formatCompactMoney(num value) => _compact.format(value);

String formatWhole(num value) => _whole.format(value);

String formatDecimal(num value) => _decimal.format(value);

String formatDate(DateTime date) => _date.format(date);

String formatLongDate(DateTime date) => _longDate.format(date);

String formatMonth(DateTime date) => _month.format(date);

String formatMonthYear(DateTime date) => _monthYear.format(date);

String formatEfficiency(double value, String unit) =>
    '${_decimal.format(value)} $unit';

String formatDistance(double value) => '${_whole.format(value)} km';

String inputNumber(double? value) {
  if (value == null) return '';
  if (value == value.roundToDouble()) return value.toStringAsFixed(0);
  return value.toString();
}

IconData vehicleIcon(String type) {
  switch (type) {
    case 'Motorcycle':
      return Icons.two_wheeler;
    case 'Tricycle':
      return Icons.electric_rickshaw;
    case 'Car':
      return Icons.directions_car;
    case 'SUV / Pickup':
      return Icons.local_taxi;
    case 'Van':
      return Icons.airport_shuttle;
    case 'Truck':
      return Icons.local_shipping;
    case 'Bus':
      return Icons.directions_bus;
    case 'Jeepney':
      return Icons.airport_shuttle;
    default:
      return Icons.commute;
  }
}
