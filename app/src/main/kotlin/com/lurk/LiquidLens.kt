package com.lurk

import androidx.compose.ui.geometry.Offset
import kotlin.math.*

// Quarter-circle bevel and Snell lens from liquid_glass_widgets (see third_party license).
internal fun lensDisplacement(x: Float, y: Float, width: Float, height: Float, thickness: Float, index: Float): Offset {
    val radius = min(width, height) / 2f
    val qx = x - x.coerceIn(radius, width - radius)
    val qy = y - height / 2f
    val length = hypot(qx, qy)
    val cosine = ((thickness + length - radius) / thickness).coerceIn(0f, 1f)
    if (cosine == 0f || length == 0f) return Offset.Zero
    val normalZ = sqrt(1f - cosine * cosine)
    val eta = 1f / index
    val refractZ = sqrt(1f - eta * eta * cosine * cosine)
    val reach = ((refractZ - eta * normalZ) * cosine * (thickness * normalZ + thickness * 8f) / refractZ).coerceAtMost(radius)
    return Offset(-qx / length * reach, -qy / length * reach)
}

internal data class LiquidMaterial(
    val thickness: Float = 10f,
    val index: Float = 1.19f,
    val dispersion: Float = .008f,
    val tint: androidx.compose.ui.graphics.Color = androidx.compose.ui.graphics.Color.Transparent,
    val light: Float = .25f,
    val saturation: Float = 1.5f,
    val rimShade: Float = 0f,
    val rimLight: Float = 0f,
    val visibility: Float = 1f,
    val pinch: Float = 0f,
)

// The active clear/spherical branches of liquid_glass_widgets 1.13.0, in local pixel coordinates.
internal const val LIQUID_LENS_SHADER = """
    uniform shader image;
    uniform float2 resolution;
    uniform float inset;
    uniform float thickness;
    uniform float refractiveIndex;
    uniform float dispersion;
    uniform float4 tint;
    uniform float lightIntensity;
    uniform float saturation;
    uniform float dprScale;
    uniform float rimShade;
    uniform float rimLight;
    uniform float pinch;
    uniform float2 captureSize;
    const float3 luma = float3(0.2126, 0.7152, 0.0722);
    const float2 lightDir = float2(-0.70710678, -0.70710678);
    half4 main(float2 pixel) {
        float2 p = pixel - inset;
        float radius = min(resolution.x, resolution.y) * 0.5;
        float2 q = p - float2(clamp(p.x, radius, resolution.x - radius), resolution.y * 0.5);
        float d = length(q);
        float cosine = clamp((thickness + d - radius) / max(thickness, 0.001), 0.0, 1.0);
        float normalZ = sqrt(max(0.0, 1.0 - cosine * cosine));
        float2 normalXY = q / max(d, 0.001) * cosine;
        float3 ray = refract(float3(0.0, 0.0, -1.0), float3(normalXY, normalZ), 1.0 / refractiveIndex);
        float2 shift = ray.xy * (thickness * normalZ + thickness * 8.0) / max(abs(ray.z), 0.001);
        shift *= min(1.0, radius / max(length(shift), 0.001));
        float rimDist = thickness * (1.0 - cosine);
        float scale = max(0.1, dprScale);
        float hairline = (1.0 - smoothstep(0.75 * scale, 2.0 * scale, rimDist)) * (1.0 - step(0.999, normalZ)) * step(0.001, rimShade);
        float2 rimN = normalXY / max(length(normalXY), 0.0001);
        shift = mix(shift, rimN * (2.5 * scale), hairline);
        float2 centered = p / resolution - 0.5;
        float2 square = centered * centered * 4.0;
        float ramp = smoothstep(0.0, 1.0, sqrt(sqrt(dot(square, square))));
        float coverage = clamp((radius - d) / 2.0, 0.0, 1.0);
        float2 sampleAt = pixel + centered * ramp * pinch * 0.025 * captureSize * coverage;
        float4 refracted = float4(image.eval(sampleAt + shift));
        if (dispersion >= 0.01 && dot(normalXY, normalXY) >= 0.0001) {
            refracted.r = image.eval(sampleAt + shift * (1.0 + dispersion * 0.5)).r;
            refracted.b = image.eval(sampleAt + shift * (1.0 - dispersion * 0.5)).b;
        }
        if (refracted.a > 0.001) refracted.rgb /= refracted.a;
        float3 color = mix(refracted.rgb, tint.rgb, tint.a * (1.0 - hairline));
        float adaptiveStrength = mix(1.2, 0.8, dot(refracted.rgb, luma));
        color = clamp(mix(float3(dot(color, luma)), color, mix(saturation * adaptiveStrength, 1.0, hairline)), 0.0, 1.0);
        float thicknessScale = clamp(40.0 * scale / max(thickness, 1.0), 1.0, 4.0);
        float edgeFactor = 1.0 - smoothstep(0.0, mix(0.8, 0.5, 1.0 / thicknessScale), normalZ);
        float mainLight = max(0.0, dot(rimN, lightDir));
        float oppositeLight = max(0.0, dot(rimN, -lightDir));
        float influence = mainLight + oppositeLight * 0.8;
        float brightnessRaw = influence * sqrt(influence) * lightIntensity * 3.0 * edgeFactor * thicknessScale * 0.8;
        float lum = dot(refracted.rgb, luma);
        float sat = max(max(refracted.r, refracted.g), refracted.b) * 2.5;
        float lumScaled = lum * 2.5;
        float3 highlight = mix(float3(1.0), refracted.rgb / max(lum, 0.001), lumScaled / (1.0 + lumScaled) * sat / (1.0 + sat));
        color = mix(color, highlight, brightnessRaw / (1.0 + brightnessRaw));
        color = clamp(color + float3((1.0 - normalZ) * edgeFactor * 0.12), 0.0, 1.0);
        float along = dot(rimN, lightDir);
        float lit = max(along, 0.0);
        float opp = max(-along, 0.0);
        float depth = max(0.0, rimDist - 2.25 * scale) / scale;
        float rimGlow = rimLight * (lit * lit * lit + 0.85 * opp * opp * opp) * pow(1.0 - clamp(dot(color, luma), 0.0, 1.0), 0.3)
            * (0.175 * exp(-depth / 1.5) + 0.035 * exp(-depth / 8.0)) * (1.0 - hairline);
        color = clamp(color + float3(rimGlow), 0.0, 1.0);
        float across = pow(max(1.0 - along * along, 0.0), 1.75);
        color = max(color - float3(rimShade * 0.314 * mix(0.2, 1.0, across) * hairline), 0.0);
        return half4(color * refracted.a, refracted.a);
    }
"""

