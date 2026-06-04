// Conditional export to call JS on Web and run a stub on Mobile/Desktop
export 'web_loader_stub.dart'
    if (dart.library.js) 'web_loader_web.dart';
