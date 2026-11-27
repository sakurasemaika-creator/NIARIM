import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../l10n/app_localizations.dart';
import '../../models/opal_gifts.dart';
import '../../services/api/community_api.dart';
import '../../services/api/niarim_api_exception.dart';
import '../../services/community_service.dart';
import '../../services/google_auth_service.dart';
import '../../utils/app_locale.dart';
import '../../utils/tolerant_preferences.dart';
import '../../widgets/ad_banner_mock_widget.dart';
import '../../widgets/empty_state_placeholder.dart';
import '../../widgets/fit_or_hide_title.dart';
import '../../widgets/icon_notice.dart';
import '../../widgets/keep_together_text.dart';
import '../../widgets/sheet_list_segment.dart';
import '../../widgets/typing_dialog_inset.dart';

/// Saved per NIARIM account once the post-sign-in coupon offer was shown on
/// this device (`<prefix><niarimUserId>`, a bool).
const String opalCouponOfferShownPrefix = 'opal.couponOffer.v1.';

/// The offer is shown only while the server account is this new.
const Duration opalCouponOfferAccountAge = Duration(hours: 1);

/// Canonical form the server also uses: full-width ASCII folded, upper case,
/// spaces and hyphens removed. Null when it cannot be a code.
String? normalizeOpalCouponCode(String raw) {
  final folded = StringBuffer();
  for (final rune in raw.runes) {
    if (rune == 0x3000) continue;
    folded.writeCharCode(
      rune >= 0xFF01 && rune <= 0xFF5E ? rune - 0xFEE0 : rune,
    );
  }
  final code = folded.toString().toUpperCase().replaceAll(
    RegExp(r'[\s\-_.‐-―−ー・]'),
    '',
  );
  return RegExp(r'^[A-Z0-9]{4,32}$').hasMatch(code) ? code : null;
}

String _newRequestId() {
  final random = Random.secure();
  return List.generate(32, (_) => random.nextInt(16).toRadixString(16)).join();
}

String _couponErrorText(AppLocalizations l10n, Object error) {
  if (error is NiarimApiException) {
    switch (error.code) {
      case 'COUPON_INVALID_CODE':
        return l10n.opalCouponErrorFormat;
      case 'COUPON_NOT_FOUND':
        return l10n.opalCouponErrorNotFound;
      case 'COUPON_ENDED':
        return l10n.opalCouponErrorEnded;
      case 'COUPON_EXPIRED':
        return l10n.opalCouponErrorExpired;
      case 'COUPON_NOT_YET_VALID':
        return l10n.opalCouponErrorNotYet;
      case 'COUPON_LIMIT_REACHED':
        return l10n.opalCouponErrorLimit;
      case 'COUPON_ALREADY_REDEEMED':
        return l10n.opalCouponErrorUsed;
      case 'COUPON_NEW_ACCOUNTS_ONLY':
        return l10n.opalCouponErrorNewOnly;
      case 'COUPON_NOT_ELIGIBLE':
        return l10n.opalCouponErrorNotEligible;
      case 'COUPON_RATE_LIMITED':
        return l10n.opalCouponErrorRateLimited;
    }
    if (error.isUnauthorized) return l10n.opalGiftSignInRequired;
  }
  return l10n.opalGiftClaimFailed;
}

/// Whether the error is a definite answer about this code (the same request
/// must not be sent again), rather than a lost or failed request.
bool _isDefiniteCouponAnswer(Object error) =>
    error is NiarimApiException &&
    !error.isNetworkError &&
    !error.isServerError &&
    error.code != 'GIFT_RETRY';

void _showReceived(BuildContext context, int coins) {
  final l10n = appLocalizationsOf(context);
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: messageText(l10n.opalGiftReceived(l10n.coinAmount(coins))),
      persist: false,
    ),
  );
}

