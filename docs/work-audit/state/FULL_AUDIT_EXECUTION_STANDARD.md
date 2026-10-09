# NIARIM 全面監査実行標準

状態: `active`
適用範囲: App / Web / Backend / Native連携 / production UI / source / assets / presets / save-export

## 1. 全面監査
全面監査はテスト実行だけではない。最新dev_branchを取得し、実装inventory→Baseline→Discovery→Delta→横断品質→最終Visual closureまで行う。全画面・全route・全UI surface・全visible control、全機能・全preset・全workflow・全分岐を対象に、実操作→判定→修正→再操作→regressionを行う。

## 2. 全通り
ユーザーが到達・操作できる固有の画面、control、状態、分岐、入力方式、離散preset/選択肢は全件実操作する。数値はdefault、min/max、boundary、代表中間、empty/large/invalid、相互作用を確認する。success/error/loading/offline、apply/cancel/back/close、double execution、rapid input、interruption、revisit、undo/redo、save/load/import/export、permission、Free/Premium等も該当する場合は確認する。

## 3. 実操作・実描画
unit/widget test、snapshot、DOM/source inspection、CIだけではPASSにしない。production UIで「到達→設定→実データ操作→結果確認→確定/取消→再操作→保存→再読込」を行う。描画系は実canvas・実絵・実レイヤー・実frame・実selection・実brush・実presetを使う。

## 4. 5軸判定
機能 / 挙動 / 見た目 / 継続性 / 製品品質を独立判定する。製品品質には手数、発見性、誤操作耐性、導線、IA、一貫性、accessibility、制作効率、体感速度、独自性を含める。

## 5. UI操作性・IA
button/touch targetのサイズ・位置・spacing、隣接操作、destructive actionの安全距離、one-handed/handedness、scroll/gesture競合、PC mouse/drag競合、文字拡大、小画面、boundary widthを確認する。機能が存在するだけでなく、parent-child、grouping、menu/panel/tab/dialog/settings/navigation/shortcutの階層、重複導線、頻用機能の埋没を再評価する。現構造維持を正解とせず、必要なら再設計する。

## 6. Theme
background/text/icon/button/border/selection/focus/disabled/panel/dialog/menu等は可能な限りtheme/appearance/design tokenを使う。light/dark/custom/accent等を変更して不可視化、低contrast、色だけに依存する意味伝達を確認する。ただしcolor circle、canvas背景、実画像・作画・素材色等の機能上独立した色は無理にtheme化しない。

## 7. Visual output
描画/演出filter、質感変更/質感偏光、blend、blur、light/shadow/glow、noise/film/CRT/VHS、brush、material、presetは処理成功だけでPASSにしない。強度、色、brightness/contrast/saturation、alpha、reflection、texture、grain、edge、detail、blur spread、depth、animationを実出力で評価し、banding、muddy color、blown highlight、crushed black、unwanted transparency、hard cutoff、clipping、edge loss、color shift、過剰blur/noiseを探す。

## 8. PC/SP・responsive・7言語
PC/SPを別設計として確認する。指定width matrix `320/360/375/390/430/480/520/559/560/600/640/641/700/759/760/834/900/1024/1180/1280/1366/1440/1600/1920px` とcontinuous resize、特に559/560、640/641、759/760を確認する。7言語は日本語の意味・意図・温度感を基準に自然さ、register、専門用語、overflow、ellipsis、CJK glyph、font fallbackを確認し、不要なslangや過剰marketing toneを加えない。

## 9. Preset / setting / save
最新HEADから全presetを再inventoryする。Brush Custom、縁取りペン、Hair Fold 5 modes、髪/前髪preset、filters、質感変更/質感偏光、blend、automation、theme/color、timeline、canvas、size/pressure等を含む。theme、language、textScale、reduced motion、workspace/panel、performance/quality、save schema/versionを意図的にmutationし、legacy/current/unknown-newer/invalid/truncated/corruptを隔離データで確認する。実装されている全export/output formatを実ファイルで確認する。

## 10. Performance
cold/warm startup、route transition、filter/brush apply、drawing、slider/drag、undo/redo、save/load、import/export、search/list、share/publish、heavy canvas/large asset/projectを測定し、可能ならp50/p95、jank/frame drop、UI freeze、memory spike、I/O待ちを記録する。必要ならprofileして改善する。

