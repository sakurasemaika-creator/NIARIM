import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:niarim/l10n/app_localizations.dart';
import 'package:niarim/screens/rewards/creator_missions_screen.dart';
import 'package:niarim/services/api/community_api.dart';
import 'package:niarim/services/api/niarim_api_client.dart';
import 'package:niarim/services/community_service.dart';
import 'package:niarim/services/google_auth_service.dart';
import 'package:niarim/services/project_service.dart';
import 'package:niarim/widgets/mission_completion_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/load_app_fonts.dart';

class _ExampleAccount implements GoogleSignInAccount {
  @override
  String get id => 'Ncapture-verified';
  @override
  String get email => 'example.invalid';
  @override
  String get displayName => 'Captured signed-in user';
  @override
  String? get photoUrl => null;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
class _ExampleAuth extends GoogleAuthService {
  final _user = _ExampleAccount();
  @override
  GoogleSignInAccount? get account => _user;
  @override
  bool get isConfigured => true;
}
http.Response _json(Object data) => http.Response(
  jsonEncode(data), 200, headers: {'content-type': 'application/json'},
);
CommunityService _exampleMissionService() => CommunityService(
  api: CommunityApi(NiarimApiClient(
    baseUrl: 'https://example.invalid',
    maxGetRetries: 0,
    tokenProvider: () async => 'non-production-test-token',
    httpClient: MockClient((request) async {
      if (request.method == 'POST') {
        return _json({'visitedToday':true,'totalDays':2});
      }
      final path = request.url.path;
      if (path == '/me/missions') {
        return _json({
          'enabled':true, 'candidateEditSeconds':3600,
          'missions':[{
            'id':'followers_10','kind':'followers','required':10,
            'progress':7,'coins':3,'claimed':false,'eligible':false,
            'readyForClaim':false,'rewardEnabled':true,'perWork':false,
          }],
        });
      }
      if (path == '/me/missions/grid') {
        return _json({'missions':[],'rewardEnabled':true});
      }
      if (path == '/me/missions/work-achievements') {
        return _json({'items':[],'nextCursor':null});
      }
      if (path == '/me/login-bonus') {
        return _json({'totalDays':2,'visitedToday':true,'dailyCoins':1,
          'dailyClaimed':false,'rewardEnabled':true,'milestones':[]});
      }
      if (path == '/me/missions/recurring') {
        return _json({'enabled':true,'missions':[
          {'id':'visit_week_3','period':'week','requiredDays':3,
            'progressDays':2,'claimed':false,'coins':3,'eligible':false},
          {'id':'visit_week_5','period':'week','requiredDays':5,
            'progressDays':2,'claimed':false,'coins':6,'eligible':false},
          {'id':'visit_month_10','period':'month','requiredDays':10,
            'progressDays':4,'claimed':false,'coins':12,'eligible':false},
        ]});
      }
      if (path == '/me/missions/plaza') {
        const goals = [
          ('plaza_day_5m','day',300,2),
          ('plaza_day_15m','day',900,4),
          ('plaza_day_30m','day',1800,6),
          ('plaza_day_60m','day',3600,10),
          ('plaza_week_1h','week',3600,8),
          ('plaza_week_3h','week',10800,15),
          ('plaza_week_6h','week',21600,25),
          ('plaza_month_10h','month',36000,30),
          ('plaza_month_20h','month',72000,45),
          ('plaza_month_40h','month',144000,60),
        ];
        return _json({'enabled':true,'missions':[
          for(final (id,period,required,coins) in goals)
            {'id':id,'period':period,'requiredSeconds':required,
              'progressSeconds':period=='day'?600:2400,
              'coins':coins,'claimed':false,
              'eligible':period=='day'&&required<=600,'ready':required<=600},
        ]});
      }
      return _json(<String,Object>{});
    }),
  )),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture actual signed-in missions and completion dialog',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts(tester);
    final out = Directory('build/mission-redesign-captures')
      ..createSync(recursive:true);
    for (final width in [390,1024]) {
      final auth = _ExampleAuth();
      final community = _exampleMissionService();
      await community.contentFiltersReady;
      final projects = ProjectService();
      final root = GlobalKey();
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width.toDouble(),width==390?844:900);
      await tester.pumpWidget(RepaintBoundary(
        key:root,
        child: MultiProvider(
          providers:[
            ChangeNotifierProvider<GoogleAuthService>.value(value:auth),
            ChangeNotifierProvider<CommunityService>.value(value:community),
            ChangeNotifierProvider<ProjectService>.value(value:projects),
          ],
          child:const MaterialApp(
            locale:Locale('ja'),
            localizationsDelegates:AppLocalizations.localizationsDelegates,
            supportedLocales:AppLocalizations.supportedLocales,
            home:CreatorMissionsScreen(),
          ),
        ),
      ));
      await tester.runAsync(() => Future<void>.delayed(
        const Duration(milliseconds:160)));
      await tester.pump(const Duration(milliseconds:450));
      await tester.pump(const Duration(milliseconds:500));
      expect(find.byKey(const Key('missionClaimAllButton')),findsOneWidget);
      Future<void> capture(String name) async {
        final exception=tester.takeException();
        expect(exception,isNull,reason:'$width $name');
        final boundary=root.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        final bytes=await tester.runAsync(() async {
          final image=await boundary.toImage(pixelRatio:1);
          final data=await image.toByteData(format:ui.ImageByteFormat.png);
          image.dispose();
          return data!.buffer.asUint8List();
        });
        await tester.runAsync(() =>
            File('${out.path}/${width}dp-$name.png').writeAsBytes(bytes!));
      }
      await capture('01-actual-mission-list-claim-all');
      final plaza=find.byKey(const Key('plazaMissionsPanel'));
      await tester.scrollUntilVisible(plaza,180,
          scrollable:find.byType(Scrollable).first,maxScrolls:20);
      await tester.pump(const Duration(milliseconds:350));
      expect(plaza,findsOneWidget);
      await capture('02-real-plaza-missions');
      final shown=showMissionCompletionDialog(
        tester.element(plaza),
        titles:const ['デイリー：作品広場を5分開く','ウィークリー：週3日ログイン'],
      );
      await tester.pumpAndSettle();
      await capture('03-mission-completed-popup');
      await tester.tap(find.byKey(const Key('missionCompletedClose')));
      await tester.pumpAndSettle();
      await shown;
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      community.dispose();
      projects.dispose();
    }
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
