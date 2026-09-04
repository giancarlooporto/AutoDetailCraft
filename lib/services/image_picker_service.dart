// Conditional import: uses dart:html on web, stub on all other platforms
import 'dart:typed_data';

import 'image_picker_service_stub.dart'
    if (dart.library.html) 'image_picker_service_web.dart';

export 'image_picker_service_stub.dart'
    if (dart.library.html) 'image_picker_service_web.dart'
    show pickImageFromDevice;
