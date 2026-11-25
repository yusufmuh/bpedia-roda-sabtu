import 'package:flutter/painting.dart';

import 'kit/sprite_sheet.dart';
import 'spin_engine.dart';

const String _package = 'roda_sabtu';

/// Seni 3D, wajah dan pose Bipy, serta stiker milik modul (dirujuk dengan
/// `package:` supaya bisa dipakai host mana pun).
abstract final class WheelArt {
  /// Koin Kelopak 3D tunggal.
  static const AssetImage coin = AssetImage(
    'assets/art/coin.webp',
    package: _package,
  );

  /// Satu koin.
  static const AssetImage coinStack1 = AssetImage(
    'assets/art/coin_stack_1.webp',
    package: _package,
  );

  /// Tumpukan tiga koin.
  static const AssetImage coinStack3 = AssetImage(
    'assets/art/coin_stack_3.webp',
    package: _package,
  );

  /// Dua tumpukan koin.
  static const AssetImage coinStack5 = AssetImage(
    'assets/art/coin_stack_5.webp',
    package: _package,
  );

  /// Tiga tumpukan koin.
  static const AssetImage coinStack10 = AssetImage(
    'assets/art/coin_stack_10.webp',
    package: _package,
  );

  /// Kotak hadiah tertutup (hadiah produk).
  static const AssetImage gift = AssetImage(
    'assets/art/gift_closed.webp',
    package: _package,
  );

  /// Podium pink-emas untuk lembar hasil.
  static const AssetImage podium = AssetImage(
    'assets/art/podium.webp',
    package: _package,
  );

  /// Wajah Bipy tersenyum (poros roda).
  static const AssetImage faceSmile = AssetImage(
    'assets/bipy/bipy_wajah_senyum.webp',
    package: _package,
  );

  /// Wajah Bipy berkedip (poros roda saat menang).
  static const AssetImage faceWink = AssetImage(
    'assets/bipy/bipy_wajah_wink.webp',
    package: _package,
  );

  /// Bipy melompat gembira (menang Kelopak besar).
  static const AssetImage poseCelebrate = AssetImage(
    'assets/bipy/bipy_pose_rayakan.webp',
    package: _package,
  );

  /// Bipy menyemangati ("sampai Sabtu depan", hadiah kecil).
  static const AssetImage poseCheer = AssetImage(
    'assets/bipy/bipy_pose_semangat.webp',
    package: _package,
  );

  /// Bipy serius, tangan siap (saat roda berputar).
  static const AssetImage poseFocus = AssetImage(
    'assets/bipy/bipy_pose_fokus.webp',
    package: _package,
  );

  /// Stiker bintang.
  static const AssetImage stickerStar = AssetImage(
    'assets/fx/stiker_bintang.webp',
    package: _package,
  );

  /// Stiker kilau empat sudut.
  static const AssetImage stickerSparkle = AssetImage(
    'assets/fx/stiker_kilau.webp',
    package: _package,
  );

  /// Stiker hati.
  static const AssetImage stickerHeart = AssetImage(
    'assets/fx/stiker_hati.webp',
    package: _package,
  );

  /// Stiker bibir.
  static const AssetImage stickerLips = AssetImage(
    'assets/fx/stiker_bibir.webp',
    package: _package,
  );

  /// Stiker kupu-kupu.
  static const AssetImage stickerButterfly = AssetImage(
    'assets/fx/stiker_kupu.webp',
    package: _package,
  );

  /// Seni hadiah [prize]: kotak hadiah untuk produk, tumpukan koin yang makin
  /// tinggi untuk Kelopak yang makin banyak.
  static AssetImage forPrize(SpinPrize prize) =>
      forReward(prize.kind, prize.kelopak);

  /// Seni hadiah berjenis [kind] senilai [kelopak].
  static AssetImage forReward(PrizeKind kind, int kelopak) {
    if (kind == PrizeKind.product) return gift;
    if (kelopak >= 10) return coinStack10;
    if (kelopak >= 5) return coinStack5;
    if (kelopak >= 3) return coinStack3;
    return coinStack1;
  }
}

/// Lembar sprite Bipy milik modul (12 fps, urut baris).
abstract final class WheelSprites {
  /// Bipy menari riang (menang produk).
  static const SpriteSheetSpec dance = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_menari.webp',
    package: _package,
    columns: 7,
    rows: 6,
    frameCount: 42,
    frameSize: Size(236, 340),
  );

  /// Bipy mengintip dari tas dengan senyum (menunggu Sabtu).
  static const SpriteSheetSpec peek = SpriteSheetSpec(
    asset: 'assets/bipy/bipy_tas.webp',
    package: _package,
    columns: 6,
    rows: 3,
    frameCount: 18,
    frameSize: Size(264, 320),
    loopMode: SpriteLoopMode.pingPong,
  );
}
