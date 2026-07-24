# V16.3 Review Decision

Decision: `ACCEPTED_LEARNING_BRANCH`

This run is accepted as a Calculus-1 learning branch derived from the canonical
SSOT. It does not replace the V15 active continuation anchor.

## Accepted mathematical structure

```text
Formula ID: f002_derivative_linearity
Human form: d/dx[a f(x)+b g(x)] = a f'(x)+b g'(x)
Structural encoding: D(af+bg)=aDf+bDg
Layout: two readable rows with compact glyphs and minimal relation weight
```

## Canonical provenance

```text
SSOT:
/Users/yehoshua/MATLAB-Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5

SHA-256:
5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013

Dataset:
/n_5_composite_field_1000x1000/data
```

## Validation result

All 12 expected rows were produced with no missing numeric metrics.

Selected balance point:

```text
anchor: 3
method: m03_projection_structural
temporal_stability_mean: 0.993139
structure_preservation: 0.976588
formula_region_motion_ratio: 2.983800
projection_alignment_mean: 0.548110
projected_motion_gain: 1.635451
mask_density: 0.124924
```

Relative to the original single-row V16 candidate, the selected V16.3 result
improves projection alignment by approximately 16.3% while preserving the
readable two-row structure. Its projected motion gain is approximately 9.1%
lower and its mask density approximately 20.5% higher than the original V16
candidate. This is an accepted learning tradeoff, not a universal optimum.

## Interpretation boundary

The output demonstrates a controlled derived embedding of derivative-linearity
structure into temporal carriers computed from the verified SSOT field. It is
not evidence that the human formula was already present in the SSOT.

## Scope decision

- V15 remains the active continuation anchor.
- V16.3 is an accepted Calculus-1 learning branch.
- V16, V16.1, and V16.2 remain preserved candidate history.
- No source or prior output was deleted, moved, renamed, or overwritten.
