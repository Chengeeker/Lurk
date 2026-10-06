import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HapticFeedbackUtil {
  HapticFeedbackUtil._();

  static bool isEnabled = true;
  static int _lastTriggerTime = 0;
  static const int _cooldownMs = 250;
  static const int _scrollTickCooldownMs = 12;

  static bool _canTrigger({int cooldownMs = _cooldownMs}) {
    if (!isEnabled) return false;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTriggerTime < cooldownMs) return false;
    _lastTriggerTime = now;
    return true;
  }

  static void light() {
    if (_canTrigger()) HapticFeedback.lightImpact();
  }

  static void selection() {
    if (_canTrigger()) HapticFeedback.selectionClick();
  }

  static void selectionTick() {
    if (_canTrigger(cooldownMs: _scrollTickCooldownMs)) {
      HapticFeedback.selectionClick();
    }
  }

  static void medium() {
    if (_canTrigger()) HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (_canTrigger()) HapticFeedback.heavyImpact();
  }
}

class HapticSplashFactory extends InteractiveInkFeatureFactory {
  final InteractiveInkFeatureFactory delegate;

  const HapticSplashFactory({this.delegate = InkSplash.splashFactory});

  @override
  InteractiveInkFeature create({
    required MaterialInkController controller,
    required RenderBox referenceBox,
    required Offset position,
    required Color color,
    required TextDirection textDirection,
    bool containedInkWell = false,
    RectCallback? rectCallback,
    BorderRadius? borderRadius,
    ShapeBorder? customBorder,
    double? radius,
    VoidCallback? onRemoved,
  }) {
    HapticFeedbackUtil.light();

    return delegate.create(
      controller: controller,
      referenceBox: referenceBox,
      position: position,
      color: color,
      textDirection: textDirection,
      containedInkWell: containedInkWell,
      rectCallback: rectCallback,
      borderRadius: borderRadius,
      customBorder: customBorder,
      radius: radius,
      onRemoved: onRemoved,
    );
  }
}
