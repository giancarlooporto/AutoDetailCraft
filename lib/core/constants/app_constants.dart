class AppConstants {
  static const String appName = 'AutoDetailCraft';
  static const String appTagline = 'Book Verified Master Detailers • Browse Real Transformations';

  static const List<String> serviceTypes = [
    'All Services',
    'Ceramic Coating',
    'Paint Correction',
    'Gloss & Decon Wash',
    'Interior Deep Clean',
    'PPF & Clear Bra',
  ];

  static const List<String> popularLocations = [
    'All Locations',
    'Austin, Texas',
    'Miami, Florida',
    'Los Angeles, California',
    'Dallas, Texas',
    'Scottsdale, Arizona',
  ];

  // List of recognized super admin emails with immediate full owner rights
  static const List<String> superAdminEmails = [
    'giancarlooportousa@gmail.com',
    'giancarlooporto@gmail.com',
    'admin@autodetailcraft.com',
    'founder@autodetailcraft.com',
  ];

  static bool isSuperAdminEmail(String? email) {
    if (email == null || email.trim().isEmpty) return false;
    final normalized = email.trim().toLowerCase();
    // Match any in the list or starting with giancarlooporto
    return superAdminEmails.contains(normalized) ||
        normalized.startsWith('giancarlooporto');
  }
}