/// Opens the coupon code dialog. Returns the opals credited, or null.
Future<int?> showOpalCouponDialog(
  BuildContext context, {
  bool offer = false,
}) async {
  final api = context.read<CommunityService>().api;
  if (api == null) return null;
  final coins = await showDialog<int>(
    context: context,
    builder: (_) => OpalCouponDialog(api: api, offer: offer),
  );
  if (coins != null && context.mounted) {
    opalWalletRevision.value++;
    _showReceived(context, coins);
  }
  return coins;
}

/// Right after an interactive Google sign-in: offers the coupon entry once
/// per NIARIM account on this device, only when the server created the
/// account moments ago. Any failure just skips the offer.
Future<void> maybeOfferOpalCouponAfterSignIn(BuildContext context) async {
  final api = context.read<CommunityService>().api;
  final auth = context.read<GoogleAuthService>();
  if (api == null || auth.account == null) return;
  final OpalGiftInbox inbox;
  try {
    inbox = OpalGiftInbox.fromJson(await api.myGifts());
  } catch (_) {
    return;
  }
  final age = inbox.accountAgeSeconds;
  if (age == null || age > opalCouponOfferAccountAge.inSeconds) return;
  final prefs = await SharedPreferences.getInstance();
  final key = '$opalCouponOfferShownPrefix${inbox.niarimUserId}';
  if (prefs.readBool(key) == true) return;
  if (!await prefs.setBool(key, true)) return;
  if (!context.mounted) return;
  await showOpalCouponDialog(context, offer: true);
}

/// Coupon code entry. Enter submits; a second press while sending does
/// nothing; a retry after a lost response reuses the same request id.
class OpalCouponDialog extends StatefulWidget {
  const OpalCouponDialog({super.key, required this.api, this.offer = false});

  final CommunityApi api;

  /// The once-only offer after the first sign-in (different title, "Later").
  final bool offer;

  @override
  State<OpalCouponDialog> createState() => _OpalCouponDialogState();
}