## 11. Accessibility / Security / Legal / Source
各Standardに従い、contrast、screen reader、keyboard/focus、text scaling、reduced motion、auth/authz、validation、API abuse、race/concurrency、resource lifecycle、PII/token/secret、OSS/license、copyright、trademark、patent/utility model、GUI design rights、privacy、consumer/contract等を確認する。法務はAIで保証せず、不確実事項を専門家確認候補として記録する。

## 法令・規制・申請/届出・許認可・ルール適合性ゲート

全面監査では、知財・privacyだけでなく、製品の実際の提供形態から適用され得る**法令、政省令、ガイドライン、届出・登録・許認可、契約上の義務、業界ルール、App Store/Google Play/外部API/広告ネットワーク等のプラットフォーム規約**を洗い出す。

特に日本法について、電気通信事業法を含むオンライン/通信サービス関連法令、個人情報保護法、消費者契約法、特定商取引法、景品表示法、資金決済・課金関連法令、知的財産法、不正競争防止法等を、NIARIMの機能・データフロー・料金・広告・通信・共有/公開・外部サービス利用状況に照らして適用可能性を判定する。該当する場合は届出、登録、許認可、表示、同意、契約、報告、保存等の義務を確認する。対象市場が日本以外に及ぶ場合は各法域を追加する。

各論点について、applicable / likely-applicable / likely-not-applicable / unresolved 等の状態、法域、根拠一次資料、確認日、必要対応、専門家確認要否をEvidenceに残す。**「法律名を調べた」だけでは完了とせず、実装・UI・規約・Privacy Policy・運用・申請準備まで整合しているかを確認する。**

必要な申請・届出・登録・許認可がある場合、製品側で準備可能な資料・設定・表示・技術対応は監査中に完了させ、外部機関への提出、本人確認、契約同意、手数料支払い、審査、行政/プラットフォームへの最終提出等だけをhuman-action-pendingとして残す。申請前提の実装不足をhuman-action-pendingに隠してはならない。


## 12. ブラッシュアップ
明確な改善余地があれば、root cause→fix→targeted test/analyze→同じ実操作→Visual再確認→関連regressionまで行う。refactor/rewrite/redesignを妨げない。機能削除は、目的、入力、出力、精度、UX、速度、自由度、保存互換性、undo/redo、share/export、Free/Premium差を確認して判断する。

## 13. Evidence / Visual closure
Audit ID、target、precondition、procedure、expected、actual、environment、PC/SP、viewport、language、theme、preset/mode、settings、test/visual result、regression、evidence location、未確認理由を追跡可能にする。Visual evidenceはBEFORE/SETTINGS/AFTER、feature、preset/mode、主要設定を識別可能にし、captureしただけでPASSにしない。最新HEADで最終Visual closureを再生成し、全ページrender＋実画像目視を行う。

## 外部サービス連携を「あと接続するだけ」にする基準

人間操作が必須となる外部サービス連携は、「外部サービスへまだログインしていない」ことと「アプリ/Web側が未完成」であることを明確に分離する。YouTube API、Google AdMob等を含む該当連携について、全面監査では次を実装・検証する。

- production code path、client/SDK/adapter、設定注入、環境変数/secret参照、認証・OAuth、scope、redirect/callback、API/SDK呼出し、成功/error/retry/timeout/rate/quota、権限拒否、offline/再接続、ログ・secret redaction、analytics/privacy/consent連携まで、必要なコード側を完成させる。
- 外部コンソールでしか作成できないID、secret、OAuth credential、ad unit、API有効化、redirect URI登録、審査/承認、契約同意等は、最後に人間が投入・実行する前提のhuman-action-pendingとして整理してよい。ただし、それを理由にコード上のTODO、placeholder、未接続経路、未検証error stateを残さない。
- 実credentialが監査環境に置けない場合は、test/sandbox/mock boundary等で本番経路と同一の設定・状態遷移を可能な範囲で実操作し、実credential投入後に追加実装が不要であることを確認する。
- YouTube APIは、必要なAPI有効化、認証/credential、scope、callback、対象endpoint、quota/error/retry、secret管理等をinventoryし、コード側を接続-readyにする。
- Google AdMobは、必要なSDK/adapter、app/ad-unit等の設定注入、test/production切替、広告表示、consent/privacy、レイアウト/表示崩れ、失敗時の安全なフォールバック等をinventoryし、コード側を接続-readyにする。
- 連携に必要なPrivacy Policy、Terms、consent、store disclosure、third-party notices等がある場合は、機能だけでなく法務/IP監査と同時に整合性を確認する。
- 人間作業として残した項目にはhuman-action-pendingを付け、**作業名 / サービス / App-Web / 実施場所 / 必要なID・secret・設定 / 前提 / 実施手順 / 完了確認 / evidence / 実施できない理由**を記録する。

