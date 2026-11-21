import 'dart:async';
import 'dart:io';

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

import '../../l10n/app_localizations.dart';
import '../../services/api/niarim_api_exception.dart';
import '../../services/community_service.dart';
import '../../services/youtube_upload_service.dart';

/// What went wrong, in the viewer's language, with what they can do next.
///
/// The text of [error] itself is never shown: the backend writes its
/// messages in Japanese only, and platform exceptions are written for
/// developers. Anything not recognised falls back to a generic message.
String communityErrorText(AppLocalizations l10n, Object error) {
  if (error is NiarimApiException) {
    return communityApiErrorCodeText(l10n, error.code) ??
        _apiStatusText(l10n, error);
  }
  if (error is GoogleSignInException) {
    return error.code == GoogleSignInExceptionCode.canceled
        ? l10n.communityErrorSignInCanceled
        : l10n.communityErrorGoogleSignIn;
  }
  if (error is YoutubeUploadException) return l10n.communityErrorYoutubeUpload;
  if (error is FileSystemException) return l10n.communityErrorVideoFile;
  if (error is SocketException ||
      error is TimeoutException ||
      error is http.ClientException) {
    return l10n.communityErrorNetwork;
  }
  if (error is UnsupportedError) return l10n.communityErrorUnsupported;
  return l10n.communityErrorGeneric;
}

/// The message for a backend error [code] (the `code` field of its error
/// reply), or null when the code has no message of its own and the HTTP
/// status should decide instead.
String? communityApiErrorCodeText(AppLocalizations l10n, String? code) =>
    switch (code) {
      'TAG_LIMIT_EXCEEDED' => l10n.communityErrorTagLimitExceeded(
        CommunityService.maxTagsPerWork,
      ),
      'TAG_TOO_LONG' => l10n.communityErrorTagTooLong,
      'TAG_UPDATE_CONFLICT' => l10n.communityErrorTagUpdateConflict,
      'WORK_CHANGED' => l10n.communityErrorWorkChanged,
      'VIDEO_NOT_FOUND' => l10n.communityErrorVideoNotFound,
      'VIDEO_ALREADY_REGISTERED' => l10n.communityErrorVideoAlreadyRegistered,
      'WORK_DELETED' => l10n.communityErrorWorkDeleted,
      'VIDEO_REGISTRATION_CONFLICT' =>
        l10n.communityErrorVideoRegistrationConflict,
      'POST_QUOTA_EXCEEDED' => l10n.communityErrorPostQuotaExceeded,
      _ => null,
    };

String _apiStatusText(AppLocalizations l10n, NiarimApiException error) {
  if (error.isNetworkError) return l10n.communityErrorNetwork;
  if (error.isUnauthorized) return l10n.communityErrorSignInRequired;
  if (error.isForbidden) return l10n.communityErrorForbidden;
  if (error.isNotFound) return l10n.communityErrorNotFound;
  if (error.isRateLimited) return l10n.communityErrorRateLimited;
  if (error.isServerError) return l10n.communityErrorServer;
  return l10n.communityErrorGeneric;
}
