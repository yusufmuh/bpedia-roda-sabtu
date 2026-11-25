import 'package:flutter/services.dart';

/// Isyarat suara game. Host yang memutar suaranya; kit hanya memancarkan.
enum GameCue { tap, claim, bonus, spinStart, tick, winKelopak, winProduct, missionDone, softError }

/// Penerima isyarat dari host (mis. `SoundService.play`).
typedef GameCueSink = void Function(GameCue cue);

/// Getar bawaan tiap isyarat.
abstract final class GameHaptics {
  static void forCue(GameCue cue) {
    switch (cue) {
      case GameCue.tap:
      case GameCue.tick:
        HapticFeedback.selectionClick();
      case GameCue.claim:
      case GameCue.spinStart:
        HapticFeedback.lightImpact();
      case GameCue.winKelopak:
      case GameCue.missionDone:
        HapticFeedback.mediumImpact();
      case GameCue.bonus:
      case GameCue.winProduct:
        HapticFeedback.heavyImpact();
      case GameCue.softError:
        HapticFeedback.vibrate();
    }
  }
}

/// Memancarkan [cue] ke [sink] (bila ada) dan memicu getar bawaannya.
void emitCue(GameCueSink? sink, GameCue cue, {bool haptic = true}) {
  sink?.call(cue);
  if (haptic) GameHaptics.forCue(cue);
}
