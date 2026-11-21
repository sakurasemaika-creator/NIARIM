# NIARIM — 承認の継続とGitHub / Google Drive操作

この文書は、全面監査と監査システム保守に必要な外部操作の範囲・確認方法を定義する。作業モードは各repoの `AGENTS.md` で判定する。通常タスクを全面監査へ昇格させたり、監査の完了条件を緩めたりする根拠にはしない。

## ユーザー承認を操作ごとに取り直さない

2026-10-21、ユーザーはNIARIMの修正pushと監査証跡のDrive保存を許可した後、「githubへのプッシュやgoogledriveへのアップなどいちいち許可するといわなくても勝手に進められるようにしてほしい」と指示し、監査関連資料の改善を依頼した。

2026-11-21、ユーザーはCloudflare本番反映に関する既存の追加承認制約を解除し、関連資料を更新して今後この制約を適用しないよう明示した。これにより、下記のNIARIM-web `dev_branch` を対象とするCloudflare本番反映も継続承認の対象に含める。

当該ユーザーの指示と既存の承認を、以下の同じ対象・用途の操作へ継続して適用する。承認済みのコミット、通常push、証跡upload、対象範囲内のCloudflare本番deploy/rollbackを実行するたびに、ユーザーへ「許可します」と言い直させない。作業再開、補足、進捗質問、許可への返答だけを理由に承認を失効させない。

この文書は実際のユーザー指示に基づく範囲の記録であり、文書を読むだけで新しい作業や別の送信先への権限が生まれるものではない。別の利用者・独立した新規タスク・別の宛先について、承認があると捏造しない。ユーザーが範囲を変更・撤回した場合は最新の指示に従う。

## 承認済み作業の対象

