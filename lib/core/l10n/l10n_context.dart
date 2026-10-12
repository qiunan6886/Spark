import 'package:flutter/widgets.dart';
import 'package:spark/l10n/app_localizations.dart';

/// Shorthand for `L10n.of(context)`, so screens read `context.l10n.navHome`
/// instead of repeating the lookup at every call site.
extension L10nContextX on BuildContext {
  L10n get l10n => L10n.of(this);
}
