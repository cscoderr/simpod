/// Boolean accessibility toggles shared by the CLI, the HTTP API
/// (`/api/device/<udid>/accessibility/<commandName>`), and the web client.
/// They have no `simctl ui` verb — the CLI writes [defaultsKey] in the
/// simulator's com.apple.Accessibility preferences domain.
enum AccessibilitySetting {
  reduceMotion('reduce-motion', 'Reduce Motion', 'ReduceMotionEnabled'),
  reduceTransparency(
    'reduce-transparency',
    'Reduce Transparency',
    'EnhancedBackgroundContrastEnabled',
  ),
  showBorders('show-borders', 'Show Borders', 'ButtonShapesEnabled');

  const AccessibilitySetting(this.commandName, this.label, this.defaultsKey);

  final String commandName;
  final String label;
  final String defaultsKey;

  static AccessibilitySetting? fromCommandName(String name) {
    for (final setting in values) {
      if (setting.commandName == name) return setting;
    }
    return null;
  }
}
