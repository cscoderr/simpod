// device_layout.dart

import 'dart:convert';

import 'package:equatable/equatable.dart';

class SimulatorDefinition extends Equatable {
  final List<DeviceButton> buttons;
  final DeviceIdentity identity;
  final DeviceKeyboard keyboard;
  final DeviceScreen screen;

  const SimulatorDefinition({
    required this.buttons,
    required this.identity,
    required this.keyboard,
    required this.screen,
  });

  factory SimulatorDefinition.fromJson(
    Map<String, dynamic> json,
  ) => SimulatorDefinition(
    buttons: (json['buttons'] as List)
        .map((e) => DeviceButton.fromJson(e as Map<String, dynamic>))
        .toList(),
    identity: DeviceIdentity.fromJson(json['identity'] as Map<String, dynamic>),
    keyboard: DeviceKeyboard.fromJson(json['keyboard'] as Map<String, dynamic>),
    screen: DeviceScreen.fromJson(json['screen'] as Map<String, dynamic>),
  );

  factory SimulatorDefinition.fromJsonString(String source) =>
      SimulatorDefinition.fromJson(jsonDecode(source) as Map<String, dynamic>);

  Map<String, dynamic> toJson() => {
    'buttons': buttons.map((e) => e.toJson()).toList(),
    'identity': identity.toJson(),
    'keyboard': keyboard.toJson(),
    'screen': screen.toJson(),
  };

  @override
  String toString() =>
      'DeviceLayout(buttons: $buttons, identity: $identity, keyboard: $keyboard, screen: $screen)';

  @override
  List<Object?> get props => [buttons, identity, keyboard, screen];
}

class DeviceButton extends Equatable {
  final ButtonBox box;
  final ButtonEnvelope envelope;
  final String id;
  final ButtonImages images;
  final ButtonTransform transform;

  /// Z-order relative to the device composite (`"below"` or `"above"`).
  final String z;

  const DeviceButton({
    required this.box,
    required this.envelope,
    required this.id,
    required this.images,
    required this.transform,
    required this.z,
  });

  factory DeviceButton.fromJson(Map<String, dynamic> json) => DeviceButton(
    box: ButtonBox.fromJson(json['box'] as Map<String, dynamic>),
    envelope: ButtonEnvelope.fromJson(json['envelope'] as Map<String, dynamic>),
    id: json['id'] as String,
    images: ButtonImages.fromJson(json['images'] as Map<String, dynamic>),
    transform: ButtonTransform.fromJson(
      json['transform'] as Map<String, dynamic>,
    ),
    z: json['z'] as String,
  );

  Map<String, dynamic> toJson() => {
    'box': box.toJson(),
    'envelope': envelope.toJson(),
    'id': id,
    'images': images.toJson(),
    'transform': transform.toJson(),
    'z': z,
  };

  @override
  String toString() =>
      'DeviceButton(id: $id, z: $z, box: $box, envelope: $envelope, images: $images, transform: $transform)';

  @override
  List<Object?> get props => [box, envelope, id, images, transform, z];
}

class ButtonBox extends Equatable {
  final double heightPct;
  final double leftPct;
  final double topPct;
  final double widthPct;

  const ButtonBox({
    required this.heightPct,
    required this.leftPct,
    required this.topPct,
    required this.widthPct,
  });

