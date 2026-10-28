import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:lurk/features/home/presentation/main_scaffold.dart';

void main() {
  const base = LiquidGlassSettings(
    glassColor: Color(0x66000000),
    bodyMode: GlassBodyMode.clear,
    thickness: 10,
    blur: 2,
    refractiveIndex: 1.19,
    rimLight: 0.2,
  );

  test(
    'light mode adds the white glass treatment and preserves other settings',
    () {
      final light = lurkLiquidGlassSettingsForBrightness(
        Brightness.light,
        base,
      );
      expect(light.glassColor, const Color(0xF0FFFFFF));
      expect(light.rimLight, 1);
      expect(light.bodyMode, base.bodyMode);
      expect(light.thickness, base.thickness);
      expect(light.blur, base.blur);
      expect(light.refractiveIndex, base.refractiveIndex);
    },
  );

  test('dark mode keeps its existing glass settings', () {
    expect(
      lurkLiquidGlassSettingsForBrightness(Brightness.dark, base),
      same(base),
    );
  });
}