全面監査の最終状態では、implementation-pending = 0 を必須とし、human-action-pendingは「外部サービス側でしか実行できない操作」に限定する。監査後の人間作業は最終報告に一括して提示し、ユーザーがそのまま実行できる粒度まで具体化する。

## 14. 完了gate
Baseline incomplete、Discovery incomplete、Delta incomplete、unregistered Discovery、advisor-pending、required evidence/regression incompleteを0にする。重大な機能・安定性・データ損失・security・legal/IP問題を残さない。見送る改善は理由と残余リスクをEvidenceに残す。


## 初心者向け導線・チュートリアル・隠れ操作の発見性監査

NIARIMでは、制作中のキャンバスを極力邪魔しないことと、初見ユーザーが操作方法を理解できることを両立させる。特にキャンバスモードのツール操作は、**「慣れれば使える」だけでは完了としない**。

### キャンバスモードのツール切替とサブ操作
- ツールアイコンのシングルタップで当該ツールへ切り替える操作を、制作中の反復操作として優先的に評価する。
- シングルタップと競合させないために長押し・上スワイプ等へ割り当てているカスタム画面、サブツール選択、追加操作について、初見ユーザーがその存在と操作方法を自然に発見できるか実操作で確認する。
- 「長押し」「上スワイプ」等の不可視・非標準的なジェスチャーを前提にする場合、視覚的な手掛かり、ヒント、初回ガイド、チュートリアル等によって発見可能性を確保する。単にヘルプを読まないと分からない状態は問題候補とする。
- 長押しやスワイプを維持すること自体を正解とせず、**シングルタップ、長押し、上スワイプ、二段階UI、展開ボタン、サブツールバー、オーバーレイ、コンテキストUI等を含めて、制作効率・キャンバス占有率・誤操作耐性・発見性を比較し、必要なら操作体系そのものを再設計する。**
- 改修する場合は、ワンタップ切替による制作効率を失わず、サブ操作との競合を避け、PC/SPそれぞれで自然に使える構成を目指す。
- 実際の初心者を想定し、説明なしの初見状態で「ツール切替」「サブツール選択」「カスタム画面への到達」ができるかを確認する。できない場合は、操作方法または案内方法の改善対象とする。

