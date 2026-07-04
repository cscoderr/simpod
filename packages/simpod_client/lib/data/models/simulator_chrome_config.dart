import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';

class SimulatorChromeConfig extends Equatable {
  const SimulatorChromeConfig({
    required this.buttons,
    required this.chromeCornerRadius,
    required this.chromeHeight,
    required this.chromeWidth,
    required this.chromeX,
    required this.chromeY,
    required this.contentHeight,
    required this.contentWidth,
    required this.contentX,
    required this.contentY,
    required this.cornerRadius,
    required this.hasScreenMask,
    required this.screenHeight,
    required this.screenWidth,
    required this.screenX,
    required this.screenY,
    required this.totalHeight,
    required this.totalWidth,
    required this.bezelImage,
  });

  factory SimulatorChromeConfig.fromJson(Map<String, dynamic> json) {
    return SimulatorChromeConfig(
      buttons:
          (json['buttons'] as List<dynamic>?)
              ?.map(
                (e) =>
                    SimulatorChromeButton.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      chromeCornerRadius: json['chromeCornerRadius'] as int? ?? 0,
      chromeHeight: json['chromeHeight'] as int? ?? 0,
      chromeWidth: json['chromeWidth'] as int? ?? 0,
      chromeX: json['chromeX'] as int? ?? 0,
      chromeY: json['chromeY'] as int? ?? 0,
      contentHeight: json['contentHeight'] as int? ?? 0,
      contentWidth: json['contentWidth'] as int? ?? 0,
      contentX: json['contentX'] as int? ?? 0,
      contentY: json['contentY'] as int? ?? 0,
      cornerRadius: json['cornerRadius'] as int? ?? 0,
      hasScreenMask: json['hasScreenMask'] as bool? ?? false,
      screenHeight: (json['screenHeight'] as num?)?.toDouble() ?? 0,
      screenWidth: (json['screenWidth'] as num?)?.toDouble() ?? 0,
      screenX: (json['screenX'] as num?)?.toDouble() ?? 0,
      screenY: (json['screenY'] as num?)?.toDouble() ?? 0,
      totalHeight: (json['totalHeight'] as num?)?.toDouble() ?? 0,
      totalWidth: (json['totalWidth'] as num?)?.toDouble() ?? 0,
      bezelImage: BezelImage.fromJson(json['bezelImage']),
    );
  }

  final List<SimulatorChromeButton> buttons;
  final int chromeCornerRadius;
  final int chromeHeight;
  final int chromeWidth;
  final int chromeX;
  final int chromeY;
  final int contentHeight;
  final int contentWidth;
  final int contentX;
  final int contentY;
  final int cornerRadius;
  final bool hasScreenMask;
  final double screenHeight;
  final double screenWidth;
  final double screenX;
  final double screenY;
  final double totalHeight;
  final double totalWidth;
  final BezelImage bezelImage;

  @override
  List<Object?> get props => [
    buttons,
    chromeCornerRadius,
    chromeHeight,
    chromeWidth,
    chromeX,
    chromeY,
    contentHeight,
    contentWidth,
    contentX,
    contentY,
    cornerRadius,
    hasScreenMask,
    screenHeight,
    screenWidth,
    screenX,
    screenY,
    totalHeight,
    totalWidth,
    bezelImage,
  ];
}

class BezelImage extends Equatable {
  /// URL for the bezel without buttons composited in.
  final String bare;

  /// URL for the full bezel (buttons at rest position).
  final String rest;

  const BezelImage({required this.bare, required this.rest});

  factory BezelImage.fromJson(Map<String, dynamic> json) =>
      BezelImage(bare: json['bare'] as String, rest: json['rest'] as String);

  @override
  List<Object?> get props => [bare, rest];
}

class SimulatorChromeButton extends Equatable {
  const SimulatorChromeButton({
    required this.align,
    required this.anchor,
    required this.height,
    required this.label,
    required this.name,
    required this.images,
    required this.normalOffset,
    required this.onTop,
    required this.rolloverOffset,
    required this.type,
    required this.usage,
    required this.usagePage,
    required this.width,
    required this.x,
    required this.y,
  });

  factory SimulatorChromeButton.fromJson(Map<String, dynamic> json) {
    return SimulatorChromeButton(
      align: json['align'] as String? ?? '',
      anchor: json['anchor'] as String? ?? '',
      label: json['label'] as String? ?? '',
      name: json['name'] as String? ?? '',
      images: SimulatorChromeButtonImages.fromJson(
        json['images'] as Map<String, dynamic>,
      ),
      normalOffset: json['normalOffset'] != null
          ? Offset(
              (json['normalOffset']['x'] as num?)?.toDouble() ?? 0,
              (json['normalOffset']['y'] as num?)?.toDouble() ?? 0,
            )
          : .zero,
      onTop: json['onTop'] as bool? ?? false,
      rolloverOffset: json['rolloverOffset'] != null
          ? Offset(
              (json['rolloverOffset']['x'] as num?)?.toDouble() ?? 0,
              (json['rolloverOffset']['y'] as num?)?.toDouble() ?? 0,
            )
          : .zero,
      type: json['type'] as String? ?? '',
      usage: json['usage'] as int? ?? 0,
      usagePage: json['usagePage'] as int? ?? 0,
      width: (json['width'] as num?)?.toDouble() ?? 0,
      height: (json['height'] as num?)?.toDouble() ?? 0,
      x: (json['x'] as num?)?.toDouble() ?? 0,
      y: (json['y'] as num?)?.toDouble() ?? 0,
    );
  }

  final String align;
  final String anchor;
  final String label;
  final String name;
  final SimulatorChromeButtonImages images;
  final Offset normalOffset;
  final bool onTop;
  final Offset rolloverOffset;
  final String type;
  final int usage;
  final int usagePage;
  final double width;
  final double height;
  final double x;
  final double y;

  @override
  List<Object?> get props => [
    align,
    anchor,
    height,
    label,
    name,
    images,
    normalOffset,
    onTop,
    rolloverOffset,
    type,
    usage,
    usagePage,
    width,
    x,
    y,
  ];
}

class SimulatorChromeButtonImages extends Equatable {
  final String pressed;
  final String rest;

  const SimulatorChromeButtonImages({
    required this.pressed,
    required this.rest,
  });

  factory SimulatorChromeButtonImages.fromJson(Map<String, dynamic> json) =>
      SimulatorChromeButtonImages(
        pressed: json['pressed'] as String,
        rest: json['rest'] as String,
      );

  @override
  List<Object?> get props => [pressed, rest];
}
