import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/community/widgets/community_post_copy_button.dart';

void main() {
  test('copies titles in either direction without linking their values', () {
    final niarim = TextEditingController(text: 'NIARIM title');
    final youtube = TextEditingController(text: 'YouTube title');
    addTearDown(niarim.dispose);
    addTearDown(youtube.dispose);

    expect(copyCommunityFieldText(
      source: niarim, destination: youtube, maxLength: 100,
    ), isNull);
    expect(youtube.text, 'NIARIM title');
    niarim.text = 'Independent title';
    expect(youtube.text, 'NIARIM title');
    youtube.text = 'Updated YouTube title';
    expect(copyCommunityFieldText(
      source: youtube, destination: niarim, maxLength: 100,
    ), isNull);
    expect(niarim.text, 'Updated YouTube title');
  });

  test('does not truncate or overwrite an overlong NIARIM description', () {
    final source = TextEditingController(text: List.filled(2001, 'a').join());
    final target = TextEditingController(text: 'Keep existing');
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    expect(copyCommunityFieldText(
      source: source, destination: target, maxLength: 2000,
    ), CommunityFieldCopyError.tooLong);
    expect(target.text, 'Keep existing');
  });

  test('rejects 2000 Japanese characters when they exceed YouTube bytes', () {
    final source = TextEditingController(text: List.filled(2000, 'あ').join());
    final target = TextEditingController(text: 'Keep YouTube text');
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    expect(copyCommunityFieldText(
      source: source, destination: target,
      maxLength: 5000, youtubeDescription: true,
    ), CommunityFieldCopyError.invalidYoutubeDescription);
    expect(target.text, 'Keep YouTube text');
  });

  test('prevents copying disallowed YouTube description markup', () {
    final source = TextEditingController(text: 'Text <tag>');
    final target = TextEditingController(text: 'Original');
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    expect(copyCommunityFieldText(
      source: source, destination: target,
      maxLength: 5000, youtubeDescription: true,
    ), CommunityFieldCopyError.invalidYoutubeDescription);
    expect(target.text, 'Original');
  });

  testWidgets('tapping the button copies text and shows disabled state', (tester) async {
    final source = TextEditingController();
    final target = TextEditingController(text: 'Other');
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    final errors = <CommunityFieldCopyError>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityPostCopyButton(
          source: source, destination: target,
          label: 'Copy to YouTube', maxLength: 100,
          enabled: true, onError: (error, _) => errors.add(error),
        ),
      ),
    ));
    expect(tester.widget<TextButton>(find.byType(TextButton)).onPressed, isNull);
    source.text = 'Copied title';
    await tester.pump();
    await tester.tap(find.text('Copy to YouTube'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityPostCopyConfirmationDialog')), findsOneWidget);
    expect(find.text("The destination's current contents will be overwritten. Do you want to copy?"), findsOneWidget);
    expect(target.text, 'Other');

    await tester.tap(find.byKey(const Key('communityPostCopyCancelButton')));
    await tester.pumpAndSettle();
    expect(target.text, 'Other');

    await tester.tap(find.text('Copy to YouTube'));
    await tester.pumpAndSettle();
    expect(target.text, 'Other');
    await tester.tap(find.byKey(const Key('communityPostCopyConfirmButton')));
    await tester.pumpAndSettle();
    expect(target.text, 'Copied title');
    expect(errors, isEmpty);
  });

  testWidgets('confirmation is required even if the destination is empty', (tester) async {
    final source = TextEditingController(text: 'New description');
    final target = TextEditingController();
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityPostCopyButton(
          source: source, destination: target,
          label: 'Copy description', maxLength: 2000,
          enabled: true, onError: (_, __) {},
        ),
      ),
    ));
    await tester.tap(find.text('Copy description'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('communityPostCopyConfirmationDialog')), findsOneWidget);
    expect(target.text, isEmpty);
    await tester.tap(find.byKey(const Key('communityPostCopyCancelButton')));
    await tester.pumpAndSettle();
    expect(target.text, isEmpty);
  });

  testWidgets('does not overwrite if a field changed while confirming', (tester) async {
    final source = TextEditingController(text: 'Old source');
    final target = TextEditingController(text: 'Old destination');
    addTearDown(source.dispose);
    addTearDown(target.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: CommunityPostCopyButton(
          source: source, destination: target,
          label: 'Copy description', maxLength: 2000,
          enabled: true, onError: (_, __) {},
        ),
      ),
    ));
    await tester.tap(find.text('Copy description'));
    await tester.pumpAndSettle();
    target.text = 'Updated destination';
    await tester.tap(find.byKey(const Key('communityPostCopyConfirmButton')));
    await tester.pumpAndSettle();
    expect(target.text, 'Updated destination');
  });
}
