# Changelog

## 0.1.0-alpha.2 - 2026-08-10

- Repairs the provider handshake when the real launcher does not retain the
  alpha.1 initialization-time registration.
- Verifies registration after `mods.loaded` and restores it at
  `battle.started` if necessary.
- Keeps Widescreen as the sole presenter and adds no battle/render hook.

## 0.1.0-alpha.1 - 2026-08-10

- First release.
- Adds immutable highlighted-move snapshot API v1.
- Registers with Gen1 Widescreen UI Battle Move Inspector API v1.
- Covers live type, PP, base/status/fixed/special power, accuracy, type-chart
  multiplier, STAB, and disabled state without drawing or changing mechanics.
