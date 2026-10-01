import 'package:flutter/material.dart';

import 'context.dart';

/// An image that switches with the theme.
///
/// ```dart
/// ThemedImage(
///   light: AssetImage('assets/empty_light.png'),
///   dark: AssetImage('assets/empty_dark.png'),
/// );
///
/// // One image, gently dimmed in dark mode so white backgrounds don't glow.
/// ThemedImage.dimmed(image: NetworkImage(url));
/// ```
class ThemedImage extends StatelessWidget {
  /// Shows [light] in light mode and [dark] in dark mode.
  const ThemedImage({
    super.key,
    required this.light,
    required this.dark,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.filterQuality = FilterQuality.medium,
  }) : dim = 0;

  /// Shows [image] in both modes, dimmed by [dim] (0–1) in dark mode.
  const ThemedImage.dimmed({
    super.key,
    required ImageProvider image,
    this.dim = 0.15,
    this.width,
    this.height,
    this.fit,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.excludeFromSemantics = false,
    this.filterQuality = FilterQuality.medium,
  }) : assert(dim >= 0 && dim <= 1),
       light = image,
       dark = image;

  /// The image in light mode.
  final ImageProvider light;

  /// The image in dark mode.
  final ImageProvider dark;

  /// How much to darken the image in dark mode, from 0 to 1.
  final double dim;

  /// See [Image.width].
  final double? width;

  /// See [Image.height].
  final double? height;

  /// See [Image.fit].
  final BoxFit? fit;

  /// See [Image.alignment].
  final AlignmentGeometry alignment;

  /// See [Image.semanticLabel].
  final String? semanticLabel;

  /// See [Image.excludeFromSemantics].
  final bool excludeFromSemantics;

  /// See [Image.filterQuality].
  final FilterQuality filterQuality;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final dimmed = dark && dim > 0;
    return Image(
      image: dark ? this.dark : light,
      width: width,
      height: height,
      fit: fit,
      alignment: alignment,
      semanticLabel: semanticLabel,
      excludeFromSemantics: excludeFromSemantics,
      filterQuality: filterQuality,
      // Keep the old image up while the new one loads, so switching never
      // flashes empty.
      gaplessPlayback: true,
      color: dimmed ? Colors.black.withValues(alpha: dim) : null,
      colorBlendMode: dimmed ? BlendMode.srcATop : null,
    );
  }
}