### チュートリアル・オンボーディング
- チュートリアルは「文章を読めば分かる」ことだけを基準にせず、**図、UIキャプチャ、操作位置の強調、矢印、番号、短い手順、実際の操作例**を活用して視覚的に理解できるか確認する。
- Help/Tipsだけでなく、初心者が機能を初めて使う場面のチュートリアル・オンボーディングにも同じ視覚説明品質を適用する。
- 複数ページのチュートリアルは、必要に応じて横スワイプ/カード形式など、現在の操作環境に自然な方法で順番に理解できるUIを検討する。
- 各ページが前ページの理解を前提とする場合、途中で閉じたことで重要な操作を知らないまま進まないよう、**全ページ閲覧を促す／必要な導入部分は完了まで閉じにくくする／未読状態を明示する**等の設計を検討する。ただし、ユーザーを不必要に拘束することや制作を妨げることも避け、重要度に応じて解除・スキップ・再表示方法を設計する。
- チュートリアルは7言語、PC/SP、画面幅、text scaling、theme、長い翻訳文でも図と説明が破綻しないことを確認する。
- 監査開始時と主要機能・UI改修後に、最新の機能inventoryとチュートリアル一覧を照合し、各機能について「既存チュートリアルで十分／更新／新規追加／不要（理由を記録）」を判断する。Helpに項目があるだけで、初回操作のチュートリアルも十分だと判断しない。
- 新機能・新しい応用workflow・操作方法の大幅な変更が発生した場合、実装と受け入れ確認の一部としてチュートリアル要否を必ず判定する。独自性が高い、初見で発見しにくい、複数手順が必要、誤操作しやすい等、学習支援が必要な機能はチュートリアルを追加・更新し、必要な案内を将来作業へ先送りして機能だけを完了扱いにしない。すべての簡単な操作に機械的に作る必要はないが、「不要」の根拠は残す。
- 最新のアプリ／本番相当環境で、チュートリアルを最初から最後まで実操作し、手順、用語、画面名、アイコン、設定、前提条件、制限、Free/Premium条件、期待結果が現行実装と一致すること、読者が自力で再現できることを確認する。UI変更で古くなった図・キャプチャ・文言は同じ変更作業内で更新する。
- 新規・更新したチュートリアルは、feature/task IDに紐づけて要否判断、対象機能、検証手順、実行結果、証拠を記録し、影響する7言語・PC/SP・対象viewport・文字拡大・themeで説明や図が破綻しないことを実画面で確認する。
- 図やキャプチャは実際の現行UIと一致している必要があり、古い画面・古いラベル・現在存在しない操作を案内しない。UI変更時は関連チュートリアルも更新し、実画面で再確認する。
- チュートリアルを読んだ後に実際の機能を一人で再現できるかを確認し、説明の分かりやすさだけでなく**学習→実操作への移行成功率、手戻り、迷い、誤操作**まで評価する。

### チュートリアル追加判定・最新性の完了条件
- 機能inventoryの全機能に対し、対応するチュートリアルと現行性を確認し、「既存で十分／更新／新規追加／不要（理由）」を記録する。
- 監査で新機能を追加した場合も、初見ユーザーにとって案内が必要かを必ず判定する。必要なチュートリアルの追加・更新まで行い、別作業へ先送りしない。
- 本番相当の最新実装で全手順を操作し、ラベル、配置、用語、gesture、前提条件、結果、制限、Free/Premium差、図・キャプチャの一致を確認する。未検証、旧UI、古い手順、説明どおりに再現できないものは未完了とする。
- 完了条件は、必要なチュートリアルの欠落・現行仕様との不一致・未検証がゼロであり、不要判定には根拠が記録されていること。

### 改善判断
- 現在の操作方法・UI・チュートリアル構造を維持することを前提にしない。
- 「キャンバスを広く保つ」「制作中のワンタップ切替を速くする」「サブ機能を発見しやすくする」「初心者が自力で習得できる」の目的を同時に満たす案を比較し、必要ならUI/gesture/情報設計/チュートリアルを大幅に再設計する。
- 改修後は、初見状態→チュートリアル→実操作→再訪の一連の流れを実際に確認し、既存ユーザーの連続操作効率、誤操作、キャンバス作業領域、performance、accessibility、保存/復元等へのregressionも確認する。

**原則：高度な操作を「知っている人だけが快適」な状態で完成とせず、初心者には発見しやすく、経験者には制作を邪魔せず速く使える操作体系を目指す。**

## 実装・実現方法による適合可能性を最大限検討する方針

全面監査では、法令・規制・届出・許認可・契約・プラットフォームルール・外部サービス制約・技術制約等に適合しにくい事項について、**その制約をそのまま受け入れて機能を諦める、または直ちにhuman-action-pending / blockerとするのではなく、実装方法・提供方法・データフロー・UI/UX・権限設計・機能構成・運用方法・外部サービスの使い方等を工夫することで、適法・適合・安全に実現できないかを可能な限り先に検討する。**

同じユーザー価値・目的を保ったまま、より適合しやすい方式へ変更できる場合は、実装を再設計して解決することを優先する。例えば、収集データを減らす、処理を端末側へ寄せる、公開範囲を限定する、権限を分離する、同意取得を適切なタイミングへ移す、外部サービスへの送信を必要最小限にする、機能を別方式へ置き換える、設定や表示を変更する、第三者素材を適切な権利状態の素材へ置換する等、**技術・設計による実現方法を具体的に比較する。**

