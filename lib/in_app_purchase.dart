import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/services.dart';
import 'package:in_app_purchase/utils.dart';
import 'modules.dart';

class InAppPurchase {
  static const MethodChannel _channel = MethodChannel('flutter_inapp');

  static StreamController<PurchasedItem?>? _purchaseController;

  static Stream<PurchasedItem?> get purchaseUpdated =>
      _purchaseController!.stream;

  static StreamController<PurchaseResult?>? _purchaseErrorController;

  static Stream<PurchaseResult?> get purchaseError =>
      _purchaseErrorController!.stream;

  static StreamController<ConnectionResult>? _connectionController;

  static Stream<ConnectionResult> get connectionUpdated =>
      _connectionController!.stream;

  static StreamController<String?>? _purchasePromotedController;

  static Stream<String?> get purchasePromoted =>
      _purchasePromotedController!.stream;

  static StreamController<int?>? _onInAppMessageController;
  static Stream<int?> get inAppMessageAndroid =>
      _onInAppMessageController!.stream;


  ///
  /// Particularly useful for removing all consumable items.
  Future consumeAll() async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod('consumeAllItems');
    } else if (Platform.isIOS) {
      return 'no-ops in ios';
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }

  /// Initializes iap features for both `Android` and `iOS`.
  ///
  /// This must be called on `Android` and `iOS` before purchasing.
  /// On `iOS`, it also checks if the client can make payments.
  Future<String?> initialize() async {
    if (Platform.isAndroid) {
      await _setPurchaseListener();
      return await _channel.invokeMethod('initConnection');
    } else if (Platform.isIOS) {
      await _setPurchaseListener();
      return await _channel.invokeMethod('canMakePayments');
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }

  Future _setPurchaseListener() async {
    _purchaseController ??= StreamController.broadcast();
    _purchaseErrorController ??= StreamController.broadcast();
    _connectionController ??= StreamController.broadcast();
    _purchasePromotedController ??= StreamController.broadcast();

    _channel.setMethodCallHandler((MethodCall call) {
      switch (call.method) {
        case "purchase-updated":
          Map<String, dynamic> result = jsonDecode(call.arguments);
          _purchaseController!.add(PurchasedItem.fromJSON(result));
          break;
        case "purchase-error":
          Map<String, dynamic> result = jsonDecode(call.arguments);
          _purchaseErrorController!.add(PurchaseResult.fromJSON(result));
          break;
        case "connection-updated":
          Map<String, dynamic> result = jsonDecode(call.arguments);
          _connectionController!.add(ConnectionResult.fromJSON(result));
          break;
        case "iap-promoted-product":
          String? productId = call.arguments;
          _purchasePromotedController!.add(productId);
          break;
        case "on-in-app-message":
          final int code = call.arguments;
          _onInAppMessageController?.add(code);
          break;
        default:
          throw ArgumentError('Unknown method ${call.method}');
      }
      return Future.value(null);
    });
  }
  Future _removePurchaseListener() async {
    _purchaseController
      ?..add(null)
      ..close();
    _purchaseController = null;

    _purchaseErrorController
      ?..add(null)
      ..close();
    _purchaseErrorController = null;
  }
  /// Finish a transaction on both `android` and `iOS`.
  ///
  /// Call this after finalizing server-side validation of the reciept.
  Future<String?> finishTransaction(PurchasedItem purchasedItem,
      {bool isConsumable = false}) async {
    if (Platform.isAndroid) {
      if (isConsumable) {
        return await _channel.invokeMethod('consumeProduct', <String, dynamic>{
          'token': purchasedItem.purchaseToken,
        });
      } else {
        if (purchasedItem.isAcknowledgedAndroid == true) {
          return Future.value(null);
        } else {
          return await _channel
              .invokeMethod('acknowledgePurchase', <String, dynamic>{
            'token': purchasedItem.purchaseToken,
          });
        }
      }
    } else if (Platform.isIOS) {
      return await _channel.invokeMethod('finishTransaction', <String, dynamic>{
        'transactionIdentifier': purchasedItem.transactionId,
      });
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }

  Future<String?> consumePurchaseAndroid(String token) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod('consumeProduct', <String, dynamic>{
        'token': token,
      });
    } else if (Platform.isIOS) {
      return 'no-ops in ios';
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }
  /// Retrieves a list of products from the store on `Android` and `iOS`.
  ///
  /// `iOS` also returns subscriptions.
  Future<List<IAPItem>> getProducts(List<String> skus) async {
    if (Platform.isAndroid) {
      dynamic result = await _channel.invokeMethod(
        'getProducts',
        <String, dynamic>{
          'skus': skus.toList(),
        },
      );
      return extractItems(result);
    } else if (Platform.isIOS) {
      dynamic result = await _channel.invokeMethod(
        'getItems',
        <String, dynamic>{
          'skus': skus.toList(),
        },
      );
      return extractItems(json.encode(result));
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }

  /// Get all non-consumed purchases made on `Android` and `iOS`.
  ///
  /// This is identical to [getPurchaseHistory] on `iOS`
  Future<List<PurchasedItem>?> getAvailablePurchases() async {
    if (Platform.isAndroid) {
      dynamic result1 = await _channel.invokeMethod(
        'getAvailableItemsByType',
        <String, dynamic>{
          'type': describeEnum(_TypeInApp.inapp),
        },
      );

      dynamic result2 = await _channel.invokeMethod(
        'getAvailableItemsByType',
        <String, dynamic>{
          'type': describeEnum(_TypeInApp.subs),
        },
      );
      return extractPurchased(result1)! + extractPurchased(result2)!;
    } else if (Platform.isIOS) {
      dynamic result = await _channel.invokeMethod('getAvailableItems');

      return extractPurchased(json.encode(result));
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }
  /// Retrieves the user's purchase history on `Android` and `iOS` regardless of consumption status.
  ///
  /// Purchase history includes all types of products.
  /// Identical to [getAvailablePurchases] on `iOS`.
  Future<List<PurchasedItem>?> getPurchaseHistory() async {
    if (Platform.isAndroid) {
      final dynamic getInappPurchaseHistory = await _channel.invokeMethod(
        'getPurchaseHistoryByType',
        <String, dynamic>{
          'type': describeEnum(_TypeInApp.inapp),
        },
      );

      final dynamic getSubsPurchaseHistory = await _channel.invokeMethod(
        'getPurchaseHistoryByType',
        <String, dynamic>{
          'type': describeEnum(_TypeInApp.subs),
        },
      );

      return extractPurchased(getInappPurchaseHistory)! +
          extractPurchased(getSubsPurchaseHistory)!;
    } else if (Platform.isIOS) {
      dynamic result = await _channel.invokeMethod('getAvailableItems');

      return extractPurchased(json.encode(result));
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }
  Future<bool> isReady() async {
    if (Platform.isAndroid) {
      return (await _channel.invokeMethod<bool?>('isReady')) ?? false;
    }
    if (Platform.isIOS) {
      return Future.value(true);
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }

  /// Acknowledge a purchase on `Android`.
  ///
  /// No effect on `iOS`, whose iap purchases are consumed at the time of purchase.
  Future<String?> acknowledgePurchaseAndroid(String token) async {
    if (Platform.isAndroid) {
      return await _channel
          .invokeMethod('acknowledgePurchase', <String, dynamic>{
        'token': token,
      });
    } else if (Platform.isIOS) {
      return 'no-ops in ios';
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }
  Future requestPurchase(
      String sku, {
        String? obfuscatedAccountId,
        String? purchaseTokenAndroid,
        String? obfuscatedProfileIdAndroid,
      }) async {
    if (Platform.isAndroid) {
      return await _channel.invokeMethod('buyItemByType', <String, dynamic>{
        'type': describeEnum(_TypeInApp.inapp),
        'sku': sku,
        'prorationMode': -1,
        'obfuscatedAccountId': obfuscatedAccountId,
        'obfuscatedProfileId': obfuscatedProfileIdAndroid,
        'purchaseToken': purchaseTokenAndroid,
      });
    } else if (Platform.isIOS) {
      return await _channel.invokeMethod('buyProduct', <String, dynamic>{
        'sku': sku,
        'forUser': obfuscatedAccountId,
      });
    }
    throw PlatformException(
        code: Platform.operatingSystem, message: "platform not supported");
  }
  String describeEnum(Object enumEntry) {
    if (enumEntry is Enum)
      return enumEntry.name;
    final String description = enumEntry.toString();
    final int indexOfDot = description.indexOf('.');
    assert(
    indexOfDot != -1 && indexOfDot < description.length - 1,
    'The provided object "$enumEntry" is not an enum.',
    );
    return description.substring(indexOfDot + 1);
  }
}
enum _TypeInApp { inapp, subs }

