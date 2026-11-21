import '../../models/filter_def.dart';

/// Every filter, including built-in, duplicated, and user-defined entries,
/// gets the same distraction-free canvas while its parameters are active.
bool shouldUseImmersiveFilterUi({
  required bool panelOpen,
  required bool desktop,
  required FilterDef? selectedFilter,
}) => panelOpen && (!desktop || selectedFilter != null);
