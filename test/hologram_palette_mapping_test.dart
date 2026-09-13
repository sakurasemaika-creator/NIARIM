import 'package:flutter_test/flutter_test.dart';
import 'package:niarim/engine/filter_engine.dart';
import 'package:niarim/models/filter_def.dart';

void main() {
  test(
    'Pearl 2 keeps earlier Pastel Dream while Pastel Dream is pink-rainbow',
    () {
      expect(
        auroraHologramStops(AuroraHologramPreset.pearl2),
        equals(const [
          (0.00, 223, 236, 255),
          (0.07, 242, 233, 255),
          (0.14, 255, 225, 240),
          (0.21, 255, 226, 211),
          (0.28, 255, 244, 199),
          (0.35, 225, 250, 221),
          (0.42, 34, 224, 255),
          (0.49, 255, 255, 255),
          (0.56, 219, 232, 255),
          (0.63, 239, 222, 255),
          (0.70, 255, 217, 235),
          (0.77, 255, 230, 205),
          (0.84, 247, 245, 204),
          (0.91, 218, 247, 227),
          (0.97, 240, 247, 255),
          (1.00, 255, 255, 255),
        ]),
      );

      final pastel = auroraHologramStops(AuroraHologramPreset.pastelDream);
      expect(
        pastel,
        isNot(equals(auroraHologramStops(AuroraHologramPreset.pearl2))),
      );
      expect(
        pastel,
        containsAll(const [
          (0.00, 255, 214, 237),
          (0.28, 214, 207, 255),
          (0.42, 202, 255, 244),
          (0.56, 255, 232, 194),
          (0.70, 255, 174, 220),
        ]),
      );
    },
  );
}
