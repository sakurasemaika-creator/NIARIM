/// What a video track row shows inside its clips. Each video row of a scene
/// keeps its own choice (saved with the project).
enum VideoTrackDisplay {
  /// Frames of the video along the clip, like a filmstrip.
  frames,

  /// The waveform of the video's sound.
  waveform;

  /// The saved [name], or [frames] for a missing or unknown value (projects
  /// saved before rows had a display, or by a later version).
  static VideoTrackDisplay fromName(Object? name) =>
      name == waveform.name ? waveform : frames;
}
