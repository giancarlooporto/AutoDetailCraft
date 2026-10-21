import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/detail_job.dart';
import '../models/inventory_item.dart';

class MockDataService {
  // Standard detailing service packages
  static final List<ServicePackage> standardPackages = [
    const ServicePackage(
      id: 'pkg_express',
      title: 'Decontamination & Gloss Wash',
      description: 'Hand foam wash, wheel barrel iron decon, clay towel treatment, and 6-month ceramic sealant spray.',
      basePrice: 160.0,
      estimatedDuration: '2.5 - 3.5 hrs',
      isPopular: false,
      includes: [
        'Foam cannon 2-bucket hand wash',
        'Iron removal chemical decon',
        'Fine clay bar paint purification',
        'Tire degreasing & satin dressing',
        'Interior blowout & streak-free glass',
        '6-month SiO2 ceramic spray sealant'
      ],
    ),
    const ServicePackage(
      id: 'pkg_correction',
      title: 'Stage 2 Paint Correction & Enhancement',
      description: 'Compound cut + jeweled finishing polish eliminating 85-90% of swirl marks, scratches, and haze.',
      basePrice: 480.0,
      estimatedDuration: '5.0 - 7.0 hrs',
      isPopular: true,
      includes: [
        'Full multi-stage wash & clay decon',
        'Dual-action machine compounding',
        'Ultra-fine gloss jeweling polish',
        'Paint depth (PTG) reading check',
        'Exhaust tips polished',
        '1-Year durable paint sealant applied'
      ],
    ),
    const ServicePackage(
      id: 'pkg_ceramic',
      title: 'Signature 5-Year Ceramic Coating & Correction',
      description: 'Full multi-stage restoration + Gtechniq Crystal Serum Ultra 9H professional ceramic coating on paint & wheels.',
      basePrice: 950.0,
      estimatedDuration: '1 - 2 Days',
      isPopular: true,
      includes: [
        'Complete 2-stage multi-step paint correction',
        'Isopropanol (IPA) paint wipe down',
        'Dual layer 9H Gtechniq Ceramic Coating',
        'Wheel face ceramic heat-shield coating',
        'Windshield rain repellent coating',
        'Official Digital Warranty & Resale Passport'
      ],
    ),
    const ServicePackage(
      id: 'pkg_interior',
      title: 'Full Concours Interior Deep Clean & Leather Shield',
      description: 'Deep steam extraction, ozone odor neutralization, carpet shampooing, and matte leather ceramic balm.',
      basePrice: 280.0,
      estimatedDuration: '3.5 - 4.5 hrs',
      isPopular: false,
      includes: [
        'Compressed air tornado blowout',
        'Hot water extraction on carpet mats',
        'Steam sanitized AC vents & dashboard',
        'pH-neutral matte leather conditioning',
        'UV barrier protection on interior plastics'
      ],
    ),
  ];

  // YOU: Starts as a clean Regular User (Vehicle Owner) with clean garage
  static final UserProfile youUser = UserProfile(
    id: 'usr_you',
    role: UserRole.client, // Regular user by default
    username: 'user',
    displayName: 'Vehicle Owner',
    businessName: '',
    avatarUrl: '',
    coverUrl: '',
    location: '',
    serviceRadius: '',
    bio: '',
    phone: '',
    instagramHandle: '',
    isIdaCertified: false,
    isVerifiedHost: false,
    servicePackages: const [],
    myGarage: const [], // Starts empty so only user-added vehicles appear!
    teamMembers: const [],
    totalJobsCount: 0,
    averageRating: 5.0,
    reviewCount: 0,
    startingPrice: 0.0,
  );

  // PUBLIC DISCOVERY PROFILES (Starts empty for real live profiles only)
  static const List<UserProfile> publicDetailers = [];

  // Initial Transformation Jobs (Starts empty for real published builds only)
  static List<DetailJob> getInitialJobs() {
    return [];
  }

  // Initial Bookings starts empty for clean user experience
  static List<BookingAppointment> getInitialBookings() {
    return [];
  }

  // Initial Professional Detailing Inventory (Starts empty for clean real studio setup)
  static List<InventoryItem> getInitialInventory() {
    return [];
  }
}