これは適用される法令・規約・契約等の趣旨を損なう方法を探すことを意味しない。**ルールを満たすことを前提に、目的・ユーザー価値をできるだけ維持する実装・設計上の代替案を探す**という意味で適用する。法的適用性が不確実な場合は、推測で実装を確定せず、一次資料と専門家確認の要否を記録する。

実装・実現方法を変更した場合は、元の目的・機能価値が維持されていることを実操作で確認し、security / privacy / accessibility / performance / save-restore / interoperability / UX / visual quality等への副作用をregressionする。**「できない理由」を見つけるだけで終わらず、「どうすれば正しく実現できるか」まで検討することを監査上の標準とする。**

## 既存作画アプリとの差別化・アイコン中心の情報設計

CLIP STUDIO PAINT、ibisPaint、MediBang Paint、PaintTool SAI等は一般原則の研究対象としてよいが、特定製品に固有性の高いtoolbar/panel構成、アイコン、色、ダイアログ、メニュー階層、操作順序、gesture等の組み合わせをそのまま模倣しない。酷似が見つかった場合は、単なる色替えに留めず、必要な範囲でNIARIM固有のレイアウト・視覚言語・情報階層・操作体系へ再設計する。一般的なUI慣習まで無理に変えて使いやすさを損なわない。知的財産上の問題が疑われる場合はLEGAL_IP_STANDARDも確認する。

画面上の文字は「常に付ける／常に消す」の二択にせず、**初見ユーザーがアイコン/UIだけで意味を正しく推測できる操作はicon-onlyを優先し、曖昧・専門的・破壊的・重要な操作は具体的な文字説明を併用する**。icon-onlyでもaccessibility用のaccessible nameやtooltip等の補助情報は確保し、7言語・PC/SP・responsiveで理解性と誤操作防止を実画面確認する。

## ダイアログ文言とボタン配置

確認・警告・削除・破棄・上書き・復元・公開・ログアウト等は、質問文とボタンだけで結果が明確になり、誤操作を防げることを確認する。削除確認の標準例は「削除しますか？ [削除する] [キャンセル]」。肯定側は具体的な動詞を使ってよいが、否定側を「削除しない」等の否定形アクション名にはせず、原則「キャンセル」「戻る」「閉じる」等を使う。OK / キャンセル等を使う場合は製品内の左右位置を固定し、画面・ダイアログ種類・PC/SP・言語で左右を逆転させない。7言語で意味が明確か、長文で配置が崩れないか、実際の結果と一致するかを実操作で確認する。


## 15. 既存作画アプリとの独自性・Help/Tips

- CLIP STUDIO PAINT、ibisPaint、MediBang Paint等を参考にする際は、特定製品の固有表現の模倣を避ける。toolbar/panel/配色/形状/アイコン/用語/操作順序/gesture等の組み合わせで酷似を調べ、比較証拠と判断理由を残す。固有性の高い類似は色替えだけでなく、NIARIM固有の設計へ再構成し、実画面で確認する。一般的な慣習まで無理に変えず、法的な非侵害保証はしない。
- 文字ラベルは全ボタンに一律で付けない。初見でもアイコン/UIから一義的に理解できる操作はicon-onlyを優先し、曖昧・専門的・文脈依存・危険・不可逆・課金/公開/権限操作には具体的説明を残す。accessible name/tooltip/状態表示を備え、PC/SP・7言語・文字拡大・実操作で確認する。
- Helpは辞書として必要項目を幅広く網羅する。機能/画面/設定/用語/操作/制限/エラー/復旧/save-restore/import-export等をinventoryと照合し、検索/カテゴリ/関連リンクを確認する。
- TipsはNIARIM固有機能を活かす実用的な利用例・応用・組み合わせ・workflowを重視し、Helpの繰り返しだけの内容にしない。全項目を維持/修正/追加/統合/削除に判定し、根拠を残す。有用なHelpを閲覧数だけで削除しない。
- 両方の用語・説明・必要条件・手順・結果・制限・Free/Premium条件・図/キャプチャ・リンク・7言語を現行アプリと照合し、変更後に実操作で再現できることを確認する。古いUIや未実装機能の説明を残さず、未確認はPASSにしない。


