import 'package:flutter/widgets.dart';

abstract class AppRadius {
  /// 4pt — chips, small tags.
  static const double xs = 4;

  /// 8pt — buttons, text fields.
  static const double sm = 8;

  /// 12pt — cards, menus, toolbars.
  static const double md = 12;

  /// 16pt — sidebars, sheets, large surfaces.
  static const double lg = 16;

  /// 24pt — hero containers, modals.
  static const double xlg = 24;

  /// Fully rounded (pills, circular buttons).
  static const double full = 999;

  static BorderRadius all(double r) => BorderRadius.circular(r);

  static const BorderRadius allXs = BorderRadius.all(Radius.circular(xs));
  static const BorderRadius allSm = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius allMd = BorderRadius.all(Radius.circular(md));
  static const BorderRadius allLg = BorderRadius.all(Radius.circular(lg));
}
