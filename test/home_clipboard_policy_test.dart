import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/screens/home/home_clipboard_policy.dart';

void main() {
  test('files are restricted by the tab and pill that owns their format', () {
    for (final source in HomePasteArea.values.where(
      (kind) => kind != HomePasteArea.trash,
    )) {
      for (final destination in HomePasteArea.values.where(
        (kind) => kind != HomePasteArea.trash,
      )) {
        expect(HomePastePolicy.check(
          source: source, destination: destination,
          containsFiles: true, containsFolders: false,
        ), source == destination
            ? HomePasteDecision.allowed
            : HomePasteDecision.incompatibleFormat,
          reason: '$source -> $destination');
      }
    }
  });

  test('empty folders may cross collection boundaries', () {
    for (final source in HomePasteArea.values.where(
      (kind) => kind != HomePasteArea.trash,
    )) {
      for (final destination in HomePasteArea.values.where(
        (kind) => kind != HomePasteArea.trash,
      )) {
        expect(HomePastePolicy.check(
          source: source, destination: destination,
          containsFiles: false, containsFolders: true,
        ), HomePasteDecision.allowed);
      }
    }
  });

  test('all non-trash collections may explicitly paste into Trash', () {
    for (final source in HomePasteArea.values.where(
      (kind) => kind != HomePasteArea.trash,
    )) {
      expect(HomePastePolicy.check(
        source: source, destination: HomePasteArea.trash,
        containsFiles: true, containsFolders: true,
      ), HomePasteDecision.allowed);
    }
  });

  test('trash does not perform an unconfirmed automatic restore', () {
    expect(HomePastePolicy.check(
      source: HomePasteArea.trash, destination: HomePasteArea.projects,
      containsFiles: true, containsFolders: false,
    ), HomePasteDecision.unsupportedTrashRestore);
  });
}
