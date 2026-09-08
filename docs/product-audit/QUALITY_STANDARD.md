# NIARIM Product Audit Quality Standard

この文書は、NIARIMの全面監査・改善をWork / Codex / Hermes等のセッションをまたいで継続する際の恒久的な品質基準です。実行・Git・再開手順はルートの `AGENTS.md`、現在地点は `docs/product-audit/README.md` と `docs/work-continuation.md` を正とします。

## 目標

NIARIMを世界中で利用される最高水準の商用製品へ仕上げることを最優先する。時間・利用枠・トークン節約のために品質を妥協しない。

既に優れた実装・仕様・UI・ブランド・互換性は維持する。一方、問題のある部分は既存コードの温存を優先せずroot causeまで追跡し、patchより再設計・大幅なrefactor・rewriteの方が最終品質、安全性、保守性、UXを高めるなら、影響範囲を理解して必要な範囲を大胆に作り直してよい。「既存を残す」「作り直す」のどちらも目的化せず、既存仕様・データ・ユーザー資産との互換性を検証しながら最終品質で判断する。製品全体の全面rewriteや意図的な互換性破壊など重大な変更だけは事前確認する。

## 監査範囲

App/Webを別々ではなく1つの製品として横断的に扱う。重大バグ、データ損失・破損、保存/復元/autosave/import/export/migration、security、認証/認可、race/concurrency/async、crash/hang、state/データ整合性、主要機能、未完成実装、TODO/FIXME/HACK/placeholder、error/offline/network処理、App/Web間のAPI・認証・データ・投稿・共有・公開状態等の整合性、accessibility、responsive、performance、保守性、dead/duplicate/obsolete code、testability、および商品品質を明確に向上できる部分まで対象にする。

問題は必要に応じて再現・影響範囲・root causeを確認し、修正→検証→実画面確認→regressionまで完結させる。

`docs/product-audit/README.md` で明確に監査済みかつ、その後の変更で前提が変わっていない領域は同等レベルのAstra Ultra/Hermes監査成果として引き継ぎ、理由なく再監査しない。未記録領域を推測で完了扱いせず、変更の影響を受けた監査済み領域だけ必要な範囲を再確認する。

## UI/UX・デザイン

UI/UX、product design、visual qualityは「動く」「崩れていない」「テストが通る」だけで合格にせず、十分なデザイン・開発リソースを持つ企業の世界水準の商用製品と比較しても見劣りしない完成度を目標にする。

可能な限り実画面を操作・確認し、情報設計、導線、操作性、視覚階層、layout、spacing、typography、color、contrast、iconography、density、feedback、loading/empty/error等の各状態、localization、accessibility、ブランド、App/Web一貫性まで評価・改善する。既に優れた部分は理由なく変更しない。

スマートフォンとPC/DeXを単なる同一UIのレスポンシブ変形として扱わない。SPはtouch、片手操作、software keyboard、tap target、小画面、限られたcanvas等に適した自然で効率的なモバイルUIへ最適化する。PC/DeXはスマホUIの引き伸ばしではなく、大画面、mouse、keyboardを活かし、必要に応じてtoolbar/sidebar/dock/panel/context menu/shortcut/workspace/広いcanvas/resize/multi-panel workflow等を備えるプロフェッショナルな制作環境として評価・改善する。Workspaceのsave/restore、preset、reset、panel state、default layout、破損/旧設定、device/viewport変更等も確認し、共通構造が最適化を妨げる場合は必要な範囲を再設計してよい。

### 必須表示監査マトリクス

全面監査・主要UI変更・responsive/visual regression確認では、次の画面幅をすべて対象にする：

`320 / 360 / 375 / 390 / 430 / 480 / 520 / 559 / 560 / 600 / 640 / 641 / 700 / 759 / 760 / 834 / 900 / 1024 / 1180 / 1280 / 1366 / 1440 / 1600 / 1920px`

各画面幅について **PC / SP の両モード × 対応7言語の全組み合わせ** を確認する。24幅 × 2モード × 7言語 = **336組み合わせ** を必須マトリクスとし、特に559/560、640/641、759/760のような境界前後は省略しない。

