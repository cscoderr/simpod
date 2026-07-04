import 'package:args/command_runner.dart';
import 'package:simpod/simpod.dart';

class SimpodCommandRunner extends CommandRunner<void> {
  SimpodCommandRunner()
    : super('simpod', 'Simpod CLI - iOS Simulator Stream and Control daemon') {
    argParser
      ..addFlag(
        'detach',
        negatable: false,
        help:
            'Run the preview server in the background and return (fire & '
            'forget); stop it with --kill',
      )
      ..addFlag(
        'quiet',
        abbr: 'q',
        negatable: false,
        help: 'Suppress human-readable output, JSON only',
      )
      ..addFlag(
        'preview',
        negatable: true,
        defaultsTo: true,
        help: 'Enable the web preview server',
      )
      ..addFlag('version', negatable: false, help: 'Print the tool version')
      ..addFlag(
        'list',
        abbr: 'l',
        negatable: false,
        help: 'List running streams',
      )
      ..addFlag(
        'kill',
        abbr: 'k',
        negatable: false,
        help: 'Kill running stream(s)',
      )
      ..addOption(
        'port',
        abbr: 'p',
        valueHelp: 'port',
        defaultsTo: '5210',
        help: 'Starting port',
      )
      ..addOption(
        'host',
        valueHelp: 'addr',
        help: 'Interface to bind the preview server to',
      )
      ..addOption('device', abbr: 'd', help: 'Target simulator device UDID');

    addCommand(GestureCommand());
    addCommand(TapCommand());
    addCommand(ButtonCommand());
    addCommand(TypeCommand());
    addCommand(RotateCommand());
    addCommand(RotateLeftCommand());
    addCommand(RotateRightCommand());
    addCommand(BootCommand());
    addCommand(ShutdownCommand());
    addCommand(DevicesCommand());
    addCommand(AppearanceCommand());
    addCommand(AccessibilityCommand());
    addCommand(OpenUrlCommand());
    addCommand(LocationCommand());
    addCommand(StatusBarCommand());
    addCommand(PermissionsCommand());
    addCommand(PairCommand());
    addCommand(DescribeCommand());
    addCommand(LogsCommand());
    addCommand(ScreenshotCommand());
    addCommand(BezelCommand());
    addCommand(UpdateCommand());
  }

  @override
  String get usage {
    return '''
Usage: simpod [options] [command] [devices...]
Examples:
  simpod                               Open simulator preview at localhost:5210
  simpod -p 3001                       Preview on a custom port
  simpod --no-preview                  Stream directly to this terminal; no preview UI
  simpod --no-preview "iPhone 16 pro"  Stream a specific device (no preview)
  simpod --detach                      Run the preview server in the background
  simpod --list                        Show all running streams
  simpod --kill                        Stop all streams

Options:
${argParser.usage}

Input commands:
  gesture [options] <json>             Send a touch/pinch step ({"type":"touch","data":{...}})
  tap [options] <x> <y>                Tap at normalized 0..1 coords
  button [options] [name]              Send a hardware button press
                                       (home|app_switcher|lock|side_button|siri)
  type [options] [text...]             Type text (US keyboard only)
  rotate [options] <orientation>       Set device orientation
                                       (portrait|portrait_upside_down|landscape_left|landscape_right)
  rotate-left | rotate-right           Quarter-turn helpers

Device commands:
  devices                              List simulators and their state
  boot <udid|name>                     Boot a simulator + attach a helper session
  shutdown                             Shut down + detach (target with -d)
  appearance [light|dark]              Get or set the appearance
  accessibility [flags]                Get or set accessibility settings;
                                       no flags prints the current values
                                         --text-size increment|decrement|<size>
                                         --[no-]contrast
                                         --[no-]reduce-motion
                                         --[no-]reduce-transparency
                                         --[no-]show-borders
  open-url <url>                       Open a deep link / https URL
  location <lat> <lon>                 Mock the GPS location
  status-bar --battery <n> --time <hh:mm> | --clear
                                       Override or clear the status bar
  permissions <grant|revoke|reset> <service> [bundle]
                                       Manage app privacy permissions
  pair [--reset]                       Show the pairing QR, deep link, and token

Inspection commands:
  describe [--point <x> <y>]           Dump the accessibility tree (JSON)
  logs [--seconds <n>]                 Tail the simulator system log
  screenshot [-o <file>]               Capture a PNG screenshot
  bezel [--no-buttons] [-o <file>]     Render the device bezel/chrome PNG

Maintenance commands:
  update                               Update simpod to the latest version''';
  }
}
