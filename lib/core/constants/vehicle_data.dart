class VehicleModelSpec {
  final String model;
  final List<int> years;
  final List<String> factoryColors;
  final String defaultImage;

  const VehicleModelSpec({
    required this.model,
    required this.years,
    required this.factoryColors,
    required this.defaultImage,
  });
}

class VehicleDatabase {
  // Production years from 1950 to 2026 (77 production years)
  static final List<int> allStandardYears = List.generate(77, (index) => 2026 - index);

  // Complete exhaustive list of Automobile Makes present in USA and Canada
  static final List<String> allMakes = [
    'Acura',
    'Alfa Romeo',
    'Aston Martin',
    'Audi',
    'Bentley',
    'BMW',
    'Bugatti',
    'Buick',
    'Cadillac',
    'Chevrolet',
    'Chrysler',
    'Dodge',
    'Ferrari',
    'Fiat',
    'Fisker',
    'Ford',
    'Genesis',
    'GMC',
    'Honda',
    'Hummer',
    'Hyundai',
    'Infiniti',
    'Jaguar',
    'Jeep',
    'Karma',
    'Kia',
    'Koenigsegg',
    'Lamborghini',
    'Land Rover / Range Rover',
    'Lexus',
    'Lincoln',
    'Lotus',
    'Lucid',
    'Maserati',
    'Maybach',
    'Mazda',
    'McLaren',
    'Mercedes-Benz',
    'Mercury',
    'MINI',
    'Mitsubishi',
    'Nissan',
    'Oldsmobile',
    'Pagani',
    'Plymouth',
    'Polestar',
    'Pontiac',
    'Porsche',
    'Ram',
    'Rivian',
    'Rolls-Royce',
    'Saab',
    'Saturn',
    'Scion',
    'Shelby',
    'Smart',
    'Subaru',
    'Suzuki',
    'Tesla',
    'Toyota',
    'VinFast',
    'Volkswagen',
    'Volvo',
  ];