## 16. Webの機能紹介網羅性・NIARIM独自価値の伝達

Web監査は「サイトの表示が現行アプリと一致するか」だけでは不十分。**製品として紹介すべき機能が適切に選ばれているか、その価値と使いどころが伝わるか、NIARIMならではの体験が明確にアピールされているか**を独立した品質ゲートとして確認する。

### 機能inventoryと掲載先の対応
- 最新Appの全機能inventoryを、WebのHome / Features / Premium / Help / FAQ / News / Community等のページ・セクションと対応付ける。
- 機能ごとに「掲載済みで十分／掲載済みだが価値説明不足／未掲載／掲載不要（理由）」を判定する。未掲載・掲載不要は理由と判断根拠を記録する。
- 「ボタンや機能が存在する」といった仕様列挙だけでなく、ユーザーが解決できる課題、得られる成果、適した制作場面、操作の簡単さ、他機能との連携を伝えているか評価する。
- 全機能を同じ面積で掲載する必要はない。重要度・独自性・ユーザー価値・発見しにくさを考慮して優先順位を付ける。ただし重要機能が紹介から漏れていないことを確認する。

### NIARIMらしさ・差別化の訴求
- 最新実装を実際に操作し、NIARIM固有の操作体験、制作workflowの短縮、迷い・失敗の減少、プレビュー、編集・復元、他機能との連携等の強みを抽出する。ソース上の存在だけで価値を推測せず、実際の操作と結果で確かめる。
- 例：ブレンドモード選択画面で適用前に結果を手軽にプレビューできる場合、「多くのブレンドモードに対応」という機能列挙に留めず、「適用を確定する前に結果を見比べて選べるため、試行錯誤や取り消しの手間を減らせる」という体験価値を訴求候補として評価する。最新UIと実操作で、プレビューの挙動・対象範囲・条件を検証してから紹介する。
- 「NIARIM独自」「他製品にはない」など競合に対する排他的な主張は、競合製品の現行一次資料と比較証拠がある場合に限る。証拠がない場合は、NIARIMで実際に確認できる体験・利点として説明し、未確認の優位性を断定しない。
- 強みの紹介には、可能な限り現行アプリから取得したキャプチャ、状態の前後比較、短い操作図解を用いる。画像は画面を飾るだけでなく、説明している機能と価値を具体的に証明すること。

### 実行手順と完了ゲート
1. 最新App/Webの開始SHAを固定し、App機能inventoryを作成・更新する。
2. 各機能について現行UIで操作し、ユーザー価値・利用場面・結果・制限・必要条件を記録する。
3. Web掲載箇所とキャプチャを対応付け、未紹介・説明不足・古い素材・用語の不一致を抽出する。
4. 重要な未掲載機能、伝わりにくい強み、重複や情報設計上の埋没を修正する。ページ構成や見せ方の変更も必要に応じて検討する。
5. 修正後は実際のWeb表示をPC/SP・指定幅・7言語で確認し、最新アプリとの齟齬、画像の可読性、訴求の明確さ、CTA/遷移先を再検証する。
6. 対応表「App機能ID → Web掲載箇所 → ユーザー価値 → 現行UI/キャプチャ証拠 → 検証結果」を保存する。

以下はそれぞれ独立した判定項目であり、片方のPASSで他を代替しない。
- **現行性:** 説明・機能名・キャプチャが最新実装と一致する。
- **網羅性:** 紹介すべき重要機能が掲載され、未掲載項目には理由がある。
- **理解性:** 初見ユーザーが機能・操作・使いどころ・得られる結果を理解できる。
- **独自価値の伝達:** NIARIMならではの体験と具体的な利点が、根拠を伴って目立つ位置・形式で伝わる。
- **主張の裏付け:** 排他的な競合優位性を含む主張は証拠に基づき、未確認の比較を断定していない。

上記の対応表がなく、重要機能の掲載漏れが未確認、独自価値の訴求が未評価、または説明とキャプチャの整合性が未検証の場合は、Web全面監査を完了扱いにしない。
