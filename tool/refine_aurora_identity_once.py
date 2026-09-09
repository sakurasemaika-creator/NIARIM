from pathlib import Path
import re

path = Path('lib/engine/filter_engine.dart')
text = path.read_text()
replacement = r'''List<(double, int, int, int)> auroraHologramStops(AuroraHologramPreset preset) {
  // Every preset keeps short interference bands and pearl peaks so it still
  // reads as holographic, but each one now has a deliberately different
  // dominant colour family. The goal is "same material, different mood",
  // rather than six variants of the same cyan/pink rainbow.
  return switch (preset) {
    // Northern lights: deep ocean blue -> turquoise -> aurora green ->
    // ultraviolet. Warm hues are nearly absent on purpose.
    AuroraHologramPreset.aurora => const [
      (0.00, 12, 72, 118),
      (0.06, 18, 141, 174),
      (0.12, 42, 224, 205),
      (0.18, 156, 255, 182),
      (0.24, 231, 255, 214),
      (0.30, 76, 221, 238),
      (0.38, 31, 143, 223),
      (0.46, 77, 88, 210),
      (0.54, 145, 91, 222),
      (0.60, 235, 230, 255),
      (0.66, 57, 227, 209),
      (0.74, 131, 255, 170),
      (0.82, 44, 176, 235),
      (0.90, 87, 91, 218),
      (0.96, 178, 123, 232),
      (1.00, 246, 253, 255),
    ],

    // Soap bubble: near-transparent pearlescence. White, ice-blue, blush,
    // lilac and champagne repeat softly, with no dark anchor colours.
    AuroraHologramPreset.soapBubble => const [
      (0.00, 244, 252, 255),
      (0.05, 255, 255, 255),
      (0.10, 217, 246, 255),
      (0.16, 230, 224, 255),
      (0.22, 255, 219, 238),
      (0.28, 255, 238, 202),
      (0.34, 236, 255, 223),
      (0.40, 255, 255, 255),
      (0.47, 210, 242, 255),
      (0.54, 244, 219, 255),
      (0.61, 255, 221, 230),
      (0.68, 255, 246, 214),
      (0.75, 221, 255, 234),
      (0.83, 248, 251, 255),
      (0.91, 225, 232, 255),
      (1.00, 255, 255, 255),
    ],

    // Cyber neon: black-light hologram. Deep indigo anchors electric cyan,
    // laser blue, hot magenta, acid lime and violet; whites are very sparse.
    AuroraHologramPreset.cyberNeon => const [
      (0.00, 18, 11, 62),
      (0.06, 28, 32, 142),
      (0.12, 0, 129, 255),
      (0.18, 0, 245, 255),
      (0.24, 55, 255, 160),
      (0.30, 199, 255, 42),
      (0.36, 255, 33, 151),
      (0.42, 255, 57, 223),
      (0.49, 142, 44, 255),
      (0.56, 44, 30, 184),
      (0.63, 0, 182, 255),
      (0.70, 0, 255, 216),
      (0.77, 171, 255, 47),
      (0.84, 255, 37, 170),
      (0.92, 176, 57, 255),
      (1.00, 28, 65, 210),
    ],

    // Pastel dream: milky low-saturation candy colours. Baby blue, lavender,
    // rose, peach, butter yellow and mint drift through creamy highlights.
    AuroraHologramPreset.pastelDream => const [
      (0.00, 223, 236, 255),
      (0.07, 242, 233, 255),
      (0.14, 255, 225, 240),
      (0.21, 255, 226, 211),
      (0.28, 255, 244, 199),
      (0.35, 225, 250, 221),
      (0.42, 239, 250, 255),
      (0.49, 255, 252, 247),
      (0.56, 219, 232, 255),
      (0.63, 239, 222, 255),
      (0.70, 255, 217, 235),
      (0.77, 255, 230, 205),
      (0.84, 247, 245, 204),
      (0.91, 218, 247, 227),
      (0.97, 240, 247, 255),
      (1.00, 255, 255, 255),
    ],

    // Sunset gold: copper/rose/orange/gold dominate. Violet only appears as
    // a reflected fringe, keeping the preset warm and foil-like rather than
    // another full-spectrum rainbow.
    AuroraHologramPreset.sunsetGold => const [
      (0.00, 91, 35, 58),
      (0.06, 145, 51, 74),
      (0.12, 221, 73, 103),
      (0.18, 255, 107, 105),
      (0.24, 255, 149, 88),
      (0.30, 255, 202, 92),
      (0.36, 255, 238, 154),
      (0.42, 255, 250, 220),
      (0.49, 236, 178, 255),
      (0.55, 255, 116, 159),
      (0.62, 255, 151, 83),
      (0.69, 255, 205, 82),
      (0.76, 255, 241, 145),
      (0.84, 255, 214, 183),
      (0.92, 212, 129, 229),
      (1.00, 255, 247, 226),
    ],

    // Silver foil: intentionally near-neutral metal. Charcoal, steel, silver
    // and hard white reflections carry only restrained blue/lilac tinting.
    AuroraHologramPreset.silverFoil => const [
      (0.00, 54, 59, 70),
      (0.06, 92, 103, 118),
      (0.12, 156, 171, 186),
      (0.18, 225, 235, 242),
      (0.23, 255, 255, 255),
      (0.29, 182, 205, 218),
      (0.36, 111, 129, 148),
      (0.43, 211, 218, 235),
      (0.49, 248, 246, 255),
      (0.55, 151, 164, 181),
      (0.62, 233, 242, 245),
      (0.68, 255, 255, 255),
      (0.75, 170, 184, 202),
      (0.82, 211, 218, 236),
      (0.90, 244, 247, 251),
      (1.00, 103, 113, 130),
    ],
  };
}'''

pattern = re.compile(
    r'List<\(double, int, int, int\)> auroraHologramStops\(AuroraHologramPreset preset\) \{.*?\n\}\n\n/// 画素の色を指定方式で減色する',
    re.S,
)
updated, count = pattern.subn(
    replacement + '\n\n/// 画素の色を指定方式で減色する', text, count=1
)
if count != 1:
    raise SystemExit(f'Expected one auroraHologramStops block, found {count}')
path.write_text(updated)
