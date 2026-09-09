# NIARIM Product Audit Quality Standard

この文書は、NIARIMの全面監査・改善をWork / Codex / Hermes等のセッションをまたいで継続する際の恒久的な品質基準です。実行・Git・再開手順はルートの `AGENTS.md`、現在地点は `docs/work-audit/state/ASTRA_CONTINUATION.md` と `docs/work-audit/state/ASTRA_AUDIT_STATE.md` を正とします。

## 目標

NIARIMを世界中で利用される最高水準の商用製品へ仕上げることを最優先する。時間・利用枠・トークン節約のために品質を妥協しない。

既に優れた実装・仕様・UI・ブランド・互換性は維持する。一方、問題のある部分は既存コードの温存を優先せずroot causeまで追跡し、patchより再設計・大幅なrefactor・rewriteの方が最終品質、安全性、保守性、UXを高めるなら、影響範囲を理解して必要な範囲を大胆に作り直してよい。「既存を残す」「作り直す」のどちらも目的化せず、既存仕様・データ・ユーザー資産との互換性を検証しながら最終品質で判断する。製品全体の全面rewriteや意図的な互換性破壊など重大な変更だけは事前確認する。

## 監査範囲

App/Webを別々ではなく1つの製品として横断的に扱う。重大バグ、データ損失・破損、保存/復元/autosave/import/export/migration、security、認証/認可、race/concurrency/async、crash/hang、state/データ整合性、主要機能、未完成実装、TODO/FIXME/HACK/placeholder、error/offline/network処理、App/Web間のAPI・認証・データ・投稿・共有・公開状態等の整合性、accessibility、responsive、performance、保守性、dead/duplicate/obsolete code、testability、および商品品質を明確に向上できる部分まで対象にする。

問題は必要に応じて再現・影響範囲・root causeを確認し、修正→検証→実画面確認→regressionまで完結させる。

`docs/work-audit/state/ASTRA_AUDIT_STATE.md` で明確に監査済みかつ、その後の変更で前提が変わっていない領域は同等レベルのAstra Ultra/Hermes監査成果として引き継ぎ、理由なく再監査しない。未記録領域を推測で完了扱いせず、変更の影響を受けた監査済み領域だけ必要な範囲を再確認する。

## UI/UX・デザイン

UI/UX、product design、visual qualityは「動く」「崩れていない」「テストが通る」だけで合格にせず、十分なデザイン・開発リソースを持つ企業の世界水準の商用製品と比較しても見劣りしない完成度を目標にする。

可能な限り実画面を操作・確認し、情報設計、導線、操作性、視覚階層、layout、spacing、typography、color、contrast、iconography、density、feedback、loading/empty/error等の各状態、localization、accessibility、ブランド、App/Web一貫性まで評価・改善する。既に優れた部分は理由なく変更しない。

### 全画面・全操作の実機能／実画面監査

全面監査では、コードレビューやunit/widget/integration/E2E test、静的解析、CI、snapshot/screenshot diffだけでUI/UX・操作監査を完了扱いしない。App/Web双方について、通常利用で到達可能な**全画面、route、dialog、sheet、popover、menu、context menu、toolbar、sidebar、panel、tab、設定、onboarding、empty/loading/error/disabled/offline等の主要状態**を棚卸しし、実際に起動した製品または本番相当の実行環境で到達して実画面を確認する。

棚卸しした各画面では、その画面からユーザーが実行可能な操作を漏れなく洗い出し、適用可能な **tap/click、long press、keyboard入力、shortcut、focus/Tab移動、hover、scroll、drag/drop、resize、zoom/pan、context menu、選択/複数選択、toggle、slider、入力/編集/確定/取消、戻る/閉じる、undo/redo、save/load/import/export、共有/公開、権限要求、失敗時のretry/cancel** 等を実際に操作する。操作の存在をコードから確認しただけ、テストがイベントを発火しただけでは実操作確認の代替にしない。

各操作について、必要に応じて**操作前、操作中、成功後、取消後、失敗時、境界値、空データ、長大データ、無効状態、loading、error、offline、権限拒否、再起動/再訪後**まで観察し、表示だけでなくstate遷移、feedback、focus、keyboard、scroll位置、選択状態、保存/復元、undo/redo、二重実行、誤操作耐性、データ整合性を確認する。破壊的操作は専用テストデータ/隔離環境を使い、本番データやユーザー資産を危険にさらさない。

Astra Ultraは、機械的に全組み合わせを反復する必要がない部分はActions/Playwright/E2E等で網羅性を確保してよいが、**実画面の視覚品質と人間が操作したときの自然さをAstra自身が確認する工程を省略しない**。自動テストPASS、DOM/widget tree、ログ、数値、スクリーンショット差分だけを根拠に「目視確認済み」「操作確認済み」と記録してはならない。環境上どうしても実操作・実画面確認できない対象はPASSにせず、未確認理由と必要な確認環境をcheckpointへ残す。

全画面・全操作のinventoryには最低限、対象画面/状態、操作、PC/SP、確認方法、結果、未確認理由を追跡できる証跡を残す。全面監査完了には、このinventoryに未説明の未確認項目がなく、重大な操作フローについて修正後の再操作・regressionまで完了していることを要求する。

