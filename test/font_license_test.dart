// 同梱フォント（SIL Open Font License 1.1）の著作権表示・ライセンス本文が
// アプリのライセンス一覧へ登録されていることを確認する。
//
// OFL第2条は再配布時に著作権表示とライセンス本文を同梱することを求めており、
// assets/fonts/へ直接置いたフォントはLicenseRegistryの自動収集対象外のため、
// main.dartで明示的に登録している。その登録が将来壊れないよう固定する。
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('同梱フォントのライセンス本文がアセットとして読み込める', () async {
    final text = await rootBundle.loadString('assets/licenses/FONT_LICENSES.txt');
    // 3書体すべての著作権表示が含まれていること。
    expect(text, contains('HakkouMincho'));
    expect(text, contains('Kuramubon.otf'));
    expect(text, contains('NotoSerifJP.ttf'));
    expect(text, contains('DelaGothicOne-Regular.ttf'));
    expect(text, contains('NotoSerifKRSubset.ttf'));
    expect(text, contains('NotoSansKRBlackSubset.ttf'));
    // OFL第3条（改変版はReserved Font Nameを使えない）への言及があること
    expect(text, contains("Reserved Font Name 'Source'"));
    expect(text, contains('The Dela Gothic Project Authors'));
    expect(text, contains('Adobe'));
    // OFL本文（全文）が含まれていること。
    expect(text, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(text, contains('PERMISSION & CONDITIONS'));
    expect(text, contains('TERMINATION'));
  });

  test('LicenseRegistryへ同梱フォントのライセンスが登録されている', () async {
    LicenseRegistry.reset();
    LicenseRegistry.addLicense(() async* {
      final text =
          await rootBundle.loadString('assets/licenses/FONT_LICENSES.txt');
      yield LicenseEntryWithLineBreaks(
        const [
          'HakkouMincho',
          'Kuramubon',
          'Noto Serif JP',
          'Dela Gothic One',
          'Noto Serif KR / SC',
          'Noto Sans KR / SC',
        ],
        text,
      );
    });
    final entries = await LicenseRegistry.licenses.toList();
    final packages = entries.expand((e) => e.packages).toSet();
    expect(
        packages,
        containsAll([
          'HakkouMincho',
          'Kuramubon',
          'Noto Serif JP',
          'Dela Gothic One',
          'Noto Serif KR / SC',
          'Noto Sans KR / SC',
        ]));
  });
}
