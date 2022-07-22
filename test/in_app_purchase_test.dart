import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase/in_app_purchase_platform_interface.dart';
import 'package:in_app_purchase/in_app_purchase_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockInAppPurchasePlatform 
    with MockPlatformInterfaceMixin
    implements InAppPurchasePlatform {

  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final InAppPurchasePlatform initialPlatform = InAppPurchasePlatform.instance;

  test('$MethodChannelInAppPurchase is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelInAppPurchase>());
  });

  test('getPlatformVersion', () async {
    InAppPurchase inAppPurchasePlugin = InAppPurchase();
    MockInAppPurchasePlatform fakePlatform = MockInAppPurchasePlatform();
    InAppPurchasePlatform.instance = fakePlatform;
  
    expect(await inAppPurchasePlugin.getPlatformVersion(), '42');
  });
}