この336組み合わせは、可能な限りGitHub Actions / Playwright / screenshot matrix等の決定論的な自動化で全件実行し、Astra Ultraの利用枠を単純反復処理で消費しない。ただし自動化のPASSだけで品質保証済みとはせず、overflow/clipping、折返し、余白、視覚階層、操作可能領域、テーマ/色漏れ、文言欠落、長文言語での崩れ、SP/PC固有UIの誤表示等を検出できるようテスト内容を設計する。異常・差分・境界条件・品質判断が必要な画面はAstra Ultra自身が実画面/スクリーンショットを確認する。

対象ページ・主要状態に対してマトリクスが未実行、queued/running、失敗、または検査項目が不十分な場合は「表示監査完了」と扱わない。主要UI変更後は影響範囲に応じて再実行する。

## SEO・Discoverability・ASO

Webは世界規模で発見・理解・共有される製品サイトとして、技術SEOだけでなく検索意図、情報設計、コンテンツ品質、多言語SEO、performanceを横断して監査する。少なくとも各公開ページ・対応言語について、title/description、canonical、hreflangと言語・地域指定、robots/index/noindex、robots.txt、XML sitemap、HTTP status/redirect/404、OG/Twitter等のsocial metadata、必要に応じたschema.org/JSON-LD構造化データ、heading/semantic HTML、内部リンク、画像alt、URL設計、重複・thin content、crawlerが主要コンテンツを取得・理解できるrendering、Core Web Vitalsを含む検索体験を確認する。

7言語は単なる直訳やkeyword詰め込みにせず、各言語の自然さ、検索意図、ブランド表現、主要機能の説明、CTA、metadata、構造化データ等の整合性を確認する。SEO指標やLighthouse等の単一スコアを目的化せず、ユーザー価値・可読性・アクセシビリティ・ブランド品質を損なう最適化は行わない。検索エンジン向けの隠し文言、過剰なkeyword反復、内容の薄い量産ページ等も採用しない。

AppはWeb SEOとは区別しつつ、App Store / Google Play等のASOとWebとのdiscoverabilityを横断監査する。ストア名・説明・keywords相当・カテゴリ・スクリーンショット/訴求・localization・ブランド/機能表現の整合、Webからストア/アプリへの導線、deep link / Universal Links / Android App Links等を実装・配布形態に応じて確認する。未公開・未確定のストア情報や機能を推測で追加しない。

SEO/ASOは公開環境・配布環境でしか確定できない項目を区別し、実装だけで完了扱いしない。自動検証可能なmetadata、リンク、sitemap、structured data、status、rendering等はCI/テストへ寄せ、検索意図・コピー品質・多言語自然性・情報設計・ブランド判断はAstra Ultraが評価する。変更後は関連するvisual/accessibility/performance/regressionも確認する。

## Astra・自動化

root cause分析、複雑な不具合、security、データ安全性、設計、App/Web横断判断、UI/UX・product design・visual quality等、高度な推論が必要な仕事はAstra Ultraが担う。

formatter、lint、static analysis、build、定型テスト、Playwright、viewport/language/theme等のmatrix、screenshot生成等の決定論的・反復処理はActions/CI/通常ツールへ任せ、必要なら再利用可能で高効率な専用Action/testを作成してよい。CI/test成功を無条件に品質保証とは扱わず、テスト自体の網羅性・妥当性も必要に応じて評価する。

サブエージェントの具体的な利用・timeout・wait・polling方針は `AGENTS.md` の最新指示に従う。AIサブエージェントとActions/CI/test等の非AI並列処理を区別する。

品質を落とさず、重複読み込み・重複推論・短時間polling・不要なcontext再投入・Astraで行う必要のない単純処理だけを削減する。具体的な調査順序・実装方法・テスト戦略は、最終品質を最大化できる方法をAstra Ultra自身が選択する。

## 完了基準

一部修正やbuild/test/CI成功、利用上限到達を全面監査完了とは扱わない。App＋Web＋横断監査、必要な修正・改善、実画面UI/UX評価、SP/PC/DeX最適化、必須表示監査マトリクス、SEO/Discoverability/ASO、regression、修正後再監査まで継続する。

合理的に「現時点で明確に直すべき問題がもう見つからない」と判断できる完成度を目標に、自律的に監査→判断→実装→検証→checkpoint→次の問題→再監査を進める。checkpoint・push・継続情報・自動再開は `AGENTS.md` の最新ルールに従う。
