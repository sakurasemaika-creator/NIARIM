import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'api/community_api.dart';
import 'api/niarim_api_exception.dart';
import '../utils/tolerant_preferences.dart';

/// A requestId is persisted before any coin-consuming network request.
/// On timeout it MUST be replayed with identical selections and price version.
class IndividualCoinRedemptionAttemptStore {
  const IndividualCoinRedemptionAttemptStore();

  static String _key(String accountId) =>
      'pending_coin_individual_redemption_v1_$accountId';

  static String _newUuid() {
    final random=Random.secure();
    final bytes=List<int>.generate(16,(_)=>random.nextInt(256));
    bytes[6]=(bytes[6]&0x0f)|0x40;
    bytes[8]=(bytes[8]&0x3f)|0x80;
    String h(int n)=>bytes[n].toRadixString(16).padLeft(2,'0');
    return [
      [for(var i=0;i<4;i++)h(i)].join(),
      [for(var i=4;i<6;i++)h(i)].join(),
      [for(var i=6;i<8;i++)h(i)].join(),
      [for(var i=8;i<10;i++)h(i)].join(),
      [for(var i=10;i<16;i++)h(i)].join(),
    ].join('-');
  }

  Future<Map<String,dynamic>> redeem({
    required CommunityApi api,
    required String accountId,
    required List<String> targets,
    required String duration,
    required int quantity,
    required String serverPriceVersion,
  }) async {
    if(accountId.isEmpty||targets.isEmpty||targets.length>11||
       targets.toSet().length!=targets.length||
       serverPriceVersion.isEmpty||quantity<1||quantity>120) {
      throw ArgumentError('Invalid coin redemption request');
    }
    final prefs=await SharedPreferences.getInstance();
    final key=_key(accountId);
    final canonical=targets.join(',');
    var version=serverPriceVersion;
    String? requestId;
    final raw=prefs.readString(key);
    if(raw!=null) {
      try {
        final existing=jsonDecode(raw) as Map<String,dynamic>;
        if(existing['targets']!=canonical||
           existing['duration']!=duration||
           existing['quantity']!=quantity) {
          // A timed-out debit must be resolved before changing selections.
          throw StateError('Unresolved coin redemption request');
        }
        final savedId=existing['requestId'];
        final savedVersion=existing['priceVersion'];
        if(savedId is! String ||
           !RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$').hasMatch(savedId)||
           savedVersion is! String||savedVersion.isEmpty) {
          throw StateError('Corrupt unresolved redemption metadata');
        }
        requestId=savedId;
        version=savedVersion;
      } on FormatException {
        throw StateError('Unreadable unresolved coin redemption request');
      } on TypeError {
        throw StateError('Unreadable unresolved coin redemption request');
      }
    }
    requestId??=_newUuid();
    final saved=await prefs.setString(key,jsonEncode({
      'requestId':requestId,'priceVersion':version,'targets':canonical,
      'duration':duration,'quantity':quantity,
    }));
    if(!saved)throw StateError('Cannot persist redemption request');
    try {
      final result=await api.redeemSelectedBenefitCoins(
        targets:targets,duration:duration,quantity:quantity,
        requestId:requestId,priceVersion:version,
      );
      if(result['redeemed']!=true) {
        throw StateError('No server receipt for coin redemption');
      }
      await prefs.remove(key);
      return result;
    } on NiarimApiException catch(error) {
      // Only definitive errors are safe to clear. A network timeout or a
      // transient server failure may mean coins were already debited.
      if(const {
        'REDEMPTION_PRICE_CHANGED','REDEMPTION_REQUEST_ID_INVALID',
        'REDEMPTION_INVALID_TARGET','REDEMPTION_INVALID_SELECTION',
        'REDEMPTION_INVALID_DURATION','REDEMPTION_OVERLAPPING_BUNDLE',
        'REDEMPTION_OVERLAPPING_ADS',
      }.contains(error.code)) {
        await prefs.remove(key);
      }
      rethrow;
    }
  }
}
