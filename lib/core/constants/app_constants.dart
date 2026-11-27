/// Shared non-localized constants. Never hardcode these in the UI.
class AppConstants {
  AppConstants._();

  static const String appName = 'Canteen 3D';
  static const String currencySymbol = '₹';

  /// Tax added on top of the basket subtotal (5%).
  static const double taxRate = 0.05;

  /// Fake network delay of the local data source, in milliseconds.
  static const int fakeLatencyMs = 400;
}