class _OpalCouponDialogState extends State<OpalCouponDialog> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  String? _pendingCode;
  String? _pendingRequestId;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() => setState(() => _error = null);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = appLocalizationsOf(context);
    final code = normalizeOpalCouponCode(_controller.text);
    if (code == null) {
      setState(() => _error = l10n.opalCouponErrorFormat);
      return;
    }
    if (_pendingCode != code) {
      _pendingCode = code;
      _pendingRequestId = _newRequestId();
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await widget.api.redeemCoupon(
        code: code,
        requestId: _pendingRequestId!,
      );
      final coins = result['awardedCoins'];
      if (result['redeemed'] != true || coins is! int) {
        throw const FormatException('Invalid coupon answer');
      }
      if (!mounted) return;
      Navigator.of(context).pop(coins);
    } catch (error) {
      if (!mounted) return;
      if (_isDefiniteCouponAnswer(error)) _pendingCode = null;
      setState(() {
        _busy = false;
        _error = _couponErrorText(l10n, error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    final canSubmit = !_busy && _controller.text.trim().isNotEmpty;
    return AlertDialog(
      key: const Key('opalCouponDialog'),
      insetPadding: typingDialogInsetPadding(context),
      scrollable: true,
      title: Text(
        widget.offer ? l10n.opalCouponOfferTitle : l10n.opalCouponEnter,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          messageText(
            widget.offer ? l10n.opalCouponOfferBody : l10n.opalCouponIntro,
          ),
          const SizedBox(height: 16),
          TextField(
            key: const Key('opalCouponField'),
            controller: _controller,
            autofocus: true,
            enabled: !_busy,
            autocorrect: false,
            enableSuggestions: false,
            textCapitalization: TextCapitalization.characters,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: TextInputAction.done,
            inputFormatters: [LengthLimitingTextInputFormatter(64)],
            decoration: InputDecoration(
              labelText: l10n.opalCouponField,
              hintText: l10n.opalCouponFieldHint,
              helperText: l10n.opalCouponFieldHelper,
              helperMaxLines: 3,
            ),
            onEditingComplete: () {},
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            IconNotice(
              _error!,
              key: const Key('opalCouponError'),
              liveRegion: true,
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          key: const Key('opalCouponCancel'),
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: Text(widget.offer ? l10n.opalCouponLater : l10n.commonCancel),
        ),
        FilledButton(
          key: const Key('opalCouponSubmit'),
          onPressed: canSubmit ? _submit : null,
          child: Text(l10n.opalGiftClaim),
        ),
      ],
    );
  }
}

/// Wallet actions: coupon entry and the present box with the number of
/// presents not yet received. Shown only when signed in.
class OpalGiftActions extends StatefulWidget {
  const OpalGiftActions({super.key, this.leading = const []});

  /// Buttons placed before the gift entries in the same wrapping row.
  final List<Widget> leading;

  @override
  State<OpalGiftActions> createState() => _OpalGiftActionsState();
}

class _OpalGiftActionsState extends State<OpalGiftActions> {
  GoogleAuthService? _auth;
  String? _accountId;
  int _unclaimed = 0;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _auth = context.read<GoogleAuthService>()..addListener(_onAccount);
      _onAccount();
    });
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAccount);
    super.dispose();
  }

  void _onAccount() {
    final id = _auth?.account?.id;
    if (id == _accountId) return;
    setState(() {
      _accountId = id;
      _unclaimed = 0;
    });
    _refresh();
  }

  Future<void> _refresh() async {
    final api = context.read<CommunityService>().api;
    final id = _accountId;
    final request = ++_request;
    if (api == null || id == null) return;
    try {
      final inbox = OpalGiftInbox.fromJson(await api.myGifts());
      if (!mounted || request != _request || _accountId != id) return;
      setState(() => _unclaimed = inbox.unclaimedCount);
    } catch (_) {
      // The badge is a hint; the present box itself reports failures.
    }
  }

  Future<void> _openPresents() async {
    await Navigator.of(context).push(
      adMockMaterialPageRoute<void>(
        builder: (_) => const OpalPresentBoxScreen(),
      ),
    );
    if (mounted) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final api = context.select<CommunityService, CommunityApi?>((s) => s.api);
    if (api == null || _accountId == null) {
      return Wrap(spacing: 4, children: widget.leading);
    }
    final l10n = appLocalizationsOf(context);
    // Text buttons like the wallet's other actions; the labels wrap inside
    // the button (Kuramubon draws outside its line, hence the 4px).
    Widget label(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: messageText(text),
    );
    return Wrap(
      spacing: 4,
      children: [
        ...widget.leading,
        TextButton.icon(
          key: const Key('opalCouponButton'),
          icon: const Icon(Icons.confirmation_number_outlined),
          onPressed: () => showOpalCouponDialog(context),
          label: label(l10n.opalCouponEnter),
        ),
        Semantics(
          value: _unclaimed > 0
              ? l10n.opalGiftUnclaimedCount(_unclaimed)
              : null,
          child: TextButton.icon(
            key: const Key('opalPresentBoxButton'),
            icon: Badge.count(
              key: const Key('opalPresentBadge'),
              count: _unclaimed,
              isLabelVisible: _unclaimed > 0,
              child: const Icon(Icons.card_giftcard_outlined),
            ),
            onPressed: _openPresents,
            label: label(l10n.opalGiftPresentBox),
          ),
        ),
      ],
    );
  }
}

/// The present box: presents the operator sent to this account, newest
/// deadline first, with the deadline and a receive button. Expired presents
/// are not listed (the server leaves them out).
class OpalPresentBoxScreen extends StatefulWidget {
  const OpalPresentBoxScreen({super.key});

  @override
  State<OpalPresentBoxScreen> createState() => _OpalPresentBoxScreenState();
}