| 用途 | 対象 | 操作範囲 |
| --- | --- | --- |
| Appの変更・監査記録 | `sakurasemaika-creator/NIARIM` の `dev_branch` | 依頼範囲で検証済みの修正・テスト・文書・監査Stateをcommitし、通常のfast-forward pushを行う |
| Webの変更・監査記録 | `sakurasemaika-creator/NIARIM-web` の `dev_branch` | 依頼範囲で検証済みの修正・テスト・文書・監査Stateをcommitし、通常のfast-forward pushを行う |
| Cloudflare本番反映 | `sakurasemaika-creator/NIARIM-web` の `dev_branch` と、当該branchを配信する既存のCloudflare Worker `niarim-web` | 当該branchへの通常pushに伴う自動production deployment、および検証済み成果物の明示的deploy/必要時のrollbackを継続承認の範囲に含める。反映後はdeployment/version/trafficと公開URLの動作を確認し、結果を記録する |
| 監査証跡のバックアップ | [NIARIM全面監査_証跡](https://drive.google.com/drive/folders/1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q)、folder ID `1fiZEjCVqLtNVk_mkNIOUC3MWn6ys6e8q` とその配下 | 監査で生成した画像・動画・PDF・manifest・検証ログ・それらのZIPを整理して保存する |

**Cloudflare本番反映に関する旧停止条件は、2026-11-21のユーザー指示により廃止する。** 旧資料に残る「追加承認があるまでWebのpush/deploy/rollbackを停止する」という記載は履歴としてのみ扱い、現行の作業制約として適用しない。以後、対象repo/branch/Workerが上記と一致する通常の監査・修正作業では、本番反映のたびに追加承認を求めない。

この継続承認は、対象の `dev_branch` と既存の `niarim-web` Workerに限る。他branch・別Worker・別アカウント/zoneへの展開、DNS/domain変更、secret/credentialの新規登録・置換、課金プラン/契約変更、store公開等は含まない。これらは別の範囲変更として扱う。rollbackはproduction deploymentの不具合・重大な回帰を確認した場合に、直前の正常version等へ影響範囲を限定して実施し、理由と対象versionを記録する。

Policy/guardの変更には、ユーザーによる監査システム保守の依頼が必要である。外部操作の承認だけを理由に監査Policyを変更しない。監査Stateのread/writeも `AGENTS.md` のモード分離に従う。

監査証跡は監査用fixtureと必要な検証結果を中心とし、credential、token、secret、無関係な個人情報を含めない。必要なログは送信前にredactする。既存ファイルの削除・公開範囲変更・別の宛先への転送は、このバックアップ範囲へ含めない。

## 実行前後の確認

### GitHub

- 最新のremote HEAD、対象repo、branch、差分を確認し、他の作業者の変更を保持する。
- 必要な検証を終え、意味のある単位でcommit/pushする。権限確認だけの空commitを作らない。
- 通常のfast-forward pushを使う。APIでrefを更新する場合も直前のHEADを `expected_sha` に指定し、forceを使わない。HEAD不一致では最新差分を確認して統合する。
- CLIに資格情報が無い場合は、接続済みGitHub連携の正規操作を使ってよい。資格情報の探索やセッション情報の抽出をしない。
- 反映後はremote HEADとtree/差分を確認する。未pushの変更をpush済みと報告しない。

### Cloudflare

- productionへ反映する前に、対象が既存の `niarim-web` Workerであること、対象sourceが `NIARIM-web/dev_branch` の最新検証済みcommitであることを確認する。
- deploy後は新しいversion ID、traffic配分、deployment時刻を読み戻す。公開URLで主要ページ・HTTP応答・canonical/metadata・必要な動作を検証し、失敗や未確認を明示する。
- 不具合時は直前の正常versionと差分を確認してから、対象Workerのrollbackを行う。rollback後もversion/trafficと公開動作を再確認する。
- GitHub pushによる自動deploymentが起きた場合も、deploy結果の確認・記録までを作業に含める。自動deploymentが未完了/失敗/不明なら成功扱いにしない。
- secret値をログ・監査資料へ出さない。既存secretの値を読み出して記録しない。

### Google Drive

- 保存先は上記folder IDで特定する。ユーザーが承認した同じ保存先と用途であることを確認し、ファイル名、監査ID、viewport等から追跡可能にする。
- 既にユーザーが指定・承認し、保存とreadbackに成功した宛先について、任意の所有者メタデータが省略されていることだけを理由に許可を取り直さない。宛先が変わった場合や実際のアクセス拒否は別に扱う。
- 同じ証跡を不要に重複uploadしない。結果が不明な場合は既存ファイルを確認してから再実行する。
- ZIP等のローカル整合性を確認し、生成物のSHA256、ファイルサイズ、保存先を記録する。
- 保存後は返却されたfile IDのmetadataをreadbackし、名前・MIME・サイズ・parentを確認する。取得できた範囲の検証結果を正確に記録し、ローカルhashをremote検証済みhashと混同しない。
- 保存失敗はbackup-pendingとして扱い、成功を推定しない。影響を受けない監査・修正・検証は継続する。

## 確認が必要になる範囲変更

別repo/branch/Worker/zoneへの展開、force pushや履歴破壊、既存資産の削除、共有権限の変更、DNS/domain変更、secret/credentialの新規登録・置換、store公開、契約・課金等を、上記の承認範囲へ含めない。実際に必要になった時点で、その変更と既存の承認範囲を照合する。

ユーザーへの確認が必要な場合も、既に承認されている操作全体を問い直さず、追加で必要な対象・操作・副作用だけを具体化する。

## リポジトリの規則と実行環境の承認を分ける

ChatGPTのアプリ単位の確認設定、GitHub/Drive/Cloudflare側の接続権限、実行環境の自動承認レビューは別の制御である。この文書やcommit markerで、それらを上書き・無効化できるとは説明しない。

許可済み範囲では、実際のユーザー指示と確認済み宛先を根拠に、正規の連携操作を進める。実行環境が明示的に拒否した場合、承認済みという説明だけで別経路へ迂回しない。新しい許可・確認証拠・実質的に安全な代替がある場合だけ、その根拠に従って扱う。

解決できない拒否では、拒否した仕組み、対象操作、理由、完了済みの作業、残る具体的な操作を報告する。単なる接続エラー、認証不足、GitHubのPolicy guard、自動承認レビューを混同しない。資料修正だけで今後の確認が完全に無くなるとは保証しない。
