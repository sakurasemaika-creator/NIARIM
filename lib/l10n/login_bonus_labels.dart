import 'package:flutter/widgets.dart';

class LoginBonusLabels {
  LoginBonusLabels._(this._words);
  final Map<String,String> _words;
  factory LoginBonusLabels.of(BuildContext context) {
    final locale=Localizations.localeOf(context);
    final code=locale.languageCode=='zh' && locale.scriptCode=='Hant'
      ? 'zh_Hant' : locale.languageCode;
    return LoginBonusLabels._(_values[code] ?? _values['en']!);
  }
  String operator [](String key) => _words[key] ?? _values['en']![key] ?? key;
}
const _values=<String,Map<String,String>>{
'ja':{
 'title':'累計ログインボーナス','days':'累計{n}日','daily':'今日のログイン報酬',
 'dailyCoins':'毎日{n}コイン','claim':'受け取る','claimed':'受取済み',
 'notYet':'未達成','milestones':'節目の追加ボーナス',
 'milestone':'累計{n}日達成','coins':'{n}コイン','unknown':'確認できません',
 'unavailable':'報酬の受取機能は現在準備中です','activityMilestone':'累計ログイン{n}日を達成しました','utc':'日付は日本時間の午前0時に切替。休んでも累計日数は減りません。',
 'retry':'更新','failed':'受取を確認できませんでした','success':'コインの受取が確認できました',
 'visitMissing':'今日のログインを確認中です',
},
'en':{'title':'Cumulative login bonuses','days':'Total {n} days','daily':'Today’s login reward','dailyCoins':'{n} coin each day','claim':'Claim','claimed':'Claimed','notYet':'Not achieved','milestones':'Milestone bonuses','milestone':'Logged in {n} days','coins':'{n} coins','unknown':'Unavailable','unavailable':'Claims are not available yet','activityMilestone':'You reached {n} total login days','utc':'Days reset at midnight Japan time (JST). Breaks never reset your total.','retry':'Refresh','failed':'Could not confirm reward','success':'Coins claimed','visitMissing':'Checking today’s visit'},
'es':{'title':'Bonos de acceso acumulado','days':'Total {n} días','daily':'Recompensa de hoy','dailyCoins':'{n} moneda diaria','claim':'Reclamar','claimed':'Reclamado','notYet':'Sin completar','milestones':'Bonos por objetivos','milestone':'{n} días de acceso','coins':'{n} monedas','unknown':'No disponible','unavailable':'Recompensas en preparación','activityMilestone':'¡Has alcanzado {n} días de acceso!','utc':'El día cambia a medianoche de Japón (JST). Las pausas no borran el progreso.','retry':'Actualizar','failed':'No se pudo confirmar','success':'Monedas recibidas','visitMissing':'Comprobando el acceso'},
'fr':{'title':'Bonus de connexion cumulés','days':'Total : {n} jours','daily':'Bonus du jour','dailyCoins':'{n} pièce par jour','claim':'Réclamer','claimed':'Réclamé','notYet':'Non atteint','milestones':'Bonus de palier','milestone':'{n} jours de connexion','coins':'{n} pièces','unknown':'Indisponible','unavailable':'Récompenses bientôt disponibles','activityMilestone':'Vous avez atteint {n} jours de connexion','utc':'La journée change à minuit heure du Japon (JST). Les pauses ne réinitialisent rien.','retry':'Actualiser','failed':'Récompense non confirmée','success':'Pièces reçues','visitMissing':'Vérification de connexion'},
'ko':{'title':'누적 로그인 보너스','days':'누적 {n}일','daily':'오늘의 로그인 보상','dailyCoins':'매일 {n}코인','claim':'받기','claimed':'수령 완료','notYet':'미달성','milestones':'누적 달성 추가 보상','milestone':'누적 {n}일 달성','coins':'{n}코인','unknown':'확인할 수 없음','unavailable':'보상 지급 준비 중','activityMilestone':'누적 로그인 {n}일을 달성했습니다','utc':'일본 시간(JST) 자정에 날짜가 바뀌며 쉬어도 기록은 유지됩니다.','retry':'새로고침','failed':'수령 확인 실패','success':'코인 수령 완료','visitMissing':'오늘의 로그인 확인 중'},
'zh':{'title':'累计登录奖励','days':'累计 {n} 天','daily':'今日登录奖励','dailyCoins':'每日 {n} 金币','claim':'领取','claimed':'已领取','notYet':'未达成','milestones':'里程碑额外奖励','milestone':'累计登录 {n} 天','coins':'{n} 金币','unknown':'无法确认','unavailable':'奖励领取尚未开放','activityMilestone':'累计登录达到 {n} 天','utc':'按日本时间(JST)午夜换日，中断不会重置累计。','retry':'刷新','failed':'无法确认领取','success':'金币已领取','visitMissing':'正在确认今日登录'},
'zh_Hant':{'title':'累計登入獎勵','days':'累計 {n} 天','daily':'今日登入獎勵','dailyCoins':'每日 {n} 金幣','claim':'領取','claimed':'已領取','notYet':'未達成','milestones':'里程碑額外獎勵','milestone':'累計登入 {n} 天','coins':'{n} 金幣','unknown':'無法確認','unavailable':'獎勵領取尚未開放','activityMilestone':'累計登入達到 {n} 天','utc':'按日本時間(JST)午夜換日，中斷不會重設累計。','retry':'重新整理','failed':'無法確認領取','success':'金幣已領取','visitMissing':'正在確認今日登入'},
};
