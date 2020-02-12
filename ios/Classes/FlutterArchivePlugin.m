#import "FlutterArchivePlugin.h"
#import <flutter_archive/flutter_archive-Swift.h>

@implementation FlutterArchivePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterArchivePlugin registerWithRegistrar:registrar];
}
@end