スマートフォンとPC/DeXを単なる同一UIのレスポンシブ変形として扱わない。SPはtouch、片手操作、software keyboard、tap target、小画面、限られたcanvas等に適した自然で効率的なモバイルUIへ最適化する。PC/DeXはスマホUIの引き伸ばしではなく、大画面、mouse、keyboardを活かし、必要に応じてtoolbar/sidebar/dock/panel/context menu/shortcut/workspace/広いcanvas/resize/multi-panel workflow等を備えるプロフェッショナルな制作環境として評価・改善する。Workspaceのsave/restore、preset、reset、panel state、default layout、破損/旧設定、device/viewport変更等も確認し、共通構造が最適化を妨げる場合は必要な範囲を再設計してよい。

### 多言語・ローカライゼーション品質

日本語を意味・意図・温度感の基準原文とし、対応7言語すべてについて単なる逐語訳ではなく、**同じ意味、同程度の丁寧さ・親しみやすさ・簡潔さ・ブランド温度**になることを確認する。翻訳後は必要に応じて日本語への再翻訳（back-translation）や意味分解を行い、機能条件、否定、警告、操作主体、数量、時間、保存/削除等の不可逆性、課金・権限等の重要ニュアンスが欠落・誇張・反転していないことを確認する。

原文にないスラング、ネット語、若者言葉、過度なくだけ表現、過剰な宣伝調、感情の追加、地域限定でしか通じない俗語を勝手に導入しない。逆に、日本語原文自体が意図的に軽いUIラベルや短縮表現を使う場合は、その役割を各言語で自然な標準UI表現へ置き換え、直訳で不自然な砕け方を再現しない。

各言語内で敬語・人称・命令形・ですます相当のregisterを統一する。英語のcontraction、スペイン語のtú/usted、フランス語のtu/vous、中国語の你/您、韓国語の해요/합니다系などが同一製品内で理由なく混在していないかを監査する。地域差が大きい語彙は、対象ロケールで一般的かつ専門アプリとして自然な表現を選ぶ。専門用語はアニメーション・イラスト制作分野の標準語彙を優先し、App/Web/ヘルプ/ストア文面で用語を統一する。

文字列だけでなく、句読点、全角/半角、複数形、性・数一致、冠詞、助数詞、日付・時刻・数値・小数点・単位・通貨、改行、プレースホルダー順序、文法上必要な語形変化、アクセラレータ/ショートカット表記まで確認する。翻訳によりUIが長くなる言語では、省略で意味を落とすのではなくlayout側を含めて解決する。

機械的なキー一致・placeholder検査はCIへ寄せるが、**自然さ、温度感、ブランド性、専門用語、意味保存、文化的違和感**はAstra Ultraが日本語原文と照合して評価する。翻訳済みだから完了とは扱わず、重大画面・オンボーディング・保存/削除・課金・共有/公開・エラー・ヘルプ・CTA・SEO/ASO文面は優先的に人間品質で監査する。

### 必須表示監査マトリクス

全面監査・主要UI変更・responsive/visual regression確認では、次の画面幅をすべて対象にする：

`320 / 360 / 375 / 390 / 430 / 480 / 520 / 559 / 560 / 600 / 640 / 641 / 700 / 759 / 760 / 834 / 900 / 1024 / 1180 / 1280 / 1366 / 1440 / 1600 / 1920px`

各画面幅について **PC / SP の両モード × 対応7言語の全組み合わせ** を確認する。24幅 × 2モード × 7言語 = **336組み合わせ** を必須マトリクスとし、特に559/560、640/641、759/760のような境界前後は省略しない。

この336組み合わせは、可能な限りGitHub Actions / Playwright / screenshot matrix等の決定論的な自動化で全件実行し、Astra Ultraの利用枠を単純反復処理で消費しない。ただし自動化のPASSだけで品質保証済みとはせず、overflow/clipping、折返し、余白、視覚階層、操作可能領域、テーマ/色漏れ、文言欠落、長文言語での崩れ、SP/PC固有UIの誤表示等を検出できるようテスト内容を設計する。異常・差分・境界条件・品質判断が必要な画面はAstra Ultra自身が実画面/スクリーンショットを確認する。

対象ページ・主要状態に対してマトリクスが未実行、queued/running、失敗、または検査項目が不十分な場合は「表示監査完了」と扱わない。主要UI変更後は影響範囲に応じて再実行する。

## Workflow・反復作業の圧縮

NIARIMを単なる機能の集合として評価せず、ユーザーが実際の制作で繰り返す一連の操作を製品側でどこまで安全かつ自然に圧縮できるかも監査する。主要な利用シナリオについて、同じ順序で繰り返される操作、既存UIでは不要な往復や余分な手数が生じる操作、入力・処理・出力が明確な定型フロー、複数機能を毎回同じ組み合わせで使うフローを洗い出し、Action / Workflow / preset / batch処理等へ昇格させる価値を評価する。