  factory ButtonBox.fromJson(Map<String, dynamic> json) => ButtonBox(
    heightPct: (json['heightPct'] as num).toDouble(),
    leftPct: (json['leftPct'] as num).toDouble(),
    topPct: (json['topPct'] as num).toDouble(),
    widthPct: (json['widthPct'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'heightPct': heightPct,
    'leftPct': leftPct,
    'topPct': topPct,
    'widthPct': widthPct,
  };

  @override
  String toString() =>
      'ButtonBox(heightPct: $heightPct, leftPct: $leftPct, topPct: $topPct, widthPct: $widthPct)';

  @override
  List<Object?> get props => [heightPct, leftPct, topPct, widthPct];
}

class ButtonEnvelope {
  final String button;
  final String type;

  const ButtonEnvelope({required this.button, required this.type});

  factory ButtonEnvelope.fromJson(Map<String, dynamic> json) => ButtonEnvelope(
    button: json['button'] as String,
    type: json['type'] as String,
  );

  Map<String, dynamic> toJson() => {'button': button, 'type': type};

  @override
  bool operator ==(Object other) =>
      other is ButtonEnvelope && other.button == button && other.type == type;

  @override
  int get hashCode => Object.hash(button, type);

  @override
  String toString() => 'ButtonEnvelope(button: $button, type: $type)';
}

class ButtonImages {
  final String pressed;
  final String rest;

  const ButtonImages({required this.pressed, required this.rest});

  factory ButtonImages.fromJson(Map<String, dynamic> json) => ButtonImages(
    pressed: json['pressed'] as String,
    rest: json['rest'] as String,
  );

  Map<String, dynamic> toJson() => {'pressed': pressed, 'rest': rest};

  @override
  bool operator ==(Object other) =>
      other is ButtonImages && other.pressed == pressed && other.rest == rest;

  @override
  int get hashCode => Object.hash(pressed, rest);

  @override
  String toString() => 'ButtonImages(pressed: $pressed, rest: $rest)';
}

class ButtonVector extends Equatable {
  final double x;
  final double y;

  const ButtonVector({required this.x, required this.y});

  factory ButtonVector.fromJson(Map<String, dynamic> json) => ButtonVector(
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'x': x, 'y': y};

  @override
  List<Object?> get props => [x, y];

  @override
  String toString() => 'ButtonVector(x: $x, y: $y)';
}

class ButtonTransform extends Equatable {
  final ButtonVector hover;
  final ButtonVector pressed;
  final ButtonVector rest;

  const ButtonTransform({
    required this.hover,
    required this.pressed,
    required this.rest,
  });

  factory ButtonTransform.fromJson(Map<String, dynamic> json) =>
      ButtonTransform(
        hover: ButtonVector.fromJson(json['hover'] as Map<String, dynamic>),
        pressed: ButtonVector.fromJson(json['pressed'] as Map<String, dynamic>),
        rest: ButtonVector.fromJson(json['rest'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
    'hover': hover.toJson(),
    'pressed': pressed.toJson(),
    'rest': rest.toJson(),
  };

  @override
  List<Object?> get props => [hover, pressed, rest];

  @override
  String toString() =>
      'ButtonTransform(hover: $hover, pressed: $pressed, rest: $rest)';
}

class DeviceIdentity {
  final String model;
  final String name;
  final String udid;

  const DeviceIdentity({
    required this.model,
    required this.name,
    required this.udid,
  });

  factory DeviceIdentity.fromJson(Map<String, dynamic> json) => DeviceIdentity(
    model: json['model'] as String,
    name: json['name'] as String,
    udid: json['udid'] as String,
  );

  Map<String, dynamic> toJson() => {'model': model, 'name': name, 'udid': udid};

  @override
  bool operator ==(Object other) =>
      other is DeviceIdentity &&
      other.model == model &&
      other.name == name &&
      other.udid == udid;

  @override
  int get hashCode => Object.hash(model, name, udid);

  @override
  String toString() =>
      'DeviceIdentity(model: $model, name: $name, udid: $udid)';
}

class DeviceKeyboard {
  const DeviceKeyboard();

  factory DeviceKeyboard.fromJson(Map<String, dynamic> json) =>
      const DeviceKeyboard();

  Map<String, dynamic> toJson() => {};

  @override
  bool operator ==(Object other) => other is DeviceKeyboard;

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() => 'DeviceKeyboard()';
}

class DeviceSensorBar extends Equatable {
  final String url;
  final double width;
  final double height;

  const DeviceSensorBar({
    required this.url,
    required this.width,
    required this.height,
  });

  factory DeviceSensorBar.fromJson(Map<String, dynamic> json) =>
      DeviceSensorBar(
        url: json['url'] as String,
        width: (json['width'] as num).toDouble(),
        height: (json['height'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'url': url,
    'width': width,
    'height': height,
  };

  @override
  List<Object?> get props => [url, width, height];

  @override
  String toString() =>
      'DeviceSensorBar(url: $url, width: $width, height: $height)';
}

class DeviceScreen {
  final BezelImage bezelImage;
  final double clipRadius;
  final ScreenRect rect;
  final ScreenViewport viewport;
  final DeviceSensorBar? sensorBar;

  const DeviceScreen({
    required this.bezelImage,
    required this.clipRadius,
    required this.rect,
    required this.viewport,
    this.sensorBar,
  });

  factory DeviceScreen.fromJson(Map<String, dynamic> json) => DeviceScreen(
    bezelImage: BezelImage.fromJson(json['bezelImage'] as Map<String, dynamic>),
    clipRadius: (json['clipRadius'] as num).toDouble(),
    rect: ScreenRect.fromJson(json['rect'] as Map<String, dynamic>),
    viewport: ScreenViewport.fromJson(json['viewport'] as Map<String, dynamic>),
    sensorBar: json['sensorBar'] != null
        ? DeviceSensorBar.fromJson(json['sensorBar'] as Map<String, dynamic>)
        : null,
  );

  Map<String, dynamic> toJson() => {
    'bezelImage': bezelImage.toJson(),
    'clipRadius': clipRadius,
    'rect': rect.toJson(),
    'viewport': viewport.toJson(),
    if (sensorBar != null) 'sensorBar': sensorBar!.toJson(),
  };

  @override
  bool operator ==(Object other) =>
      other is DeviceScreen &&
      other.bezelImage == bezelImage &&
      other.clipRadius == clipRadius &&
      other.rect == rect &&
      other.viewport == viewport &&
      other.sensorBar == sensorBar;

  @override
  int get hashCode =>
      Object.hash(bezelImage, clipRadius, rect, viewport, sensorBar);

  @override
  String toString() =>
      'DeviceScreen(bezelImage: $bezelImage, clipRadius: $clipRadius, rect: $rect, viewport: $viewport, sensorBar: $sensorBar)';
}

class BezelImage {
  /// URL for the bezel without buttons composited in.
  final String bare;

  /// URL for the full bezel (buttons at rest position).
  final String rest;

  const BezelImage({required this.bare, required this.rest});

  factory BezelImage.fromJson(Map<String, dynamic> json) =>
      BezelImage(bare: json['bare'] as String, rest: json['rest'] as String);

  Map<String, dynamic> toJson() => {'bare': bare, 'rest': rest};

  @override
  bool operator ==(Object other) =>
      other is BezelImage && other.bare == bare && other.rest == rest;

  @override
  int get hashCode => Object.hash(bare, rest);

  @override
  String toString() => 'BezelImage(bare: $bare, rest: $rest)';
}

class ScreenRect {
  final double height;
  final double width;
  final double x;
  final double y;

  const ScreenRect({
    required this.height,
    required this.width,
    required this.x,
    required this.y,
  });

  factory ScreenRect.fromJson(Map<String, dynamic> json) => ScreenRect(
    height: (json['height'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {
    'height': height,
    'width': width,
    'x': x,
    'y': y,
  };

  @override
  bool operator ==(Object other) =>
      other is ScreenRect &&
      other.height == height &&
      other.width == width &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(height, width, x, y);

  @override
  String toString() =>
      'ScreenRect(height: $height, width: $width, x: $x, y: $y)';
}

class ScreenViewport {
  final double height;
  final double width;

  const ScreenViewport({required this.height, required this.width});

  factory ScreenViewport.fromJson(Map<String, dynamic> json) => ScreenViewport(
    height: (json['height'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'height': height, 'width': width};

  @override
  bool operator ==(Object other) =>
      other is ScreenViewport && other.height == height && other.width == width;

  @override
  int get hashCode => Object.hash(height, width);

  @override
  String toString() => 'ScreenViewport(height: $height, width: $width)';
}
