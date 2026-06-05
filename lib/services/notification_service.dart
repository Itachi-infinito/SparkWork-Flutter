class NotificationService {
  static Future<void> initialize() async {}
  static Future<String?> getToken() async => null;
  static Future<void> showMatch({
    required String jobOfferTitle,
    required String companyName,
  }) async {}
  static Future<void> showMessage({
    required String senderName,
    required String messagePreview,
  }) async {}
}