  static final Map<String, List<VehicleModelSpec>> makesAndModels = {
    'Acura': [
      VehicleModelSpec(
        model: 'NSX / Type S (Mid-Engine V6 & Hybrid)',
        years: [2022, 2021, 2020, 2019, 2018, 2017, 2005, 2004, 2003, 2002, 2001, 1999, 1997, 1995, 1993, 1991],
        factoryColors: ['Indy Yellow Pearl', 'Thermal Orange Pearl', 'Valencia Red Pearl', 'Berlina Black', '130R White', 'Casino White Pearl', 'Formula Red', 'Grand Prix White', 'Long Beach Blue Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Integra Type S / A-Spec / Type R (DC2)',
        years: [2025, 2024, 2023, 2001, 2000, 1999, 1998, 1997, 1996, 1995, 1994],
        factoryColors: ['Tiger Eye Pearl', 'Apex Blue Pearl', 'Championship White', 'Platinum White Pearl', 'Liquid Carbon Metallic', 'Majestic Black Pearl', 'Phoenix Yellow', 'Flamenco Black Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'MDX / RDX (Type S & A-Spec)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2007, 2004],
        factoryColors: ['Apex Blue Pearl', 'Tiger Eye Pearl', 'Performance Red Pearl', 'Fathom Blue Pearl', 'Lunar Silver Metallic', 'Majestic Black Pearl', 'Platinum White Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'TLX Type S / A-Spec (Turbo V6)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015],
        factoryColors: ['Tiger Eye Pearl', 'Apex Blue Pearl', 'Performance Red Pearl', 'Urban Gray Pearl', 'Platinum White Pearl', 'Modern Steel Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'ZDX Type S (All-Electric 500hp)',
        years: [2025, 2024, 2013, 2012, 2011, 2010],
        factoryColors: ['Double Apex Blue Pearl', 'Tiger Eye Pearl', 'Cosmic Black Metallic', 'Snowfall Pearl', 'Mercury Silver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'RSX Type-S / TL Type-S (6-Speed Manual)',
        years: [2008, 2007, 2006, 2005, 2004, 2003, 2002],
        factoryColors: ['Kinetic Blue Pearl', 'Nighthawk Black Pearl', 'Arctic Blue Pearl', 'Vivid Blue Pearl', 'Milano Red', 'Desert Mist Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Alfa Romeo': [
      VehicleModelSpec(
        model: 'Giulia Quadrifoglio / Ti / Competizione (505hp Twin-Turbo)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017],
        factoryColors: ['Rosso Competizione (Tri-Coat)', 'Verde Montreal (Tri-Coat)', 'Misano Blue Metallic', 'Vulcano Black Metallic', 'Alfa Red', 'Trofeo White', 'Ocre Lipari'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Stelvio Quadrifoglio / Veloce (Twin-Turbo V6 AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Rosso GTA', 'Verde Fangio', 'Anodized Blue', 'Vesuvio Grey Metallic', 'Alfa White', 'Vulcano Black', 'Misano Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Tonale (Q4 Plug-in Hybrid AWD)',
        years: [2025, 2024],
        factoryColors: ['Verde Fangio Metallic', 'Rosso Alfa', 'Misano Blue Metallic', 'Grigio Ascari Metallic', 'Alfa Black', 'Alfa White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '4C Spider / Coupe (Carbon Monocoque)',
        years: [2020, 2019, 2018, 2017, 2016, 2015],
        factoryColors: ['Madreperla White', 'Rosso Alfa', 'Giallo Prototipo (Yellow)', 'Basalt Grey', 'Alfa Black', 'Rosso Competizione'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '8C Competizione / Spider (4.7L V8 Ferrari Engine)',
        years: [2010, 2009, 2008, 2007],
        factoryColors: ['Rosso 8C Metallizzato', 'Nero Seta (Matte Black)', 'Giallo Corsa', 'Blu Celeste', 'Argento 8C'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Aston Martin': [
      VehicleModelSpec(
        model: 'Vantage / V12 Vantage / F1 Edition',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012, 2010, 2008, 2006],
        factoryColors: ['Aston Martin Racing Green', 'Cosmopolitan Yellow', 'Hyper Red', 'Onyx Black', 'Lunar White', 'China Grey', 'Elwood Blue', 'Lime Essence', 'Q Satin Titanium'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'DB12 / DBS Superleggera / DB11 / Vanquish',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2014, 2010, 2005],
        factoryColors: ['Satin Xenon Grey', 'Caribbean Blue Pearl', 'Minotaur Green', 'Magnetic Silver', 'Supernova Red', 'Storm Red', 'Cumberland Grey', 'Iridescent Emerald'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'DBX 707 SUV (707hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021],
        factoryColors: ['Apex Grey', 'Synapse Green', 'Plasma Blue', 'Scintilla Silver', 'Onyx Black', 'Liquid Crimson', 'Satin Titanium Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Valkyrie (6.5L Cosworth V12 1160hp)',
        years: [2024, 2023, 2022],
        factoryColors: ['AMR Track Green', 'Sunburst Yellow', 'Slipstream Green', 'Lunar White', 'Exposed Gloss Carbon'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Audi': [
      VehicleModelSpec(
        model: 'RS6 Avant / RS7 Performance (621hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018, 2017, 2016, 2015, 2014],
        factoryColors: ['Nardo Grey', 'Daytona Grey Pearl / Matte', 'Tango Red Metallic', 'Sebring Black Crystal', 'Ultra Blue Metallic', 'Navarra Blue Metallic', 'Glacier White Metallic', 'Goodwood Green Pearl (Audi Exclusive)'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'R8 V10 Performance / Decennium / GT (5.2L V10)',
        years: [2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2014, 2012, 2011, 2010, 2009, 2008],
        factoryColors: ['Kemora Grey Metallic', 'Vegas Yellow', 'Mythos Black Metallic', 'Suzuka Grey Metallic', 'Dynamite Red', 'Ascari Blue Metallic', 'Daytona Grey Matte', 'Ibis White'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'RS3 / RS4 / RS5 (5-Cylinder Turbo & Twin-Turbo V6)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2013, 2010, 2008, 2007],
        factoryColors: ['Kyalami Green', 'Kemora Grey', 'Turbo Blue', 'Sonoma Green Metallic', 'Glacier White Metallic', 'Mythos Black Metallic', 'Misano Red Pearl', 'Nardo Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'RS Q8 / SQ7 / SQ8 / SQ5 / Q7 / Q8',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010],
        factoryColors: ['Dragon Orange Metallic', 'Matador Red Metallic', 'Orca Black Metallic', 'Waitomo Blue Metallic', 'Vicuna Beige Metallic', 'Daytona Grey Pearl', 'Navarra Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'e-tron GT / RS e-tron GT (Performance Electric)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Tactical Green Metallic', 'Daytona Grey Pearl', 'Kemora Grey Metallic', 'Suzuka Grey', 'Mythos Black Metallic', 'Ascari Blue Metallic', 'Florett Silver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'S4 / S5 / S6 / A3 / A4 / A5 / A6',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2008, 2005, 2001, 1999],
        factoryColors: ['Navarra Blue Metallic', 'Daytona Grey Pearl', 'Brilliant Black', 'Ibis White', 'Chronos Grey Metallic', 'District Green Metallic', 'Tango Red'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Bentley': [
      VehicleModelSpec(
        model: 'Continental GT / GT Speed / Supersports (W12 & V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2013, 2011, 2008, 2005],
        factoryColors: ['Verdant Green', 'Sequin Blue', 'St James Red', 'Beluga Black', 'Glacier White', 'Orange Flame', 'Tungsten Metallic', 'Havana', 'Apple Green'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Bentayga Speed / EWB / Azure (W12 / Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017],
        factoryColors: ['Dragon Red II', 'Portofino Blue', 'Extreme Silver', 'Dark Sapphire', 'Cumbrian Green', 'Rose Gold', 'Onyx Black', 'Patina Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Flying Spur Speed / Mulliner (W12 & Hybrid)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012, 2009],
        factoryColors: ['Midnight Emerald', 'Onyx', 'Cricket Ball (Burgundy)', 'Marlin Blue', 'Ice White', 'Brodgar', 'Silver Storm'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'BMW': [
      VehicleModelSpec(
        model: 'M3 / M4 Competition / CS (G80/G82 503hp+)',
        years: [2025, 2024, 2023, 2022, 2021],
        factoryColors: ['Isle of Man Green (C4G)', 'Sao Paulo Yellow', 'Brooklyn Grey Metallic', 'Portimao Blue Metallic', 'Frozen Brilliant White (Matte)', 'Black Sapphire Metallic', 'Dravit Grey Metallic', 'Frozen Portimao Blue', 'Toronto Red'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'M3 / M4 (F80, F82 CS, E92 V8, E46, E30)',
        years: [2020, 2019, 2018, 2017, 2016, 2015, 2013, 2012, 2011, 2010, 2009, 2008, 2005, 2003, 2001, 1998, 1995, 1990, 1988],
        factoryColors: ['Yas Marina Blue', 'Austin Yellow Metallic', 'Sakhir Orange', 'Interlagos Blue', 'Alpine White', 'Mineral Grey Metallic', 'Laguna Seca Blue', 'Phoenix Yellow', 'Techno Violet', 'Dakar Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'M2 Coupe / CS (G87 & F87)',
        years: [2025, 2024, 2023, 2021, 2020, 2019, 2018, 2017, 2016],
        factoryColors: ['Zandvoort Blue', 'Toronto Red Metallic', 'Long Beach Blue', 'Hockenheim Silver Metallic', 'Brooklyn Grey Metallic', 'Black Sapphire Metallic', 'Alpine White', 'Misano Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1555215695-3004980ad54e?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'M5 / M8 Competition / CS (617hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2013, 2008, 2006, 2003, 2000],
        factoryColors: ['Marina Bay Blue Metallic', 'Motegi Red Metallic', 'Donington Grey Metallic', 'Alvite Grey Metallic', 'Frozen Dark Silver', 'Brands Hatch Grey', 'Isle of Man Green', 'Silverstone II'],
        defaultImage: 'https://images.unsplash.com/photo-1525609004556-c46c7d6cf023?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '3 Series / 4 Series / 5 Series (330i, M340i, M440i, M550i)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2006, 2000, 1995, 1990],
        factoryColors: ['Portimao Blue Metallic', 'Tanzanite Blue II Metallic', 'Mineral White Metallic', 'Skyscraper Grey Metallic', 'Sunset Orange Metallic', 'Jet Black', 'Alpine White'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'X3 / X5 / X7 / XM (X3M, X5M Competition, M60i)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2005],
        factoryColors: ['Marina Bay Blue', 'Manhattan Green Metallic', 'Tanzanite Blue II', 'Dravit Grey Metallic', 'Mineral White', 'Carbon Black Metallic', 'Cape York Green', 'Sao Paulo Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1549399542-7e3f8b79c341?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Bugatti': [
      VehicleModelSpec(
        model: 'Chiron / Super Sport 300+ / Pur Sport / Divo (1500hp+ W16)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016],
        factoryColors: ['French Racing Blue', 'Exposed Blue Carbon Fiber', 'Italian Red', 'Nocturne Black', 'Glacier White', 'Grey Carbon', 'Jaune Molsheim (Yellow)'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Tourbillon (Cosworth V16 Hybrid 1800hp)',
        years: [2026, 2025],
        factoryColors: ['Aerolithe Blue', 'Nocturne Blue', 'French Racing Blue / Exposed Carbon', 'Argent Platinum', 'Bespoke Dual-Tone'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Veyron 16.4 / Grand Sport Vitesse / Super Sport',
        years: [2015, 2014, 2013, 2012, 2011, 2010, 2008, 2006, 2005],
        factoryColors: ['Two-Tone Blue / Black', 'Pearl White & Aluminium', 'Sang Noir Black', 'Bright Red / Black', 'Bugatti Light Blue Sport'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Buick': [
      VehicleModelSpec(
        model: 'Enclave / Envision / Envista / Encore GX (Avenir Luxury)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012],
        factoryColors: ['White Frost Tricoat', 'Sage Metallic', 'Cinnabar Metallic', 'Ebony Twilight Metallic', 'Moonstone Gray Metallic', 'Copper Ice Metallic', 'Ocean Blue Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Grand National / GNX / Regal T-Type (Turbo 3.8L V6)',
        years: [1987, 1986, 1985, 1984, 1982],
        factoryColors: ['Sinister Solid Black (OEM GM 19)', 'Dark Charcoal Grey Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Regal GS (AWD Turbo) / Riviera (Classic Boat-Tail)',
        years: [2020, 2019, 2018, 2017, 2015, 2013, 1973, 1971, 1965],
        factoryColors: ['Sport Red', 'Smoked Pearl Metallic', 'Dark Sapphire Blue', 'Ebony Twilight', 'Quicksilver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Cadillac': [
      VehicleModelSpec(
        model: 'CT5-V Blackwing / CT4-V Blackwing (668hp Supercharged V8 6-Speed)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Blaze Orange Metallic', 'Electric Blue', 'Dark Emerald Frost (Matte)', 'Cyber Yellow Metallic', 'Black Raven', 'Summit White', 'Rift Metallic', 'Maverick Noir Frost', 'Radiant Red Tintcoat'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Escalade / Escalade-V / IQ (682hp Supercharged 6.2L)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2007, 2002],
        factoryColors: ['Black Raven', 'Crystal White Tricoat', 'Radiant Red Tintcoat', 'Dark Emerald Metallic', 'Mahogany Metallic', 'Galactic Gray Metallic', 'Argent Silver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Lyriq / Celestiq (Ultra-Luxury Hand-Built EV)',
        years: [2025, 2024, 2023],
        factoryColors: ['Celestial Metallic', 'Opulent Blue Metallic', 'Stellar Black Metallic', 'Emerald Lake Metallic', 'Nimbus Metallic', 'Crystal White'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'CTS-V / ATS-V (Supercharged 6.2L V8 & Twin-Turbo V6)',
        years: [2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012, 2011, 2010, 2009, 2005],
        factoryColors: ['Crystal White Frost (Matte)', 'Red Obsession Tintcoat', 'Phantom Gray Metallic', 'Black Raven', 'Velocity Red', 'Vector Blue Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Chevrolet': [
      VehicleModelSpec(
        model: 'Corvette Z06 / ZR1 / E-Ray / Stingray (C8 Mid-Engine)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Torch Red', 'Amplify Orange Tintcoat', 'Rapid Blue', 'Hypersonic Grey Metallic', 'Black', 'Arctic White', 'Sea Wolf Gray Tricoat', 'Cacti Green', 'Riptide Blue Metallic', 'Competition Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Corvette ZR1 / Z06 / Grand Sport (C7, C6, C5, C4, C3, C2, C1)',
        years: [2019, 2018, 2017, 2016, 2015, 2014, 2013, 2011, 2009, 2008, 2006, 2004, 2002, 1999, 1995, 1990, 1982, 1970, 1967, 1963, 1957],
        factoryColors: ['Sebring Orange Tintcoat', 'Watkins Glen Gray Metallic', 'Long Beach Red Metallic', 'Laguna Blue Tintcoat', 'Velocity Yellow', 'Torch Red', 'Black', 'Jetstream Blue', 'Le Mans Blue', 'Nassau Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Camaro ZL1 1LE / SS / Z28 (650hp Supercharged LT4)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2012, 2010, 2002, 1998, 1969, 1967],
        factoryColors: ['Vivid Orange Metallic', 'Shock Yellow', 'Riverside Blue Metallic', 'Red Hot', 'Crush Orange', 'Shadow Gray Metallic', 'Black', 'Summit White', 'Hugger Orange (Classic)'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Silverado 1500 / 2500HD / 3500HD / ZR2 (Duramax & 6.2L V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005, 2000],
        factoryColors: ['Glacier Blue Metallic', 'Harvest Bronze Metallic', 'Red Hot', 'Black', 'Summit White', 'Sterling Gray Metallic', 'Lakeshore Blue Metallic', 'Auburn Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Tahoe / Suburban / Colorado ZR2 Bison / Blazer EV',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005],
        factoryColors: ['Auburn Metallic', 'Midnight Blue Metallic', 'Iridescent Pearl Tricoat', 'Black', 'Radiant Red Tintcoat', 'Sand Dune Metallic', 'Cypress Gray'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Chevelle SS / Nova SS / Impala SS (Big Block Classics)',
        years: [1996, 1995, 1994, 1972, 1970, 1969, 1968, 1967, 1964],
        factoryColors: ['Tuxedo Black w/ White Stripes', 'Cranberry Red', 'Fathom Blue', 'Cortez Silver', 'Dark Cherry Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Chrysler': [
      VehicleModelSpec(
        model: '300C (6.4L 392 Hemi V8 485hp) / 300S',
        years: [2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2010, 2006, 2005],
        factoryColors: ['Velvet Red Pearl', 'Gloss Black', 'Bright White', 'Silver Mist', 'Ocean Blue Metallic', 'Ceramic Grey', 'Granite Crystal'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Pacifica (Pinnacle Luxury / Plug-in Hybrid)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017],
        factoryColors: ['Fathom Blue Pearl', 'Velvet Red Pearl', 'Ceramic Grey', 'Brilliant Black Crystal Pearl', 'Bright White', 'Silver Mist Clearcoat'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Crossfire SRT-6 (Supercharged V6) / PT Cruiser GT',
        years: [2008, 2007, 2006, 2005, 2004],
        factoryColors: ['Aero Blue Pearl', 'Black', 'Classic Yellow', 'Alabaster White', 'Sapphire Silver Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Dodge': [
      VehicleModelSpec(
        model: 'Challenger Hellcat / Demon 170 / Redeye / Scat Pack 392 (1025hp)',
        years: [2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2008, 1971, 1970],
        factoryColors: ['Plum Crazy Purple', 'Go Mango Orange', 'F8 Green', 'TorRed', 'B5 Blue', 'Destroyer Grey', 'Pitch Black', 'Sinamon Stick', 'Frostbite', 'Octane Red', 'Sub-Lime Green', 'Smoke Show'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Charger Hellcat Redeye Widebody / Scat Pack / Daytona EV (670hp)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2006, 1969, 1968],
        factoryColors: ['Sub-Lime Green', 'Octane Red', 'Hellraisin Purple', 'White Knuckle', 'Pitch Black', 'Smoke Show Grey', 'Go Mango', 'After Dark Blue', 'Peel Out Orange', 'Blaster Red'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Durango SRT Hellcat / 392 / R/T (710hp Supercharged AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012],
        factoryColors: ['Redline Red Tri-Coat', 'DB Black Crystal', 'Reactor Blue Pearl', 'Destroyer Grey', 'Vice White', 'Night Moves (Navy)', 'Vapor Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Viper GTS / ACR / Time Attack / SRT-10 (8.4L V10 645hp)',
        years: [2017, 2016, 2015, 2014, 2013, 2010, 2008, 2006, 2003, 1998, 1996, 1992],
        factoryColors: ['Viper GTS Blue w/ White Stripes', 'Stryker Green Tri-Coat', 'Competition Blue', 'Venom Black', 'Adrenaline Red', 'Billet Silver Metallic', 'Yorange', 'Anodized Carbon Matte'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Ferrari': [
      VehicleModelSpec(
        model: '296 GTB / GTS (Twin-Turbo V6 Hybrid 819hp)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Rosso Corsa (DS 322)', 'Giallo Modena (Yellow)', 'Rosso Scuderia', 'Grigio Silverstone', 'Nero Daytona', 'Blu Pozzi', 'Verde British Racing', 'Rosso Imola', 'Argento Nurburgring'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'SF90 Stradale / Spider / XX Stradale (1000hp+ Quad-Motor)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Rosso Fiorano', 'Rosso Dino', 'Giallo Triplo Strato', 'Grigio Titanio', 'Nero Opaco (Matte)', 'Blu Corsa', 'Rosso Le Mans', 'Bianco Cervino'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '488 Pista / F8 Tributo / 458 Speciale / 458 Italia (Mid-V8 Icons)',
        years: [2022, 2021, 2020, 2019, 2018, 2015, 2014, 2012, 2010],
        factoryColors: ['Rosso Corsa w/ NART Racing Stripe', 'Blu America', 'Argento Nurburgring', 'Bianco Avus', 'Giallo Modena', 'Grigio Medio', 'Blu Tour de France'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '812 Superfast / GTS / Competizione / 12Cilindri (830hp Naturally Aspirated V12)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Rosso 70 Anni', 'Grigio Ferro', 'Blu Tour de France', 'Verde Francesca', 'Nero Daytona', 'Giallo Tristrato', 'Rosso Mugello'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Purosangue (6.5L V12 715hp Super SUV)',
        years: [2025, 2024, 2023],
        factoryColors: ['Nero Purosangue', 'Rosso Portofino', 'Grigio Titanio', 'Blu Scozia', 'Bianco Cervino', 'Verde Toscana'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'LaFerrari / Enzo / F40 / F50 / Testarossa (Halo Legends)',
        years: [2016, 2015, 2014, 2013, 2004, 2003, 1996, 1995, 1990, 1987, 1984],
        factoryColors: ['Rosso Corsa', 'Giallo Modena', 'Nero', 'Argento Nurburgring', 'Bianco Avus'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Fiat': [
      VehicleModelSpec(
        model: '500 Abarth / 500e / 124 Spider Abarth (Turbo)',
        years: [2025, 2024, 2020, 2019, 2018, 2017, 2016, 2015, 2013, 2012],
        factoryColors: ['Rosso Abarth (Red)', 'Giallo Modena', 'Campovolo Grey', 'Nero Puro', 'Bianco Ghiaccio', 'Acid Green', 'Rose Gold'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Fisker': [
      VehicleModelSpec(
        model: 'Ocean (Extreme / One / Ultra Dual-Motor AWD)',
        years: [2024, 2023],
        factoryColors: ['Big Sur Blue (Matte)', 'Blue Planet', 'Solar Orange', 'Great White', 'Night Drive Black', 'Silver Lining', 'Mariana Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Ford': [
      VehicleModelSpec(
        model: 'Mustang GT / Dark Horse / Mach 1 / EcoBoost (5.0L Coyote V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2005, 1999, 1993, 1989, 1969, 1967, 1965],
        factoryColors: ['Blue Ember Metallic', 'Vapor Blue Metallic', 'Grabber Blue', 'Shadow Black', 'Race Red', 'Oxford White', 'Atlas Blue Metallic', 'Dark Matter Gray', 'Yellow Splash Metallic', 'Kona Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Shelby GT500 / GT350 / Super Snake (760hp Predator V8)',
        years: [2022, 2021, 2020, 2019, 2018, 2017, 2016, 2014, 2013, 2012, 2010, 2008, 1968, 1967],
        factoryColors: ['Twister Orange Tri-Coat', 'Performance Blue', 'Ford Performance Red', 'Wimbledon White w/ Guardsman Blue Stripes', 'Antimatter Blue', 'Grabber Lime', 'Fighter Jet Gray'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'F-150 Raptor / Raptor R / Lightning EV / Tremor (720hp Supercharged V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2014, 2012, 2010],
        factoryColors: ['Shelter Green', 'Code Orange Metallic', 'Avalanche Grey', 'Antimatter Blue', 'Agate Black Metallic', 'Lead Foot Grey', 'Oxford White', 'Carbonized Gray Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Bronco Raptor / Wildtrak / Badlands / Heritage Edition',
        years: [2025, 2024, 2023, 2022, 2021, 1977, 1974, 1969],
        factoryColors: ['Eruption Green Metallic', 'Area 51', 'Cactus Grey', 'Cyber Orange Metallic', 'Robins Egg Blue', 'Shadow Black', 'Hot Pepper Red Tintcoat', 'Velocity Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Super Duty F-250 / F-350 (6.7L Power Stroke) / Explorer ST',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2012, 2005],
        factoryColors: ['Rapid Red Metallic', 'Star White Metallic', 'Stone Gray', 'Agate Black', 'Carbonized Gray', 'Glacier Gray Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Ford GT / GT40 (Twin-Turbo EcoBoost & V8 Supercars)',
        years: [2022, 2021, 2020, 2019, 2018, 2017, 2006, 2005, 1966],
        factoryColors: ['Heritage Gulf Blue & Orange', 'Liquid Blue', 'Triple Yellow', 'Liquid Red', 'Frozen White', 'Shadow Black w/ Racing Stripes', 'Titanium Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Focus RS / Fiesta ST (AWD Drift Mode Hot Hatch)',
        years: [2018, 2017, 2016, 2015, 2014, 2013],
        factoryColors: ['Nitrous Blue Metallic', 'Stealth Grey', 'Shadow Black', 'Frozen White', 'Race Red'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Genesis': [
      VehicleModelSpec(
        model: 'G70 / G80 / G90 (Sport Prestige 3.5T Twin-Turbo AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Havana Red', 'Tasman Blue', 'Makalu Gray (Matte & Gloss)', 'Uyuni White', 'Vik Black', 'Bond Silver Matte', 'Capri Blue', 'Siberian Ice'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'GV70 / GV80 / GV80 Coupe (Twin-Turbo V6 & E-Supercharger)',
        years: [2025, 2024, 2023, 2022, 2021],
        factoryColors: ['Cardiff Green', 'Bering Blue', 'Matterhorn White Matte', 'Brunswick Green Matte', 'Mauna Red', 'Storr Green', 'Uyuni White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'GV60 (Performance Dual-Motor Electric 483hp Boost)',
        years: [2025, 2024, 2023],
        factoryColors: ['Sao Paulo Lime', 'Hanauma Mint', 'Atacama Copper Matte', 'Uyuni White', 'Matterhorn White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'GMC': [
      VehicleModelSpec(
        model: 'Sierra 1500 / 2500HD / 3500HD (Denali Ultimate, AT4X, 6.6L Duramax)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005],
        factoryColors: ['Onyx Black', 'Titanium Rush Metallic', 'Volcanic Red Tintcoat', 'White Frost Tricoat', 'Desert Sand Metallic', 'Thunderstorm Gray', 'Sterling Metallic', 'Pacific Blue Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Yukon / Yukon XL (Denali Ultimate / AT4 6.2L V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005],
        factoryColors: ['Hunter Metallic', 'Midnight Blue Metallic', 'Onyx Black', 'Pearl White Tricoat', 'Redwood Metallic', 'Downpour Metallic', 'Sterling Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Hummer EV (SUV & Pickup 1000hp CrabWalk & Omega Edition)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Neptune Blue Matte (Omega Edition)', 'Interstellar White', 'Void Black', 'Deep Aurora Metallic (Bronze)', 'Supernova Metallic', 'After Burn Orange', 'Meteorite Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Canyon AT4X AEV / Syclone / Typhoon (Historic Turbo AWD)',
        years: [2025, 2024, 2023, 1993, 1992, 1991],
        factoryColors: ['Dynamic Blue Metallic', 'Solar Flare Metallic', 'Volcanic Red', 'Desert Sand', 'Midnight Solid Black'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Honda': [
      VehicleModelSpec(
        model: 'Civic Type R (FL5, FK8, EP3, EK9 315hp 6-Speed)',
        years: [2025, 2024, 2023, 2021, 2020, 2019, 2018, 2017, 2004, 2000, 1997],
        factoryColors: ['Championship White', 'Boost Blue Pearl', 'Sonic Gray Pearl', 'Rallye Red', 'Crystal Black Pearl', 'Phoenix Yellow (Limited Edition)'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'S2000 (AP1 & AP2 Club Racer 9000 RPM VTEC)',
        years: [2009, 2008, 2007, 2006, 2005, 2004, 2003, 2002, 2001, 2000],
        factoryColors: ['Grand Prix White', 'Apex Blue Pearl (CR)', 'Rio Yellow Pearl', 'Spa Yellow', 'Suzuka Blue Metallic', 'Laguna Blue Pearl', 'Berlina Black', 'Silverstone Metallic', 'New Formula Red'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Civic / Civic Si / Accord (Sport, Hybrid, Touring)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2010, 2006, 2000, 1995, 1990],
        factoryColors: ['Meteorite Gray Metallic', 'Still Night Pearl', 'Platinum White Pearl', 'San Marino Red', 'Crystal Black Pearl', 'Urban Gray Pearl', 'Solar Silver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'CR-V / Pilot / Passport / Ridgeline (Trailsport Off-Road)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005],
        factoryColors: ['Diffused Sky Blue Pearl', 'Obsidian Blue Pearl', 'Canyon River Blue Metallic', 'Radiant Red Metallic', 'Sonic Gray Pearl', 'Platinum White Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Hummer': [
      VehicleModelSpec(
        model: 'H1 / H2 / H3 / H3T (V8 Off-Road Icons)',
        years: [2010, 2009, 2008, 2007, 2006, 2005, 2004, 2003, 2002, 2000, 1998, 1995],
        factoryColors: ['Solar Flare Yellow', 'Black Onyx', 'Desert Tan', 'Pewter Metallic', 'Victory Red', 'Birch White', 'Sage Green'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Hyundai': [
      VehicleModelSpec(
        model: 'Ioniq 5 N / Elantra N (641hp Drift Mode & Track Hot Sedans)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Performance Blue (Matte & Gloss)', 'Soultronic Orange Pearl', 'Cyber Gray Metallic', 'Abyss Black Pearl', 'Atlas White', 'Ecotronic Gray Matte', 'Intense Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Palisade / Santa Fe / Tucson / Sonata (Calligraphy & N Line)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012, 2010],
        factoryColors: ['Robust Emerald Pearl', 'Terracotta Orange', 'Moonlight Cloud Blue', 'Hyper White', 'Abyss Black Pearl', 'Hampton Gray', 'Serenity White Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Genesis Coupe 3.8 Track / Veloster N (RWD & Hot Hatch)',
        years: [2022, 2021, 2020, 2019, 2016, 2015, 2013, 2010],
        factoryColors: ['Performance Blue', 'Racing Red', 'Chalk White', 'Tsukuba Red', 'Interlagos Yellow', 'Mirabeau Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Infiniti': [
      VehicleModelSpec(
        model: 'Q50 Red Sport 400 / Q60 Red Sport (400hp Twin-Turbo V6)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016],
        factoryColors: ['Dynamic Sunstone Red', 'Slate Gray', 'Grand Blue', 'Midnight Black', 'Majestic White', 'Graphite Shadow', 'Iridium Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'QX80 / QX60 / QX50 / QX55 (Autograph Luxury)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012, 2010],
        factoryColors: ['Dynamic Metal', 'Grand Blue', 'Moonbow Blue', 'Anthracite Gray', 'Black Obsidian', 'Mineral Black', 'Liquid Platinum'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'G35 / G37 Coupe & Sedan / FX35 / FX50 (V8 Sport)',
        years: [2013, 2012, 2011, 2010, 2008, 2007, 2005, 2003],
        factoryColors: ['Athens Blue', 'Vibrant Red', 'Black Obsidian', 'Liquid Platinum', 'Moonlight White', 'Laser Red', 'Lapis Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Jaguar': [
      VehicleModelSpec(
        model: 'F-Type R / SVR / 400 Sport (575hp Supercharged 5.0L V8)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014],
        factoryColors: ['British Racing Green', 'Caldera Red', 'FireBlue Metallic', 'Santorini Black', 'Yulong White', 'Fuji White', 'Madagascar Orange', 'Velocity Blue', 'Desire Red (SVO)'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'F-Pace SVR / I-Pace EV / XKR / XJR (Supercharged V8)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2012, 2008, 2005],
        factoryColors: ['Atacama Orange', 'Sorrento Yellow', 'Ultra Blue', 'Carpathian Grey', 'Eiger Grey', 'Santorini Black', 'Midnight Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Jeep': [
      VehicleModelSpec(
        model: 'Wrangler Rubicon 392 (470hp 6.4L V8) / 4xe / Willy',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2010, 2005, 1997, 1990],
        factoryColors: ['Tuscadero Pink', 'Hydro Blue Pearl', 'Sarge Green', 'Firecracker Red', 'High Velocity Yellow', 'Earl Grey', 'Black', 'Anvil Grey', 'Gobi Tan', 'Snazzberry Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Grand Cherokee Trackhawk (707hp Supercharged Hellcat V8) / SRT / L',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2008, 2006],
        factoryColors: ['Velvet Red Pearl', 'Diamond Black Crystal', 'Silver Zynith', 'Rocky Mountain Pearl', 'Bright White', 'Redline 2 Pearl', 'Green Metallic', 'Granite Crystal'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Grand Wagoneer / Wagoneer (Twin-Turbo Hurricane 510hp)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Midnight Sky (Dark Blue)', 'River Rock', 'Baltic Gray Metallic', 'Diamond Black Crystal', 'Bright White', 'Velvet Red'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Gladiator Rubicon / Mojave (Desert Rated)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Snazzberry Pearl', 'Gobi Tan', 'Gator Green', 'Hydro Blue', 'Granite Crystal', 'Sting-Gray', 'Firecracker Red'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Karma': [
      VehicleModelSpec(
        model: 'Revero / GS-6 / Gyesera (Luxury Plug-in Hybrid GT)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Pacifico Gray', 'Napa Red', 'Corona Del Mar Blue', 'Borrego Black', 'Balboa White', 'Surfer Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Kia': [
      VehicleModelSpec(
        model: 'EV6 GT / EV9 (576hp Dual-Motor AWD Electric)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Ocean Blue (Matte & Gloss)', 'Yacht Blue', 'Panthera Metal', 'Aurora Black Pearl', 'Snow White Pearl', 'Ivory Silver Matte', 'Runway Red'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Stinger GT / GT2 (368hp Twin-Turbo 3.3L V6)',
        years: [2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['HiChroma Red', 'Micro Blue Pearl', 'Ceramic Silver', 'Panthera Metal', 'Aurora Black Pearl', 'Federation Orange', 'Snow White Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Telluride (SX Prestige X-Pro) / Carnival / K5 GT',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Jungle Green', 'Midnight Lake Blue', 'Dark Moss', 'Wolf Gray', 'Ebony Black', 'Glacial White Pearl', 'Passion Red'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Koenigsegg': [
      VehicleModelSpec(
        model: 'Jesko Attack / Absolut (1600hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021],
        factoryColors: ['Tang Orange', 'Imperial Blue', 'Sweet Mandarin', 'Ghost White', 'Exposed Clear Green Carbon', 'Crystal Flake White'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Gemera / Regera / Agera RS / One:1',
        years: [2024, 2023, 2022, 2020, 2018, 2016, 2015, 2014],
        factoryColors: ['Exposed Red Tinted Carbon', 'Bespoke Blue Carbon', 'Candy Apple Red', 'Moon Silver', 'Agera Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Lamborghini': [
      VehicleModelSpec(
        model: 'Huracan EVO / STO / Tecnica / Sterrato (Naturally Aspirated V10)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015],
        factoryColors: ['Verde Mantis (Pearl Green)', 'Giallo Inti (Pearl Yellow)', 'Arancio Borealis (Pearl Orange)', 'Blu Cepheus', 'Grigio Telesto', 'Nero Noctis', 'Bianco Monocerus', 'Viola Pasifae', 'Verde Gea (Matte)'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Urus / Performante / S / SE (Plug-in Hybrid 789hp)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Giallo Auge (Yellow)', 'Arancio Argos', 'Verde Scandal', 'Nero Helene', 'Blu Eleos', 'Grigio Kres', 'Rosso Anteros', 'Verde Viper'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Aventador SVJ / Ultimae / SV / S (770hp Naturally Aspirated V12)',
        years: [2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2014, 2013, 2012],
        factoryColors: ['Verde Alceo (Matte Green)', 'Rosso Efesto', 'Arancio Atlas', 'Blu Nethuns', 'Grigio Titans Matte', 'Nero Pegaso', 'Giallo Orion'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Revuelto / Temerario (1001hp V12 Hybrid & 920hp V8 Twin-Turbo)',
        years: [2025, 2024],
        factoryColors: ['Arancio Apodis', 'Verde Turbine', 'Bianco Asopo', 'Blu Astraeus', 'Nero Nemesis Matte', 'Giallo Conte', 'Blu Uranus'],
        defaultImage: 'https://images.unsplash.com/photo-1592198084033-aade902d1aae?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Gallardo / Murcielago / Diablo / Countach',
        years: [2014, 2013, 2010, 2008, 2006, 2004, 2001, 1999, 1995, 1989],
        factoryColors: ['Giallo Midas (Pearl Yellow)', 'Verde Ithaca', 'Arancio Ymir', 'Nero Aldebaran', 'Blu Hera', 'Rosso Siviglia'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Land Rover / Range Rover': [
      VehicleModelSpec(
        model: 'Range Rover / SV / Autobiography (Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005],
        factoryColors: ['Sunset Gold Satin (Matte)', 'Carpathian Grey', 'Belgravia Green', 'Santorini Black', 'Hakuba Silver', 'Batumi Gold', 'Charente Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Range Rover Sport / SV / SVR (626hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010],
        factoryColors: ['Flux Silver (Matte)', 'Firenze Red', 'Estoril Blue', 'Varesine Blue', 'Giola Green', 'Santorini Black', 'Fuji White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Defender 90 / 110 / 130 / OCTA (626hp 4.4L Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 1997, 1994],
        factoryColors: ['Petra Copper Matte', 'Gondwana Stone', 'Pangea Green', 'Tasman Blue', 'Sedona Red', 'Carpathian Grey', 'Fuji White', 'Santorini Black'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Range Rover Velar / Discovery / Evoque',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Arroios Grey', 'Byron Blue', 'Lantau Bronze', 'Santorini Black', 'Hakuba Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Lexus': [
      VehicleModelSpec(
        model: 'LFA (4.8L V10 9000 RPM Supercar)',
        years: [2012, 2011],
        factoryColors: ['Whitest White', 'Pearl Yellow', 'Passion Red', 'Starlight Black Metallic', 'Pearl Blue', 'Matte Black', 'Brown Stone', 'Steel Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'LC 500 / LC 500 Convertible (Naturally Aspirated 5.0L V8 471hp)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Structural Blue (Nanotech Coating)', 'Flare Yellow', 'Infrared (Metallic Red)', 'Nori Green Pearl', 'Caviar Black', 'Cloudburst Gray', 'Ultra White', 'Copper Crest', 'Cadmium Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'IS 500 F Sport Performance / RC F / GS F (5.0L V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2015, 2014, 2010],
        factoryColors: ['Molten Pearl (Orange)', 'Grecian Water Blue', 'Incognito (Flat Grey)', 'Infrared', 'Ultra White', 'Caviar Black', 'Matador Red Mica', 'Ultrasonic Blue Mica 2.0'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'GX 550 / LX 600 / TX / RX 500h (Overtrail Twin-Turbo)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018, 2015, 2010, 2005],
        factoryColors: ['Earth (Two-Tone Tan)', 'Nori Green Pearl', 'Eminent White Pearl', 'Nightfall Mica', 'Caviar Black', 'Atomic Silver', 'Incognito Gray'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Lincoln': [
      VehicleModelSpec(
        model: 'Navigator / Aviator (Black Label 450hp Twin-Turbo)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005],
        factoryColors: ['Chroma Caviar Dark Gray', 'Flight Blue Metallic', 'Diamond Red Metallic', 'Infinite Black Metallic', 'Pristine White Metallic', 'Ocean Drive Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Nautilus / Corsair (All-Digital Luxury)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Blue Panther Metallic', 'Red Carpet Metallic', 'Asher Gray Metallic', 'Infinite Black', 'Crystal White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Continental / Town Car (Coach Door Edition)',
        years: [2020, 2019, 2018, 2017, 2011, 2005, 1998, 1965],
        factoryColors: ['Rhapsody Blue', 'Chroma Crystal Blue', 'Pure White', 'Infinite Black', 'Burgundy Velvet'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Lotus': [
      VehicleModelSpec(
        model: 'Emira (Supercharged V6 / Turbo i4 AMG 6-Speed Manual)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Seneca Blue', 'Hethel Yellow', 'Magma Red', 'Dark Verdant (British Racing Green)', 'Shadow Grey', 'Nimbus Grey', 'Cosmos Black', 'Zinc Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Evora GT / Exige / Elise / Esprit V8',
        years: [2021, 2020, 2019, 2018, 2017, 2015, 2011, 2008, 2005, 2002, 1998],
        factoryColors: ['Daytona Blue', 'Formula Red', 'Motorsport Green', 'Solar Yellow', 'Metallic Black', 'Ardent Red', 'Chrome Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Eletre / Evija (Hyper-SUV & 2000hp Electric Hypercar)',
        years: [2025, 2024, 2023],
        factoryColors: ['Natron Red', 'Galloway Green', 'Solar Yellow', 'Starlight Black', 'Kaimu Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Lucid': [
      VehicleModelSpec(
        model: 'Air Sapphire / Grand Touring / Pure (1234hp Tri-Motor)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Sapphire Blue Metallic', 'Stellar White', 'Infinite Black', 'Quantum Grey', 'Zenith Red', 'Cosmos Silver', 'Fathom Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Gravity (Luxury 3-Row Electric SUV)',
        years: [2026, 2025],
        factoryColors: ['Aurora Green', 'Lunar Titanium', 'Stellar White', 'Infinite Black', 'Zenith Red'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Maserati': [
      VehicleModelSpec(
        model: 'MC20 / Cielo Supercar (621hp Twin-Turbo Nettuno V6)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Bianco Audace (Matte White)', 'Giallo Genio (Yellow)', 'Rosso Vincente', 'Blu Infinito', 'Nero Enigma', 'Grigio Mistero', 'Verde Royale', 'Aquamarina'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'GranTurismo / Trofeo / Folgore EV (Twin-Turbo V6 & 760hp EV)',
        years: [2025, 2024, 2019, 2018, 2017, 2015, 2012, 2010, 2008],
        factoryColors: ['Blu Nobile', 'Rosso GranTurismo', 'Grigio Maratea', 'Nero Ribelle', 'Bianco Astro', 'Giallo Corse', 'Blu Inchiostro'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Grecale / Levante Trofeo (Ferrari-Built Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Giallo Corse', 'Blu Emozione', 'Grigio Lava', 'Bianco Luce', 'Nero Ribelle', 'Rosso Magma'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Maybach': [
      VehicleModelSpec(
        model: 'S 680 (6.0L Twin-Turbo V12) / S 580 / GLS 600',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018, 2015, 2010, 2005],
        factoryColors: ['Two-Tone Kalahari Gold & Obsidian Black', 'Two-Tone Cirrus Silver & Nautical Blue', 'MANUFAKTUR Diamond White Bright', 'Rubellite Red Metallic', 'Obsidian Black', 'Emerald Green'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Mazda': [
      VehicleModelSpec(
        model: 'MX-5 Miata (ND3, ND2, NC, NB, NA 6-Speed Club)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2012, 2008, 2002, 1999, 1994, 1990],
        factoryColors: ['Soul Red Crystal Metallic (46V)', 'Polymetal Grey Metallic', 'Zircon Sand Metallic', 'Deep Crystal Blue Mica', 'Jet Black Mica', 'Snowflake White Pearl', 'Classic Red', 'Mariner Blue', 'Sunburst Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Mazda3 / CX-30 / CX-50 / CX-90 / CX-70 (Inline-6 Turbo & AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015],
        factoryColors: ['Soul Red Crystal (46V)', 'Machine Grey Metallic', 'Polymetal Grey', 'Artisan Red Premium', 'Rhodium White Premium', 'Platinum Quartz Metallic', 'Zircon Sand', 'Melting Copper'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'RX-7 (FD3S & FC3S Twin-Turbo) / RX-8 (Rotary Wankel)',
        years: [2011, 2010, 2008, 2004, 2002, 1998, 1995, 1994, 1993, 1991, 1988],
        factoryColors: ['Innocent Blue Mica', 'Vintage Red', 'Chaste White', 'Montego Blue Metallic', 'Brilliant Black', 'Velocity Red Mica', 'Sunlight Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Mazdaspeed3 / Mazdaspeed6 (Turbocharged AWD / FWD)',
        years: [2013, 2012, 2010, 2008, 2007, 2006],
        factoryColors: ['Velocity Red Mica', 'Black Mica', 'Liquid Silver Metallic', 'Cosmic Blue', 'True Red'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'McLaren': [
      VehicleModelSpec(
        model: '750S / 720S / 765LT (Longtail 765hp Twin-Turbo V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Papaya Spark (Orange)', 'Curacao Blue', 'Lantana Purple', 'Sarthe Grey', 'Volcano Red', 'Onyx Black', 'Paris Blue', 'Smoked White', 'Burton Blue', 'MSO Cerulean Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Artura / GT / GTS (Twin-Turbo V6 Hybrid 690hp)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Flux Green', 'Ember Orange', 'Plateau Grey', 'Aurora Blue', 'Silica White', 'Tokyo Cyan', 'Supernova Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'P1 / Senna / Speedtail / 675LT / 600LT / 570S (Ultimate Series)',
        years: [2021, 2020, 2019, 2018, 2016, 2015, 2014, 2013],
        factoryColors: ['McLaren Orange', 'Volcano Yellow', 'Amethyst Black', 'Trofeo Copper', 'Chiron Blue', 'Chicane Grey', 'Mira Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Mercedes-Benz': [
      VehicleModelSpec(
        model: 'AMG GT Coupe / Black Series / 63 S E-Performance (805hp+)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016],
        factoryColors: ['AMG Green Hell Magno (Matte)', 'Sun Yellow', 'Selenite Grey Magno', 'Obsidian Black Metallic', 'MANUFAKTUR Opalite White', 'Designo Brilliant Blue Magno', 'Hyper Blue Metallic', 'Magmabeam Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1618843479313-40f8afb4b4d8?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'G-Class G63 AMG / G550 / G580 with EQ Tech (Twin-Turbo V8 & Electric)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2008, 2002],
        factoryColors: ['Night Black Magno (Matte)', 'Arabian Grey', 'Olive Green Magno', 'Polar White', 'Designo Platinum Magno', 'Copper Orange Magno', 'China Blue', 'Deep White Magno', 'Emerald Green Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1520050206274-a1ae44613e6d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'C63 / E63 S / S63 AMG / SL 63 AMG (Handcrafted V8 Biturbo)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2008, 2005],
        factoryColors: ['Graphite Grey Metallic', 'Brilliant Blue Magno', 'Designo Diamond White', 'Iridium Silver Metallic', 'Obsidian Black', 'Monza Grey Magno', 'Selenite Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'C-Class / E-Class / S-Class / GLE / GLS (Executive Sedans & SUVs)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005, 2000, 1995, 1990],
        factoryColors: ['Nautical Blue Metallic', 'Emerald Green Metallic', 'Mojave Silver Metallic', 'Obsidian Black', 'High-Tech Silver', 'Selenite Grey', 'Polar White'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'SLS AMG / 300SL Gullwing / SLR McLaren (Gullwing Supercars)',
        years: [2015, 2014, 2013, 2012, 2011, 2010, 2009, 2006, 1957, 1955],
        factoryColors: ['AMG Le Mans Red', 'AMG Solarbeam Yellow', 'Alubeam Silver', 'Obsidian Black', 'Designo Magno Alanite Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Mercury': [
      VehicleModelSpec(
        model: 'Marauder (4.6L DOHC V8) / Grand Marquis / Cougar',
        years: [2004, 2003, 1999, 1995, 1990, 1986, 1970, 1968],
        factoryColors: ['Gloss Black', 'Dark Toreador Red Pearl', 'Silver Birch Metallic', 'Dark Blue Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'MINI': [
      VehicleModelSpec(
        model: 'John Cooper Works (JCW) / Cooper S / Countryman / GP3 (Turbo)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2012, 2008, 2004],
        factoryColors: ['Rebel Green w/ Chili Red Roof', 'Chili Red', 'British Racing Green IV', 'Island Blue Metallic', 'Nanuq White', 'Midnight Black II', 'Zesty Yellow', 'Racing Grey Matte (GP)'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Mitsubishi': [
      VehicleModelSpec(
        model: 'Lancer Evolution (Evo X, IX, VIII 4G63 Turbo AWD)',
        years: [2015, 2014, 2013, 2012, 2010, 2008, 2006, 2005, 2004, 2003],
        factoryColors: ['Octane Blue Pearl', 'Rally Red', 'Wicked White', 'Phantom Black Pearl', 'Apex Silver Metallic', 'Tarmac Black', 'Graphite Grey Pearl', 'Ralliart Red'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '3000GT VR-4 (Twin-Turbo AWD 4WS) / Eclipse GSX Turbo',
        years: [1999, 1998, 1997, 1996, 1995, 1994, 1993, 1991],
        factoryColors: ['Caracas Red', 'Panama Green Pearl', 'Solenoid Blue', 'Monarch Green', 'Fiji Blue Pearl', 'Gloss Black'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Outlander / Outlander PHEV / Eclipse Cross',
        years: [2025, 2024, 2023, 2022, 2020, 2018],
        factoryColors: ['Red Diamond', 'White Diamond', 'Black Diamond', 'Cosmic Blue Metallic', 'Deep Bronze Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Nissan': [
      VehicleModelSpec(
        model: 'GT-R (R35 Nismo, T-Spec, Track Edition 600hp AWD)',
        years: [2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2016, 2015, 2012, 2010, 2009],
        factoryColors: ['Bayside Blue (Wangan Blue)', 'Midnight Purple (Special Edition)', 'Millennium Jade', 'Stealth Gray (Nismo)', 'Solid Red', 'Jet Black Pearl', 'Pearl White Tricoat', 'Super Silver Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Skyline GT-R (R34, R33, R32 RB26DETT AWD Legends)',
        years: [2002, 2001, 2000, 1999, 1998, 1997, 1995, 1994, 1992, 1989],
        factoryColors: ['Bayside Blue (TV2)', 'Midnight Purple II (LV4)', 'Midnight Purple III (LX0)', 'Millennium Jade (JW0)', 'Gun Grey Metallic (KH2)', 'Active Red', 'Sonic Silver (KR4)'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Z / 370Z / 350Z / 300ZX / 240Z (Twin-Turbo & Nismo)',
        years: [2025, 2024, 2023, 2020, 2018, 2015, 2012, 2008, 2006, 2003, 1996, 1990, 1973, 1970],
        factoryColors: ['Ikazuchi Yellow Tricoat', 'Seiran Blue', 'Passion Red Tricoat', 'Boulder Gray', 'Black Diamond Pearl', 'Ultra Yellow', 'Le Mans Sunset Orange', 'Safari Gold'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Titan / Frontier / Armada / Pathfinder (PRO-4X Off-Road)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018, 2015],
        factoryColors: ['Baja Storm (Sand Metallic)', 'Tactical Green Metallic', 'Cardinal Red Metallic', 'Super Black', 'Glacier White', 'Deep Blue Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Oldsmobile': [
      VehicleModelSpec(
        model: '442 / Cutlass 442 W-30 (Hurst / Olds 455 V8)',
        years: [1987, 1985, 1983, 1972, 1970, 1969, 1968, 1964],
        factoryColors: ['Ebony Black w/ Gold Stripes', 'Viking Blue', 'Rally Red', 'Bamboo Cream', 'Sterling Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Pagani': [
      VehicleModelSpec(
        model: 'Utopia / Huayra / Zonda / Codalunga (AMG V12 Manual Supercars)',
        years: [2025, 2024, 2023, 2022, 2020, 2018, 2016, 2014, 2012, 2008, 2005, 2002],
        factoryColors: ['Visible Raw Blue Carbon', 'Rinascimento Bronze', 'Pearl White w/ Italian Tricolore', 'Giallo Modena Carbon', 'Rosso Monza Carbon', 'Silverstone Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Plymouth': [
      VehicleModelSpec(
        model: 'Barracuda Hemi \'Cuda / Road Runner Superbird / Prowler',
        years: [2002, 2001, 2000, 1999, 1997, 1971, 1970, 1969, 1968],
        factoryColors: ['In-Violet (Plum Crazy)', 'TorRed (Hemi Orange)', 'Vitamin C Orange', 'Lime Light Green', 'Prowler Purple Metallic', 'Prowler Yellow', 'Black'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Polestar': [
      VehicleModelSpec(
        model: 'Polestar 1 / 2 / 3 / 4 (Performance Pack & BST Edition)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Swedish Gold Accents w/ Battleship Grey', 'Thunder Grey', 'Snow White', 'Midnight Blue', 'Magnesium', 'Void Black', 'Jupiter Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Pontiac': [
      VehicleModelSpec(
        model: 'Firebird Trans Am WS6 / Ram Air / Bandit 455',
        years: [2002, 2001, 2000, 1999, 1998, 1979, 1977, 1973, 1969],
        factoryColors: ['Starlight Black w/ Gold Screaming Chicken', 'Sunset Orange Metallic', 'Bright Red', 'Navy Blue Metallic', 'Arctic White'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'G8 GXP (6.2L LS3 V8 6-Speed) / GTO (6.0L LS2) / Solstice GXP',
        years: [2009, 2008, 2006, 2005, 2004],
        factoryColors: ['Brazen Metallic (Orange)', 'Impulse Blue Metallic', 'Torrid Red', 'Phantom Black Metallic', 'Liquid Red', 'Pacific Slate Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Porsche': [
      VehicleModelSpec(
        model: '911 GT3 / GT3 RS / S/T / GT2 RS (992, 991, 997, 996)',
        years: [2025, 2024, 2023, 2022, 2021, 2019, 2018, 2016, 2015, 2011, 2007, 2004],
        factoryColors: ['Shark Blue (D5C)', 'Guards Red (84A)', 'GT Silver Metallic (M7Z)', 'Python Green', 'Solid Black (041)', 'Chalk (M9A)', 'Lava Orange', 'Ultraviolet Purple', 'Signal Yellow (PTS)', 'Rubystar Neo', 'Arctic Grey', 'Ice Grey Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1614162692292-7ac56d7f7f1e?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '911 Carrera / Turbo S / Targa / Dakar / Sport Classic',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2008, 2005, 1998, 1995, 1989, 1974, 1965],
        factoryColors: ['Gentian Blue Metallic', 'Agate Grey Metallic', 'Jet Black Metallic', 'Carrara White Metallic', 'Racing Yellow', 'Aventurine Green Metallic', 'Night Blue Metallic', 'Ice Grey Metallic', 'Oak Green Metallic Neo', 'Shade Green Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '718 Cayman GT4 RS / Spyder RS / Boxster GTS (4.0L 9000 RPM)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2014, 2010, 2006],
        factoryColors: ['Arctic Grey', 'Guards Red', 'Shark Blue', 'Black', 'White', 'Frozen Blue Metallic', 'Miami Blue', 'Gentian Blue', 'Racing Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Taycan Turbo S / 4S / Cross Turismo (Electric Super-Sedan)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Frozen Berry Metallic', 'Neptune Blue', 'Volcano Grey Metallic', 'Ice Grey Metallic', 'Dolomite Silver Metallic', 'Mamba Green Metallic', 'Provence', 'Shade Green Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1617814076367-b759c7d7e738?w=1200&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Macan / Cayenne (GTS, Turbo GT 650hp V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2010, 2005],
        factoryColors: ['Carmine Red', 'Papaya Metallic', 'Night Blue Metallic', 'Moonlight Blue Metallic', 'Chalk / Crayon', 'Algarve Blue Metallic', 'Montego Blue Metallic', 'Carrara White'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Carrera GT (V10 Manual) / 918 Spyder / 959 (Halo Supercars)',
        years: [2015, 2014, 2013, 2006, 2005, 2004, 1988, 1987],
        factoryColors: ['GT Silver Metallic', 'Fayence Yellow', 'Basalt Black', 'Liquid Metal Silver', 'Guards Red', 'Acid Green Accents'],
        defaultImage: 'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Ram': [
      VehicleModelSpec(
        model: '1500 TRX / RHO / Rebel (702hp Supercharged 6.2L V8)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019],
        factoryColors: ['Ignition Orange', 'Hydro Blue Pearl', 'Flame Red', 'Diamond Black Crystal', 'Billet Silver Metallic', 'Granite Crystal Metallic', 'Havoc Yellow', 'Ceramic Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '2500 / 3500 Heavy Duty / Power Wagon (Cummins Turbo Diesel 1075 lb-ft)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010],
        factoryColors: ['Patriot Blue Pearl', 'Delmonico Red Pearl', 'Bright White', 'Diamond Black Crystal', 'Olive Green Pearl', 'Ceramic Grey', 'Granite Crystal'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Ram SRT-10 (8.3L Viper V10 Manual Super Truck)',
        years: [2006, 2005, 2004],
        factoryColors: ['Flame Red', 'Black Clearcoat', 'Bright Silver Metallic', 'Night Runner Special Edition'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Rivian': [
      VehicleModelSpec(
        model: 'R1T (Quad-Motor 1025hp Electric Pickup)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Rivian Blue', 'Compass Yellow', 'Forest Green', 'Launch Green', 'Red Canyon', 'El Cap Granite', 'Midnight Black', 'Glacier White', 'LA Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'R1S / R2 / R3X (Quad-Motor Electric SUV)',
        years: [2026, 2025, 2024, 2023, 2022],
        factoryColors: ['Forest Green', 'Rivian Blue', 'Red Canyon', 'Limestone (Flat Grey)', 'LA Silver', 'Midnight Black', 'Glacier White'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Rolls-Royce': [
      VehicleModelSpec(
        model: 'Cullinan / Black Badge (6.75L Twin-Turbo V12 Luxury SUV)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019],
        factoryColors: ['Black Badge Diamond Black', 'Salamanca Blue', 'Magma Red', 'Dark Emerald', 'Petra Gold', 'English White', 'Forge Yellow', 'Iguazu Blue'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Ghost / Phantom / Spectre / Wraith / Dawn (Bespoke Luxury)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018, 2015, 2010, 2005],
        factoryColors: ['Chartreuse Yellow', 'Tempest Grey', 'Iguazu-Blue', 'Bespoke Diamond Black', 'Belladonna Purple', 'Wittering Blue', 'Arctic White', 'Midnight Sapphire'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Saab': [
      VehicleModelSpec(
        model: '9-3 Aero / Turbo X / Viggen / 9-5 Aero (Turbocharged)',
        years: [2011, 2010, 2009, 2008, 2007, 2006, 2004, 2002, 1999, 1995, 1990],
        factoryColors: ['Jet Black Metallic (Titanium Accents)', 'Laser Red', 'Nocturne Blue', 'Lightning Yellow (Viggen)', 'Silver Metallic', 'Monte Carlo Yellow'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Saturn': [
      VehicleModelSpec(
        model: 'Sky Red Line (2.0L Turbo 260hp RWD) / Ion Red Line',
        years: [2010, 2009, 2008, 2007, 2006, 2004],
        factoryColors: ['Sunburst Yellow', 'Chili Red', 'Midnight Blue', 'Silver Pearl', 'Black Onyx', 'Polar White'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Scion': [
      VehicleModelSpec(
        model: 'FR-S (Boxer 6-Speed RWD) / tC / xB',
        years: [2016, 2015, 2014, 2013, 2012, 2010, 2006],
        factoryColors: ['Hot Lava (Orange)', 'Ultramarine Blue', 'Firestorm Red', 'Raven Black', 'Whiteout Pearl', 'Asphalt Metallic'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Shelby': [
      VehicleModelSpec(
        model: 'Shelby Cobra 427 S/C / Series 1 / GT500KR',
        years: [2024, 2020, 2015, 2008, 1999, 1968, 1966, 1965],
        factoryColors: ['Guardsman Blue w/ White Stripes', 'Wimbledon White', 'Raven Black', 'Shelby Red'],
        defaultImage: 'https://images.unsplash.com/photo-1584345604476-8ec5e12e42dd?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Smart': [
      VehicleModelSpec(
        model: 'Fortwo (Brabus / Electric Drive)',
        years: [2019, 2018, 2017, 2016, 2015, 2012, 2008],
        factoryColors: ['Lava Orange / Black Tridion Cell', 'Midnight Blue', 'Rally Red', 'Crystal White', 'Matt Anthracite'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Subaru': [
      VehicleModelSpec(
        model: 'WRX / STI (VAB, VB, GR, GV, GD Hawkeye, Blobeye, 22B Boxer Turbo AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2011, 2006, 2004, 2002, 1998],
        factoryColors: ['World Rally Blue Pearl (WR Blue)', 'Solar Orange Pearl', 'Ignition Red', 'Ceramic White', 'Magnetite Gray Metallic', 'Crystal Black Silica', 'Sonic Yellow', 'Pure White'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'BRZ (tS / Limited / Series.Purple 6-Speed RWD)',
        years: [2025, 2024, 2023, 2022, 2020, 2018, 2016, 2013],
        factoryColors: ['WR Blue Pearl', 'Sapphire Blue Pearl', 'Track bRED', 'Ignition Red', 'Ice Silver Metallic', 'Crystal White Pearl', 'Galaxy Blue Silica'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Outback / Forester / Crosstrek / Ascent (Wilderness Off-Road Edition)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005],
        factoryColors: ['Geyser Blue (Wilderness Exclusive)', 'Autumn Green Metallic', 'Offshore Blue Metallic', 'Cascade Green Silica', 'Crimson Red Pearl', 'Crystal White Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Suzuki': [
      VehicleModelSpec(
        model: 'Jimny / Samurai / Sidekick / Grand Vitara (4x4 Off-Road)',
        years: [2024, 2022, 2020, 2018, 2012, 2008, 1995, 1988],
        factoryColors: ['Kinetic Yellow', 'Jungle Green', 'Brisk Blue Metallic', 'Superior White', 'Medium Gray'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Tesla': [
      VehicleModelSpec(
        model: 'Model 3 (Performance Highland / Long Range / RWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018],
        factoryColors: ['Solid Black (PBSB)', 'Ultra Red', 'Pearl White Multi-Coat', 'Deep Blue Metallic', 'Stealth Grey', 'Midnight Silver Metallic', 'Quicksilver'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Model Y (Performance / Long Range / Juniper AWD)',
        years: [2025, 2024, 2023, 2022, 2021, 2020],
        factoryColors: ['Stealth Grey', 'Quicksilver Metallic', 'Ultra Red', 'Solid Black', 'Pearl White Multi-Coat', 'Deep Blue Metallic', 'Midnight Cherry Red'],
        defaultImage: 'https://images.unsplash.com/photo-1617788138017-80ad40651399?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Model S Plaid (1020hp Tri-Motor 0-60 in 1.99s)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2014, 2012],
        factoryColors: ['Ultra Red', 'Solid Black', 'Deep Blue Metallic', 'Pearl White Multi-Coat', 'Lunar Silver', 'Midnight Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Model X Plaid / Long Range (Falcon Wing Doors)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016],
        factoryColors: ['Ultra Red', 'Stealth Grey', 'Solid Black', 'Pearl White Multi-Coat', 'Deep Blue Metallic', 'Lunar Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Cybertruck (Cyberbeast 845hp Tri-Motor / All-Wheel Drive)',
        years: [2025, 2024],
        factoryColors: ['Raw Stainless Steel 301', 'Matte Satin Black Wrap', 'Matte Satin White Wrap', 'Desert Camo Wrap', 'Stealth Grey Wrap', 'Rose Gold Wrap'],
        defaultImage: 'https://images.unsplash.com/photo-1698877546875-927cb7cbcfb6?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Roadster (Original Lotus-Based & Next-Gen Space Package)',
        years: [2026, 2025, 2012, 2011, 2010, 2008],
        factoryColors: ['Signature Red', 'Radiant Red', 'Thunder Grey', 'Very Orange', 'Electric Blue', 'Jet Black'],
        defaultImage: 'https://images.unsplash.com/photo-1542362567-b07e54358753?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Toyota': [
      VehicleModelSpec(
        model: 'GR Supra 3.0 / A90 / A80 MKIV Turbo (2JZ-GTE & B58 6-Speed)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 1998, 1997, 1995, 1994, 1993, 1989],
        factoryColors: ['Mikan Blast (Orange)', 'Stratosphere Blue', 'Renaissance Red 2.0', 'Nitro Yellow', 'Phantom Matte Grey', 'Absolute Zero White', 'Nocturnal Black', 'Royal Sapphire Pearl', 'Super White'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'GR Corolla (Circuit / Morizo) / GR86 (Boxer RWD)',
        years: [2025, 2024, 2023, 2022],
        factoryColors: ['Blue Flame', 'Heavy Metal (Grey)', 'Solar Shift Orange', 'Track bRED', 'Supersonic Red', 'Ice Cap White', 'Black'],
        defaultImage: 'https://images.unsplash.com/photo-1580273916550-e323be2ae537?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Tacoma / Tundra (TRD Pro / Trailhunter / i-FORCE MAX Hybrid)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2012, 2008, 2004],
        factoryColors: ['Terra (Red Ochre)', 'Mudbath (Trailhunter)', 'Solar Octane', 'Lunar Rock', 'Army Green', 'Cement Grey', 'Voodoo Blue', 'Cavalry Blue', 'Magnetic Grey Metallic', 'Underground'],
        defaultImage: 'https://images.unsplash.com/photo-1558441719-ef0ce0f6244f?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Land Cruiser (1958, First Edition, LC250, LC200, LC100, LC80, FJ40) / 4Runner (TRD Pro)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005, 2000, 1995, 1990, 1985, 1975],
        factoryColors: ['Trail Dust Tan w/ Grayscale Roof', 'Heritage Blue w/ Grayscale Roof', 'Underground Grey', 'Lime Rush', 'Quicksand', 'Midnight Black Metallic', 'Ice Cap', 'Terra'],
        defaultImage: 'https://images.unsplash.com/photo-1533473359331-0135ef1b58bf?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Camry / RAV4 / Grand Highlander / Crown / Prius (XSE, Prime)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2015, 2010, 2005],
        factoryColors: ['Ocean Gem Blue', 'Reservoir Blue', 'Wind Chill Pearl', 'Midnight Black', 'Ruby Flare Pearl', 'Heavy Metal', 'Cutting Edge Silver'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'VinFast': [
      VehicleModelSpec(
        model: 'VF 8 / VF 9 / VF 7 (All-Electric Pininfarina-Designed SUVs)',
        years: [2025, 2024, 2023],
        factoryColors: ['VinFast Blue', 'Brahminy White', 'Desat Silver', 'Neptune Grey', 'Crimson Red', 'Jet Black', 'Sunset Orange'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Volkswagen': [
      VehicleModelSpec(
        model: 'Golf R / GTI (Mk8.5, Mk8, Mk7, Mk6, Mk5, Mk4 R32 Turbo AWD & 6-Speed)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2017, 2015, 2012, 2008, 2004, 2000, 1995, 1990],
        factoryColors: ['Lapiz Blue Metallic', 'Pomelo Yellow Metallic', 'Kings Red Metallic', 'Oryx White Pearl', 'Deep Black Pearl', 'Moonstone Grey', 'Tornado Red', 'Deep Blue Pearl (R32)'],
        defaultImage: 'https://images.unsplash.com/photo-1563720223185-11003d516935?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'ID.4 / ID. Buzz (Electric Microbus) / Atlas / Jetta GLI',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2018],
        factoryColors: ['Pomelo Yellow', 'Energetic Orange w/ Candy White Roof', 'Bay Leaf Green', 'Tourmaline Blue Metallic', 'Aurora Red Metallic', 'Pure Grey', 'Mahi Green'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'Corrado VR6 / Phaeton W12 / Touareg V10 TDI (Legendary Engines)',
        years: [2008, 2006, 2004, 1995, 1994, 1993, 1992],
        factoryColors: ['Flash Red', 'Classic Green Pearl', 'Moonlight Blue Pearl', 'Reflex Silver', 'Black Magic Pearl'],
        defaultImage: 'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=900&auto=format&fit=crop&q=80',
      ),
    ],
    'Volvo': [
      VehicleModelSpec(
        model: 'V60 / S60 Polestar Engineered (455hp Plug-in Hybrid Brembo / Ohlins)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019],
        factoryColors: ['Swedish Gold Accents w/ Onyx Black', 'Thunder Grey Metallic', 'Crystal White Metallic', 'Fusion Red Metallic', 'Denim Blue Metallic', 'Silver Dawn'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: 'XC90 / XC60 / EX90 / EX30 (Luxury & Twin-Motor Performance Electric)',
        years: [2025, 2024, 2023, 2022, 2021, 2020, 2019, 2018, 2016, 2012, 2005],
        factoryColors: ['Cloud Blue', 'Moss Yellow', 'Denim Blue Metallic', 'Pine Grey Metallic', 'Crystal White', 'Onyx Black', 'Bright Dusk Metallic', 'Vapour Grey'],
        defaultImage: 'https://images.unsplash.com/photo-1519641471654-76ce0107ad1b?w=900&auto=format&fit=crop&q=80',
      ),
      VehicleModelSpec(
        model: '850 T-5R / V70 R (5-Cylinder Turbo Wagons)',
        years: [2007, 2006, 2005, 2004, 1997, 1996, 1995],
        factoryColors: ['Cream Yellow (T-5R Gul)', 'Flash Green Metallic', 'Laser Blue Metallic', 'Titanium Grey', 'Solid Black'],
        defaultImage: 'https://images.unsplash.com/photo-1603584173870-7f23fdae1b7a?w=900&auto=format&fit=crop&q=80',
      ),
    ],
  };

  static List<VehicleModelSpec> getModelsForMake(String make) {
    return makesAndModels[make] ?? [];
  }

  // Returns all known makes — NHTSA API handles model-year filtering dynamically.
  // Local year lists in VehicleModelSpec are incomplete; don't use them to gate makes.
  static List<String> getMakesForYear(int year) => allMakes;

  // Get models for a specific Make AND Year (with graceful fallback to all models for that make)
  static List<VehicleModelSpec> getModelsForMakeAndYear(String make, int year) {
    final specs = makesAndModels[make] ?? [];
    final matching = specs.where((s) => s.years.contains(year)).toList();
    return matching.isNotEmpty ? matching : specs;
  }
}
