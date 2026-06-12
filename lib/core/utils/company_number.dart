/// Validation du numéro d'entreprise belge (BCE / TVA).
///
/// Format officiel : 10 chiffres commençant par 0 ou 1 (ex: 0123.456.749).
/// Les 2 derniers chiffres sont une clé de contrôle :
///   clé = 97 - (8 premiers chiffres % 97)
/// C'est la même règle que pour le numéro de TVA belge (préfixe BE).
class CompanyNumber {
  static String normalize(String input) {
    return input
        .toUpperCase()
        .replaceAll('BE', '')
        .replaceAll(RegExp(r'[^0-9]'), '');
  }

  static bool isValid(String input) {
    final digits = normalize(input);
    if (digits.length != 10) return false;
    if (digits[0] != '0' && digits[0] != '1') return false;
    final body = int.tryParse(digits.substring(0, 8));
    final check = int.tryParse(digits.substring(8));
    if (body == null || check == null) return false;
    return check == 97 - (body % 97);
  }

  /// Format d'affichage : 0123.456.749
  static String format(String input) {
    final d = normalize(input);
    if (d.length != 10) return input;
    return '${d.substring(0, 4)}.${d.substring(4, 7)}.${d.substring(7)}';
  }
}
