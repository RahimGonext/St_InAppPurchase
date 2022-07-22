#import "InAppPurchasePlugin.h"
#if __has_include(<in_app_purchase/in_app_purchase-Swift.h>)
#import <in_app_purchase/in_app_purchase-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "in_app_purchase-Swift.h"
#endif

@implementation InAppPurchasePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftInAppPurchasePlugin registerWithRegistrar:registrar];
}
@end
