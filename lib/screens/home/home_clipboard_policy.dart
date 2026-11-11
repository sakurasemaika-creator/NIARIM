/// Clipboard source and destination collections in the create-works screen.
/// The two "Shared" pills are different serialization formats.
enum HomePasteArea { projects, works, received, outgoing, trash }

enum HomePasteDecision { allowed, incompatibleFormat, unsupportedTrashRestore }

abstract final class HomePastePolicy {
  static HomePasteDecision check({
    required HomePasteArea source,
    required HomePasteArea destination,
    required bool containsFiles,
    required bool containsFolders,
  }) {
    if (source == HomePasteArea.trash) {
      return HomePasteDecision.unsupportedTrashRestore;
    }
    if (destination == HomePasteArea.trash) {
      return HomePasteDecision.allowed;
    }
    if (source == destination) return HomePasteDecision.allowed;
    // A folder without any files is format-neutral. Folder hierarchy must
    // still be checked by the destination's storage implementation.
    if (containsFolders && !containsFiles) return HomePasteDecision.allowed;
    return HomePasteDecision.incompatibleFormat;
  }
}
