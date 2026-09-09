from pathlib import Path
import re

path = Path('lib/engine/filter_engine.dart')
text = path.read_text()
replacement = r'''List<(double, int, int, int)> auroraHologramStops(AuroraHologramPreset preset) {
  // Keep every preset recognisably holographic while giving it a distinct
  // colour identity. Uneven stop spacing is intentional: short pearl peaks
  // create foil-like interference flashes instead of a plain rainbow sweep.
  return switch (preset) {
    // Cool northern-light hologram: cyan/mint/blue/violet dominate, with only
    // tiny pink pearl flashes. This should read as "aurora" before "rainbow".
    AuroraHologramPreset.aurora => const [
      (0.00, 56, 191, 224),
      (0.08, 115, 243, 218),
      (0.16, 205, 255, 191),
      (0.23, 238, 255, 230),
      (0.29, 137, 229, 255),
      (0.38, 92, 177, 255),
      (0.47, 151, 132, 246),
      (0.55, 225, 210, 255),
      (0.61, 249, 247, 255),
      (0.67, 117, 239, 228),
      (0.76, 150, 255, 186),
      (0.84, 104, 198, 255),
      (0.92, 186, 157, 250),
      (0.97, 255, 220, 241),
      (1.00, 246, 255, 255),
    ],

    // Soap-film iridescence: very pale translucent-looking rainbow with
    // frequent pearl white, peach and lilac highlights.
    AuroraHologramPreset.soapBubble => const [
      (0.00, 231, 249, 255),
      (0.05, 255, 255, 255),
      (0.11, 255, 226, 210),
      (0.18, 255, 213, 235),
      (0.26, 230, 216, 255),
      (0.34, 205, 239, 255),
      (0.42, 211, 255, 239),
      (0.49, 247, 255, 221),
      (0.55, 255, 255, 255),
      (0.60, 255, 234, 198),
      (0.68, 255, 207, 232),
      (0.76, 221, 205, 255),
      (0.84, 195, 238, 255),
      (0.91, 215, 255, 235),
      (0.96, 255, 248, 219),
      (1.00, 255, 255, 255),
    ],

    // Hard electronic hologram: electric cyan, hot magenta, violet and acid
    // lime. White peaks are sparse so the colours stay punchy and synthetic.
    AuroraHologramPreset.cyberNeon => const [
      (0.00, 10, 182, 255),
      (0.07, 0, 245, 234),
      (0.14, 91, 255, 126),
      (0.20, 236, 255, 57),
      (0.27, 255, 54, 187),
      (0.35, 201, 55, 255),
      (0.43, 103, 69, 255),
      (0.49, 242, 239, 255),
      (0.55, 0, 224, 255),
      (0.63, 0, 255, 203),
      (0.70, 181, 255, 53),
      (0.77, 255, 45, 178),
      (0.85, 221, 63, 255),
      (0.92, 77, 105, 255),
      (1.00, 15, 229, 255),
    ],

    // Milky dreamy hologram: low saturation, lots of creamy white, baby pink,
    // lavender, mint and powder blue. Contrast is intentionally gentle.
    AuroraHologramPreset.pastelDream => const [
      (0.00, 238, 244, 255),
      (0.08, 255, 247, 252),
      (0.16, 255, 220, 232),
      (0.24, 246, 226, 255),
      (0.32, 220, 235, 255),
      (0.40, 214, 250, 241),
      (0.48, 235, 255, 220),
      (0.56, 255, 249, 222),
      (0.64, 255, 230, 218),
      (0.72, 255, 222, 239),
      (0.80, 232, 222, 255),
      (0.88, 218, 240, 255),
      (0.95, 237, 255, 244),
      (1.00, 255, 252, 246),
    ],

    // Warm sunset foil: gold/amber/peach/coral dominate, then rose and plum.
    // A tiny cool reflection keeps it holographic without turning it rainbow.
    AuroraHologramPreset.sunsetGold => const [
      (0.00, 194, 119, 48),
      (0.07, 255, 185, 65),
      (0.14, 255, 229, 134),
      (0.21, 255, 248, 207),
      (0.28, 255, 177, 122),
      (0.36, 255, 120, 129),
      (0.44, 246, 92, 156),
      (0.52, 190, 86, 186),
      (0.59, 116, 93, 187),
      (0.64, 224, 211, 255),
      (0.69, 255, 238, 201),
      (0.77, 255, 197, 87),
      (0.85, 255, 139, 111),
      (0.92, 236, 92, 151),
      (1.00, 255, 228, 174),
    ],

    // Metallic silver foil: mostly neutral silver/white/steel. Subtle icy blue,
    // lilac and champagne reflections appear only as thin interference flashes.
    AuroraHologramPreset.silverFoil => const [
      (0.00, 92, 101, 114),
      (0.08, 154, 164, 177),
      (0.15, 225, 231, 236),
      (0.21, 255, 255, 255),
      (0.27, 184, 202, 216),
      (0.34, 244, 248, 250),
      (0.41, 207, 198, 220),
      (0.48, 251, 249, 242),
      (0.55, 159, 173, 188),
      (0.62, 238, 245, 247),
      (0.68, 255, 255, 255),
      (0.75, 188, 207, 218),
      (0.82, 230, 226, 238),
      (0.89, 247, 242, 229),
      (0.95, 205, 214, 224),
      (1.00, 112, 121, 134),
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