自動化は「できるから増やす」のではなく、反復頻度、手数削減、誤操作防止、学習コスト、発見可能性、編集可能性、undo/redo・cancel、安全性、処理時間、端末性能、保存/互換性、PC/SPそれぞれの操作特性を考慮し、明確にUXを改善する場合だけ採用する。例外や分岐が多く複雑化する作業、低頻度の作業、ユーザーの判断を隠してしまう自動化は無理にWorkflow化しない。

Workflow/presetを実装する場合は、再実行可能性、途中失敗時の一貫性、非破壊性、undo、進捗/feedback、cancel、設定編集、命名・管理、保存/復元、version/migration、import/export・共有の必要性、旧データ互換性まで製品品質として監査する。PCでは高度なAction/Workflow編集やbatch等を、SPでは小画面・touchに適した簡潔な再利用導線を検討し、同一UIを機械的に流用しない。

### AI機能は禁止

NIARIMのApp/Web製品にはAI機能を実装しない。生成AI、LLM、AIチャット、AIアシスタント、AIによる画像生成・編集・判定・提案、外部AI/Codex等をユーザー向け製品機能として組み込むことを、将来候補を含めて提案・設計・実装しない。Workflow / Action / preset / batch等は通常の決定論的な製品機能として設計する。この禁止はNIARIMを開発・監査するためにAstra等のAI開発ツールを利用することには適用しない。

## 国際展開・SEO・Discoverability・ASO・Conversion

NIARIMを日本国内向け製品の翻訳版としてではなく、各言語圏で自然に発見・理解・比較・導入されるグローバル製品として監査する。技術SEOやストアmetadataだけでなく、**検索流入 → Web理解 → ストア遷移 → ストア閲覧 → インストール/導入**までの獲得ファネル全体を品質対象に含める。

Webは各公開ページ・各言語について、検索意図、title/meta description、heading/semantic structure、canonical、hreflang、indexability、robots/sitemap、internal link、structured data、OG/social metadata、URL設計、重複/薄いcontent、画像alt/性能、Core Web Vitals等を確認する。単なるキーワード詰め込みは行わず、各市場で実際に使われる自然な検索語・競合/カテゴリ語・ユーザー課題を調査し、内容と一致する範囲で情報設計・コピーへ反映する。日本語キーワードの直訳をSEOとみなさない。

App Store / Google Play等では、実際に配布する各市場・言語について、アプリ名、subtitle/short description、keywords（提供される場合）、long description、カテゴリ、promotional text、アイコン、スクリーンショット、feature graphic、preview/video、localization、価格/課金/権限説明、レビュー/評価導線等を監査する。ストア規約・文字数・metadata仕様・禁止表現は公開時点の一次資料で再確認する。スクリーンショット等は単に綺麗な画像ではなく、最初の数枚で価値提案・差別化・主要workflowが理解でき、各言語で自然に読めることを確認する。

SEO/ASOコピーはローカライゼーション品質基準と同様、日本語原文の事実・ブランド温度を保持しつつ、各市場の検索意図に合わせてtranscreationしてよい。検索順位のために事実を誇張したり、競合商標を不自然に詰め込んだり、原文にない機能・優位性を追加しない。

獲得品質はランキングだけでなくconversionまで評価する。計測可能な場合は、地域/言語/端末/流入元別に検索impression→CTR→landing engagement→store click→store view→install等のfunnelを確認し、低下箇所を仮説→変更→検証で改善する。実データへアクセスできない場合は数値を推測・捏造せず、計測設計と検証可能な仮説を残す。privacy/consent要件を破って計測を増やさない。

## 法務・知的財産・プライバシー・利用規約

全面監査には `docs/product-audit/LEGAL_IP_STANDARD.md` を必須基準として適用する。ライセンス、著作権、商標、特許/実用新案、意匠等の知財だけでなく、対象国・地域のprivacy/data protection/consumer/contract law、Privacy Policy、Terms of Service、ストアprivacy disclosure/consent/delete-account等と実装の一致まで監査対象とする。法的保証ができない事項は未確認/残余リスク/専門家確認事項として残し、AIだけで全世界適法・非侵害と断定しない。

## 検証

修正後は変更に適したformat/static analysis/lint/unit/widget/integration/E2E/build/実画面確認を実行する。機械的検査は可能な限りCI/Actionsへ寄せるが、AIが判断すべき設計・UX・visual・翻訳・国際展開・法務リスクを機械的PASSで代替しない。

同一HEAD・同一入力・同一環境で既にPASSした重いsuiteを根拠なく再実行しない。ただしコード/依存/環境/入力/テスト自体が変わった場合、失敗原因の再確認、影響範囲のregression、全面監査のfull checkpoint、上記336表示マトリクス等で必要なら再実行する。

## 完了条件

重大・高優先度問題を未解決のまま「完了」としない。未監査領域、未実行の必要テスト、未確認の実画面/言語/viewport、queued/running CI、既知regression、法務上の未確認/専門家確認事項を明示する。完了とは、監査範囲を一巡し、必要な修正とregressionを終え、残余リスクと外部制約がcheckpointに記録されている状態を指す。