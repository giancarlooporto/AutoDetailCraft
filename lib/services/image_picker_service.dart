// Conditional export: uses dart:html on web, stub on all other platforms
export 'image_picker_service_stub.dart'
    if (dart.library.html) 'image_picker_service_web.dart'
    show pickImageFromDevice, pickMultipleImagesFromDevice;