@androidx.annotation.RequiresApi(33)
internal fun configureLiquidShader(shader: android.graphics.RuntimeShader, size: androidx.compose.ui.geometry.Size, inset: Float, density: Float, material: LiquidMaterial) {
    val visibility = material.visibility.coerceIn(0f, 1f)
    shader.setFloatUniform("resolution", size.width, size.height)
    shader.setFloatUniform("inset", inset)
    shader.setFloatUniform("thickness", (material.thickness * visibility * density / 3f).coerceAtLeast(.001f))
    shader.setFloatUniform("refractiveIndex", 1f + (material.index - 1f) * visibility)
    shader.setFloatUniform("dispersion", material.dispersion * visibility)
    shader.setFloatUniform("tint", material.tint.red, material.tint.green, material.tint.blue, material.tint.alpha * visibility)
    shader.setFloatUniform("lightIntensity", material.light * visibility)
    shader.setFloatUniform("saturation", 1f + (material.saturation - 1f) * visibility)
    shader.setFloatUniform("dprScale", density / 3f)
    shader.setFloatUniform("rimShade", material.rimShade * visibility)
    shader.setFloatUniform("rimLight", material.rimLight * visibility)
    shader.setFloatUniform("pinch", material.pinch)
    shader.setFloatUniform("captureSize", size.width + inset * 2f, size.height + inset * 2f)
}

// Older Android GPUs reuse one offscreen control texture with a bounded, cached affine mesh.
internal class LensTriangle(val clip: android.graphics.Path, val transform: android.graphics.Matrix)
internal fun lensMesh(width: Float, height: Float, thickness: Float, index: Float, inset: Float, step: Float): List<LensTriangle> {
    val radius = min(width, height) / 2f
    fun axis(extent: Float, edge: Float): List<Float> {
        val count = ceil(edge / step).toInt().coerceAtLeast(1)
        return ((0..count).map { edge * it / count } + (0..count).map { extent - edge * it / count }).distinct().sorted()
    }
    val xs = axis(width, radius)
    val ys = axis(height, radius)
    val result = ArrayList<LensTriangle>()
    fun triangle(a: Offset, b: Offset, c: Offset) {
        val points = listOf(a, b, c)
        val destination = points.flatMap { listOf(it.x, it.y) }.toFloatArray()
        val source = points.flatMap {
            val shift = lensDisplacement(it.x, it.y, width, height, thickness, index)
            listOf(it.x + shift.x + inset, it.y + shift.y + inset)
        }.toFloatArray()
        val transform = android.graphics.Matrix()
        if (transform.setPolyToPoly(source, 0, destination, 0, 3)) {
            val path = android.graphics.Path().apply { moveTo(a.x, a.y); lineTo(b.x, b.y); lineTo(c.x, c.y); close() }
            result.add(LensTriangle(path, transform))
        }
    }
    for (y in 0 until ys.lastIndex) for (x in 0 until xs.lastIndex) {
        val a = Offset(xs[x], ys[y]); val b = Offset(xs[x + 1], ys[y])
        val c = Offset(xs[x + 1], ys[y + 1]); val d = Offset(xs[x], ys[y + 1])
        triangle(a, b, c); triangle(a, c, d)
    }
    return result
}

// Original non-liquid gallery button shader (gallery_glass_button.frag).
internal const val GALLERY_BUTTON_SHADER = """
    uniform shader image;
    uniform float2 resolution;
    uniform float inset;
    half4 main(float2 p) {
        float2 position = p - inset;
        float2 radial = position - resolution * 0.5;
        float radius = min(resolution.x, resolution.y) * 0.5;
        float r = clamp(length(radial) / radius, 0.0, 0.98);
        float slope = (1.4 / radius) * r / sqrt(max(1.0 - r * r, 0.04));
        float incidence = atan(slope);
        float transmission = asin(clamp(sin(incidence) / 1.52, 0.0, 0.99));
        float shift = clamp((incidence - transmission) * 8.0, 0.0, 0.45) * smoothstep(0.08, 0.42, r);
        float2 sampleAt = clamp(position + radial / max(length(radial), 0.001) * shift, resolution * 0.001, resolution * 0.999);
        return image.eval(sampleAt + inset);
    }
"""
