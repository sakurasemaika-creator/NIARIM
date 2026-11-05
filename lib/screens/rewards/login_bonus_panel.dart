import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/login_bonus_labels.dart';
import '../../services/api/community_api.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';

bool canClaimLoginBonus({
  required bool enabled, required bool achieved, required bool claimed,
}) => enabled && achieved && !claimed;

/// Login visits are registered independently from reward claims.
/// Receiving a notification or opening the page NEVER credits local coins.
class LoginBonusPanel extends StatefulWidget {
  const LoginBonusPanel({super.key});

  @override
  State<LoginBonusPanel> createState() => _LoginBonusPanelState();
}

class _LoginBonusPanelState extends State<LoginBonusPanel> {
  String? _owner;
  CommunityApi? _api;
  Future<Map<String,dynamic>>? _future;
  final Set<String> _busy={};

  Future<Map<String,dynamic>> _load(CommunityApi api) async {
    try {
      await api.visitLoginBonus();
    } catch (_) {
      // A temporary visit failure is not a reason to hide saved progress.
    }
    return api.myLoginBonus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final owner=context.watch<GoogleAuthService>().account?.id;
    final api=context.read<CommunityService>().api;
    if (_owner!=owner || !identical(api,_api)) {
      _owner=owner;_api=api;_busy.clear();
      _future=owner!=null && api!=null ? _load(api):null;
    }
  }

  Future<void> _claim(String kind, int? goal) async {
    final owner=_owner, api=_api;
    if (owner==null || api==null) return;
    final key=kind+'${goal??0}';
    if (_busy.contains(key)) return;
    setState(()=>_busy.add(key));
    try {
      final result=await api.claimLoginBonus(kind:kind,days:goal);
      if(!mounted || owner!=_owner || !identical(api,_api) ||
        context.read<GoogleAuthService>().account?.id!=owner)return;
      final t=LoginBonusLabels.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content:Text(result['claimed']==true
          ?t['success']:t['failed'])));
    } catch (_) {
      if(mounted && owner==_owner && identical(api,_api)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content:Text(LoginBonusLabels.of(context)['failed'])));
      }
    } finally {
      if(mounted && owner==_owner && identical(api,_api)) {
        setState(() {
          _busy.remove(key);
          _future=_load(api);
        });
      }
    }
  }

  String _message(String template, Object value)=>
      template.replaceAll('{n}','$value');

  @override
  Widget build(BuildContext context) {
    final t=LoginBonusLabels.of(context);
    final scheme=Theme.of(context).colorScheme;
    if(_owner==null || _api==null)return const SizedBox.shrink();
    return Card(
      key:const Key('loginBonusPanel'),
      child: Padding(
        padding:const EdgeInsets.all(12),
        child:FutureBuilder<Map<String,dynamic>>(
          future:_future,
          builder:(context,snapshot) {
            if(snapshot.connectionState!=ConnectionState.done) {
              return const Center(child:Padding(
                padding:EdgeInsets.all(12),
                child:CircularProgressIndicator()));
            }
            if(snapshot.hasError || !snapshot.hasData) {
              return Row(children:[
                Expanded(child:Text(t['unknown'])),
                IconButton(
                  onPressed:()=>setState(()=>_future=_load(_api!)),
                  icon:const Icon(Icons.refresh),
                ),
              ]);
            }
            final status=snapshot.data!;
            final days=(status['totalDays'] as num?)?.toInt()??0;
            final amount=(status['dailyCoins'] as num?)?.toInt()??1;
            final enabled=status['rewardEnabled']==true;
            final visited=status['visitedToday']==true;
            final dailyClaimed=status['dailyClaimed']==true;
            final milestones=(status['milestones'] as List? ?? const [])
                .whereType<Map>()
                .map(m=>Map<String,dynamic>.from(m))
                .toList();
            milestones.sort((a,b) {
              final ap=a['eligible']==true && a['claimed']!=true?0:1;
              final bp=b['eligible']==true && b['claimed']!=true?0:1;
              if(ap!=bp)return ap-bp;
              return ((a['days'] as num?)?.toInt()??0)
                .compareTo((b['days'] as num?)?.toInt()??0);
            });
            return Column(
              crossAxisAlignment:CrossAxisAlignment.start,
              children:[
                Row(children:[
                  Icon(Icons.calendar_month_outlined,color:scheme.primary),
                  const SizedBox(width:8),
                  Expanded(child:Text(t['title'],
                    style:Theme.of(context).textTheme.titleMedium)),
                  IconButton(
                    tooltip:t['retry'],
                    onPressed:()=>setState(()=>_future=_load(_api!)),
                    icon:const Icon(Icons.refresh),
                  ),
                ]),
                Text(_message(t['days'],days)),
                const SizedBox(height:8),
                Row(children:[
                  Expanded(child:Column(
                    crossAxisAlignment:CrossAxisAlignment.start,
                    children:[
                      Text(t['daily']),
                      Text(_message(t['dailyCoins'],amount),
                        style:Theme.of(context).textTheme.bodySmall),
                    ],
                  )),
                  FilledButton(
                    key:const Key('loginDailyClaimButton'),
                    onPressed:canClaimLoginBonus(
                      enabled:enabled,achieved:visited,claimed:dailyClaimed,
                    ) && !_busy.contains('daily0')
                      ? ()=>_claim('daily',null):null,
                    child:Text(dailyClaimed?t['claimed']:t['claim']),
                  ),
                ]),
                if(!visited)Text(t['visitMissing'],
                  style:Theme.of(context).textTheme.bodySmall),
                if(!enabled)Text(t['unavailable'],
                  style:Theme.of(context).textTheme.bodySmall),
                const SizedBox(height:8),
                Text(t['utc'],style:Theme.of(context).textTheme.bodySmall),
                ExpansionTile(
                  key:const Key('loginMilestoneExpansion'),
                  title:Text(t['milestones']),
                  children:milestones.map((m) {
                    final goal=(m['days'] as num?)?.toInt()??0;
                    final coins=(m['coins'] as num?)?.toInt()??0;
                    final claimed=m['claimed']==true;
                    final eligible=m['eligible']==true;
                    return ListTile(
                      key:Key('loginMilestone$goal'),
                      leading:Icon(eligible && !claimed
                        ? Icons.priority_high_rounded:Icons.flag_outlined,
                        color:eligible?scheme.primary:scheme.onSurfaceVariant),
                      title:Text(_message(t['milestone'],goal)),
                      subtitle:Text(_message(t['coins'],coins)),
                      trailing:claimed?Text(t['claimed'])
                        :OutlinedButton(
                          onPressed:canClaimLoginBonus(
                            enabled:enabled,achieved:eligible,claimed:claimed,
                          ) && !_busy.contains('milestone$goal')
                            ? ()=>_claim('milestone',goal):null,
                          child:Text(eligible?t['claim']:t['notYet']),
                        ),
                    );
                  }).toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