class _OpalPresentBoxScreenState extends State<OpalPresentBoxScreen> {
  OpalGiftInbox? _inbox;
  bool _loading = true;
  bool _failed = false;
  final Set<String> _claiming = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    final api = context.read<CommunityService>().api;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      if (api == null) throw StateError('No backend');
      final inbox = OpalGiftInbox.fromJson(await api.myGifts());
      if (!mounted) return;
      setState(() {
        _inbox = inbox;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<void> _claim(OpalPresent present) async {
    if (_claiming.contains(present.id)) return;
    final api = context.read<CommunityService>().api;
    if (api == null) return;
    final l10n = appLocalizationsOf(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    setState(() => _claiming.add(present.id));
    try {
      final result = await api.claimPresent(present.id);
      final coins = result['awardedCoins'];
      if (result['claimed'] != true || coins is! int) {
        throw const FormatException('Invalid present answer');
      }
      if (!mounted) return;
      setState(() => _inbox = _inbox?.withClaimed(present.id));
      opalWalletRevision.value++;
      _showReceived(context, coins);
    } catch (error) {
      if (!mounted) return;
      final code = error is NiarimApiException ? error.code : null;
      final text = switch (code) {
        'PRESENT_EXPIRED' => l10n.opalGiftPresentExpired,
        'PRESENT_ENDED' || 'PRESENT_NOT_FOUND' => l10n.opalGiftPresentEnded,
        _ when error is NiarimApiException && error.isUnauthorized =>
          l10n.opalGiftSignInRequired,
        _ => l10n.opalGiftClaimFailed,
      };
      messenger?.showSnackBar(
        SnackBar(content: messageText(text), persist: false),
      );
      if (code != null && code.startsWith('PRESENT_')) _load();
    } finally {
      if (mounted) setState(() => _claiming.remove(present.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    return Scaffold(
      appBar: AppBar(title: FitOrHideTitle(l10n.opalGiftPresentBox)),
      body: SafeArea(top: false, child: _body(context, l10n)),
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n) {
    final inbox = _inbox;
    if (_loading && inbox == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed && inbox == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconNotice.caution(
                l10n.opalGiftLoadFailed,
                key: const Key('opalPresentLoadFailed'),
                liveRegion: true,
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                key: const Key('opalPresentReload'),
                onPressed: _load,
                child: Text(l10n.opalGiftReload),
              ),
            ],
          ),
        ),
      );
    }
    final presents = inbox?.presents ?? const <OpalPresent>[];
    if (presents.isEmpty) {
      final text = Theme.of(context).textTheme;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const Key('opalPresentEmpty'),
            mainAxisSize: MainAxisSize.min,
            children: [
              const EmptyStateIcon(icon: Icons.card_giftcard_outlined),
              const SizedBox(height: 12),
              Text(
                l10n.opalGiftPresentEmpty,
                style: text.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              messageText(
                l10n.opalGiftPresentEmptyHint,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16 + MediaQuery.paddingOf(context).bottom,
      ),
      itemCount: presents.length,
      itemBuilder: (context, index) => SheetListSegment(
        first: index == 0,
        last: index == presents.length - 1,
        dividerIndent: 16,
        child: _PresentRow(
          present: presents[index],
          busy: _claiming.contains(presents[index].id),
          onClaim: () => _claim(presents[index]),
        ),
      ),
    );
  }
}

class _PresentRow extends StatelessWidget {
  const _PresentRow({
    required this.present,
    required this.busy,
    required this.onClaim,
  });

  final OpalPresent present;
  final bool busy;
  final VoidCallback onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = appLocalizationsOf(context);
    final theme = Theme.of(context);
    final message = present.messageFor(l10n.localeName);
    final muted = theme.colorScheme.onSurfaceVariant;
    return Padding(
      key: ValueKey('opalPresent.${present.id}'),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(message.title, style: theme.textTheme.titleMedium),
          if (message.body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(message.body, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  messageText(
                    l10n.coinAmount(present.coins),
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    l10n.opalGiftClaimUntil(present.claimUntil),
                    key: const Key('opalPresentDeadline'),
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                ],
              ),
              if (present.claimed)
                Row(
                  key: const Key('opalPresentClaimed'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, size: 18, color: muted),
                    const SizedBox(width: 6),
                    Text(
                      l10n.opalGiftClaimed,
                      style: theme.textTheme.labelLarge?.copyWith(color: muted),
                    ),
                  ],
                )
              else
                FilledButton(
                  key: const Key('opalPresentClaim'),
                  onPressed: busy ? null : onClaim,
                  child: Text(l10n.opalGiftClaim),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
