import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/utils/transfer_merge.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 引き継ぎ（.niatra）で、受け取った項目と、その中身を別のIDで持っていた
/// この端末の項目のつながり（[TransferCopyRecord.link]）：指す側（作品・
/// 早替えツールなど）から見て同じ項目になるが、この端末の項目は引き継ぎで
/// 足した複製には数えない（この端末で名前・太さを変えた後の読み直しは、
/// これまでどおりもう1台の項目を足す）。
void main() {
  test('an item of this device linked to the item it was found to be counts '
      'as the same item, but not as a copy that a transfer added', () {
    final record = TransferCopyRecord.none()..link('theirs', 'held');
    expect(record.origin('theirs'), record.origin('held'));
    expect(record.copiesOf('theirs'), isEmpty, reason: 'この端末の項目は、足した複製ではない');
    expect(
      record.copiesOf('held'),
      isEmpty,
      reason: '受け取った項目も、この端末の項目の版を足した複製ではない',
    );
  });

  test('a saved record keeps the copies a transfer added and the items that '
      'were only linked apart when it is read again', () async {
    SharedPreferences.setMockInitialValues({});
    final record = await TransferCopyRecord.read(TransferCopyRecord.brushes);
    record
      ..add('a', 'a_copy')
      ..add('same', 'same')
      ..link('theirs', 'a')
      ..link('other', 'held');
    await record.save();

    final read = await TransferCopyRecord.read(TransferCopyRecord.brushes);
    expect(read.copiesOf('a'), ['a_copy']);
    expect(read.copiesOf('same'), ['same']);
    expect(read.copiesOf('held'), isEmpty);
    expect(read.copiesOf('theirs'), isEmpty);
    expect(read.copiesOf('other'), isEmpty);
    expect(
      {
        for (final id in ['a', 'a_copy', 'theirs']) read.origin(id),
      },
      hasLength(1),
      reason: '足した複製も、つなげた項目も、同じ項目',
    );
    expect(read.origin('other'), read.origin('held'));
    expect(read.origin('same'), 'same');
    expect(read.origin('a'), isNot(read.origin('held')));

    // 読んだだけ・既にあるつながりを書くだけでは保存し直さない。
    final prefs = await SharedPreferences.getInstance();
    final key = '${TransferCopyRecord.keyPrefix}${TransferCopyRecord.brushes}';
    final saved = prefs.getString(key);
    await prefs.setString(key, '$saved ');
    read
      ..add('a', 'a_copy')
      ..link('theirs', 'a')
      ..link('a_copy', 'theirs');
    await read.save();
    expect(prefs.getString(key), '$saved ', reason: '変えていない記録は保存しない');

    // つながりを1つ書いただけの記録も保存する。
    final linked = await TransferCopyRecord.read(TransferCopyRecord.tones);
    linked.link('theirs', 'held');
    await linked.save();
    final linkedRead = await TransferCopyRecord.read(TransferCopyRecord.tones);
    expect(linkedRead.origin('theirs'), linkedRead.origin('held'));
    expect(linkedRead.copiesOf('held'), isEmpty);
  });

  test('a copy that arrives as an item of the other device no longer counts '
      'as the copy added for an item, but stays the same item; its own '
      'record and other copies are kept, and the change is saved', () async {
    SharedPreferences.setMockInitialValues({});
    final record = await TransferCopyRecord.read(TransferCopyRecord.stamps);
    record
      ..add('a', 'a_copy')
      ..add('a', 'returned')
      ..add('b', 'returned')
      ..add('returned', 'returned')
      ..add('returned', 'copy_of_returned');
    await record.save();
    final saved = await TransferCopyRecord.read(TransferCopyRecord.stamps);
    saved.arrivedAsItem('returned');
    // 複製として書き留めていないIDでは何も変えない。
    saved.arrivedAsItem('a');
    saved.arrivedAsItem('unknown');
    await saved.save();

    for (final (stage, r) in [
      ('changed', saved),
      ('read again', await TransferCopyRecord.read(TransferCopyRecord.stamps)),
    ]) {
      expect(r.copiesOf('a'), ['a_copy'], reason: stage);
      expect(r.copiesOf('b'), isEmpty, reason: stage);
      expect(r.copiesOf('returned'), [
        'returned',
        'copy_of_returned',
      ], reason: '$stage: 自分自身の版と、その版を足した複製はそのまま');
      expect(
        {
          for (final id in ['a', 'a_copy', 'b', 'returned', 'copy_of_returned'])
            r.origin(id),
        },
        hasLength(1),
        reason: '$stage: つながりは残る',
      );
    }

    // 変えなければ保存し直さない。
    final prefs = await SharedPreferences.getInstance();
    final key = '${TransferCopyRecord.keyPrefix}${TransferCopyRecord.stamps}';
    final value = prefs.getString(key);
    await prefs.setString(key, '$value ');
    final unchanged = await TransferCopyRecord.read(TransferCopyRecord.stamps);
    unchanged
      ..arrivedAsItem('returned')
      ..arrivedAsItem('a_copy_2');
    await unchanged.save();
    expect(prefs.getString(key), '$value ');
  });

  test('linking two IDs that are already the same item writes nothing', () {
    final record = TransferCopyRecord.none()
      ..add('a', 'a_copy')
      ..add('a_copy', 'a_copy_copy')
      ..link('theirs', 'held');
    record
      // 前に足した複製とその元。
      ..link('a', 'a_copy')
      ..link('a', 'a_copy_copy')
      // 逆向き。
      ..link('held', 'theirs')
      // 同じID。
      ..link('alone', 'alone');
    expect(record.copiesOf('a'), ['a_copy']);
    expect(record.copiesOf('a_copy'), ['a_copy_copy']);
    expect(record.copiesOf('a_copy_copy'), isEmpty);
    expect(record.copiesOf('theirs'), isEmpty);
    expect(record.copiesOf('alone'), isEmpty);
    expect(record.origin('alone'), 'alone');
  });
}
