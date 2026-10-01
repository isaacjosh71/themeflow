// Older packages still read these deprecated ColorScheme roles, and
// ColorScheme.copyWith would otherwise freeze them at their old values.
// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

/// Returns [result] with `background`, `onBackground` and `surfaceVariant`
/// carried over from [source] the same way as the other roles: matching the
/// [from] scheme means taking the [to] value, anything else goes through
/// [map].
ColorScheme carryLegacyRoles(
  ColorScheme result, {
  required ColorScheme source,
  required ColorScheme from,
  required ColorScheme to,
  required Color Function(Color color, {required bool content}) map,
}) => result.copyWith(
  background: source.background == from.background
      ? to.background
      : map(source.background, content: false),
  onBackground: source.onBackground == from.onBackground
      ? to.onBackground
      : map(source.onBackground, content: true),
  surfaceVariant: source.surfaceVariant == from.surfaceVariant
      ? to.surfaceVariant
      : map(source.surfaceVariant, content: false),
);
