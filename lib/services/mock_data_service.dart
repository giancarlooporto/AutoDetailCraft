import '../models/user_profile.dart';
import '../models/booking_models.dart';
import '../models/detail_job.dart';
import '../models/team_member.dart';
import '../models/user_vehicle.dart';

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
    username: 'car_enthusiast',
    displayName: 'Car Enthusiast',
    businessName: 'My Detailing Studio',
    avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=200&auto=format&fit=crop&q=80',
    coverUrl: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
    location: 'Austin, Texas',
    serviceRadius: '30 miles • Mobile & Shop',
    bio: 'Automotive enthusiast. Keeping paint in showroom condition.',
    phone: '',
    instagramHandle: '@detailcraft',
    isIdaCertified: false,
    isVerifiedHost: false,
    servicePackages: standardPackages,
    myGarage: const [], // Starts empty so only user-added vehicles appear!
    teamMembers: const [],
    totalJobsCount: 0,
    averageRating: 5.0,
    reviewCount: 0,
    startingPrice: 160.0,
  );

  // PUBLIC DISCOVERY PROFILES (Browse other detailers on Explore)
  static final List<UserProfile> publicDetailers = [
    UserProfile(
      id: 'usr_marcus',
      role: UserRole.detailer,
      username: 'marcus_vance',
      displayName: 'Marcus Vance',
      businessName: 'Apex Gloss Lab & Mobile',
      avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=200&auto=format&fit=crop&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
      location: 'Austin, Texas',
      serviceRadius: '30 miles • Mobile Van & Shop',
      bio: 'IDA CD-SV Certified Master Detailer. Dedicated to swirl-free paint correction and accredited Gtechniq ceramic coatings.',
      phone: '(512) 890-4421',
      instagramHandle: '@apexglosslab',
      isIdaCertified: true,
      isVerifiedHost: true,
      certifications: const [
        UserCertification(title: 'IDA Certified Detailer (CD-SV)', issuer: 'International Detailing Assoc.'),
        UserCertification(title: 'Gtechniq Accredited Installer', issuer: 'Gtechniq UK'),
        UserCertification(title: 'XPEL Certified PPF Installer', issuer: 'XPEL Inc.'),
      ],
      servicePackages: standardPackages,
      teamMembers: const [
        TeamMember(
          id: 'tm_01',
          name: 'Tyler Reed',
          roleTitle: 'Lead Paint Correction Specialist',
          avatarUrl: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=200&auto=format&fit=crop&q=80',
          rating: 5.0,
          completedJobsCount: 58,
        ),
        TeamMember(
          id: 'tm_02',
          name: 'Elena Rostova',
          roleTitle: 'PPF & Ceramic Coating Tech',
          avatarUrl: 'https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=200&auto=format&fit=crop&q=80',
          rating: 4.9,
          completedJobsCount: 34,
        ),
      ],
      totalJobsCount: 84,
      averageRating: 4.98,
      reviewCount: 47,
      followersCount: 1420,
      followingCount: 180,
      startingPrice: 160.0,
    ),
    UserProfile(
      id: 'usr_sarah',
      role: UserRole.detailer,
      username: 'sarah_gloss',
      displayName: 'Sarah Jenkins',
      businessName: 'Signature Concours Studio',
      avatarUrl: 'https://images.unsplash.com/photo-1580489944761-15a19d654956?w=200&auto=format&fit=crop&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=1200&auto=format&fit=crop&q=80',
      location: 'Dallas, Texas',
      serviceRadius: 'Studio Location Only',
      bio: 'Exotic & classic car specialist. Temperature-controlled clean room with multi-angle lighting for zero swirl defects.',
      phone: '(214) 773-9012',
      instagramHandle: '@signatureconcours',
      isIdaCertified: true,
      isVerifiedHost: true,
      certifications: const [
        UserCertification(title: 'IDA Skills Validated (SV)', issuer: 'International Detailing Assoc.'),
        UserCertification(title: 'Modesta Accredited Coating Specialist', issuer: 'Modesta Japan'),
      ],
      servicePackages: standardPackages,
      teamMembers: const [
        TeamMember(
          id: 'tm_03',
          name: 'Derrick Hall',
          roleTitle: 'Senior Wet Sanding & Texture Leveler',
          avatarUrl: 'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200&auto=format&fit=crop&q=80',
          rating: 5.0,
          completedJobsCount: 71,
        ),
      ],
      totalJobsCount: 62,
      averageRating: 5.0,
      reviewCount: 38,
      followersCount: 980,
      followingCount: 120,
      startingPrice: 180.0,
    ),
    UserProfile(
      id: 'usr_diego',
      role: UserRole.detailer,
      username: 'diego_craft',
      displayName: 'Diego Morales',
      businessName: 'Morales Elite Mobile Detail',
      avatarUrl: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=200&auto=format&fit=crop&q=80',
      coverUrl: 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=1200&auto=format&fit=crop&q=80',
      location: 'Houston, Texas',
      serviceRadius: '40 miles • Fully Equipped Mobile Unit',
      bio: 'On-site luxury vehicle correction. Deionized spot-free water & onboard silent generator.',
      phone: '(713) 441-8890',
      instagramHandle: '@morales_elite',
      isIdaCertified: false,
      isVerifiedHost: true,
      servicePackages: standardPackages,
      totalJobsCount: 39,
      averageRating: 4.92,
      reviewCount: 22,
      followersCount: 560,
      followingCount: 95,
      startingPrice: 140.0,
    ),
  ];

  // Initial Detail Jobs Feed
  static List<DetailJob> getInitialJobs() {
    return [
      DetailJob(
        id: 'job_01',
        author: publicDetailers[0], // Marcus Vance
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        title: 'Stage 2 Correction on Sticky Jet Black + 5-Year Ceramic',
        description:
            'Extremely soft sticky solid black clear coat. Heavy car-wash brush swirls throughout all horizontal panels. Achieved 92% defect removal with zero buffer trails.',
        vehicleYear: 2023,
        vehicleMake: 'Porsche',
        vehicleModel: '911 GT3 (992)',
        paintColorName: 'Solid Black (A1)',
        paintCode: 'A1',
        paintHardness: PaintHardness.soft,
        initialPaintThicknessMicrons: 112.0,
        finalPaintThicknessMicrons: 108.5,
        defectSeverity: 8,
        serviceType: 'Ceramic Coating',
        recipeStages: const [
          RecipeStage(
            stageName: 'Chemical Decon & Iron Removal',
            chemical: 'CarPro IronX & TarX',
            technique: 'Dwell 5 mins out of direct sunlight, agitate with detail brush, high-pressure rinse',
          ),
          RecipeStage(
            stageName: 'Compounding Cut (Stage 1)',
            machine: 'Rupes LHR15 Mark III (15mm throw)',
            pad: 'Lake Country Microfiber Cutting Pad 5.5"',
            chemical: 'Koch Chemie Heavy Cut H9.02',
            technique: '4 crosshatch passes @ speed 4.5, slow arm movement, wipe with 400gsm microfiber',
          ),
          RecipeStage(
            stageName: 'Finishing Polish (Jeweling Stage 2)',
            machine: 'Rupes Duetto (12mm throw)',
            pad: 'Rupes Yellow Fine Foam Pad',
            chemical: 'Sonax Perfect Finish 04-06',
            technique: '3 light passes @ speed 3 with minimal pressure to eliminate micro-marring',
          ),
          RecipeStage(
            stageName: 'Ceramic Protection Layer',
            machine: 'Hand Applicator Block + Suede 10x10',
            pad: 'CarPro Foam Applicator Block',
            chemical: 'Gtechniq Crystal Serum Ultra (9H Accredited)',
            technique: 'Cross-hatch application per panel, flash wait 60s, dual towel wipe leveling',
          ),
        ],
        beforeImageUrl: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
        afterImageUrl: 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=900&auto=format&fit=crop&q=80',
        defectBadge: 'Heavy Brush Swirls',
        likesCount: 142,
        savesCount: 67,
      ),
      DetailJob(
        id: 'job_02',
        author: publicDetailers[1], // Sarah Jenkins
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        title: 'CeramiClear Hard Paint Wet-Sand & Leveling on AMG G63',
        description:
            'Mercedes Magno/CeramiClear hard clear coat with deep etchings from hard sprinkler water. Required micro-sanding on hood and roof.',
        vehicleYear: 2024,
        vehicleMake: 'Mercedes-AMG',
        vehicleModel: 'G 63 4MATIC',
        paintColorName: 'Night Black Magno',
        paintCode: '056',
        paintHardness: PaintHardness.hard,
        initialPaintThicknessMicrons: 145.0,
        finalPaintThicknessMicrons: 139.0,
        defectSeverity: 9,
        serviceType: 'Paint Correction',
        recipeStages: const [
          RecipeStage(
            stageName: 'Defect Spot Wet Sanding',
            machine: 'Mirka Cordless 32mm 3mm Orbit',
            pad: 'Trizact 3000 Grit Foam Disc',
            chemical: 'Meguiars M34 Final Inspection Lubricant',
            technique: 'Feather-edge 8-second localized sand bursts with digital micrometer verification',
          ),
          RecipeStage(
            stageName: 'Rotary Heavy Cut',
            machine: 'Flex PE 14-2 Rotary Polisher',
            pad: 'Lake Country Wool Pad 6.5"',
            chemical: 'Menzerna Heavy Cut Compound 400',
            technique: '1200 RPM constant, guide with edge, wipe IPA 20% solution',
          ),
          RecipeStage(
            stageName: 'Refinement DA Polish',
            machine: 'Rupes LHR21 Mark III (21mm throw)',
            pad: 'Scholl Concepts Spider Foam Pad',
            chemical: 'Scholl Concepts S20 Black 1-Step',
            technique: '4 crosshatch passes @ speed 4.0',
          ),
        ],
        beforeImageUrl: 'https://images.unsplash.com/photo-1520340356584-f9917d1eea6f?w=900&auto=format&fit=crop&q=80',
        afterImageUrl: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
        defectBadge: 'Water Spot Acid Etch',
        likesCount: 98,
        savesCount: 45,
      ),
      DetailJob(
        id: 'job_03',
        author: publicDetailers[0], // Marcus Vance
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        title: 'Single Stage Vintage Paint Rehydration & Glaze Polish',
        description:
            'Original non-clear coated single stage lacquer on 1967 Alfa Romeo. Required oil saturation before any mechanical compounding.',
        vehicleYear: 1967,
        vehicleMake: 'Alfa Romeo',
        vehicleModel: '33 Stradale / Giulia Sprint GT',
        paintColorName: 'Rosso Alfa',
        paintCode: 'AR-501',
        paintHardness: PaintHardness.singleStage,
        initialPaintThicknessMicrons: 95.0,
        finalPaintThicknessMicrons: 93.0,
        defectSeverity: 7,
        serviceType: 'Paint Correction',
        recipeStages: const [
          RecipeStage(
            stageName: 'Meguiar #7 Oil Soak Saturation',
            chemical: 'Meguiars Mirror Glaze #7 Show Car Glaze',
            technique: 'Hand applied heavy coat, let sit 24h wrapped in plastic to feed drying lacquer oils',
          ),
          RecipeStage(
            stageName: 'Ultra-Gentle Foam DA Polish',
            machine: 'Rupes LHR15 Mark III',
            pad: 'Rupes White Ultra Fine Foam Pad',
            chemical: 'CarPro Reflect Super Fine Polish',
            technique: 'Speed 3, zero downward pressure, frequent pad clean with compressed air nozzle',
          ),
        ],
        beforeImageUrl: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
        afterImageUrl: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
        defectBadge: 'Oxidized Lacquer',
        likesCount: 215,
        savesCount: 110,
      ),
    ];
  }

  // Initial Bookings starts empty for clean user experience
  static List<BookingAppointment> getInitialBookings() {
    return [];
  }
}
