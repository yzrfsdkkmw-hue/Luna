# Knowledge Quantization Structural Visual Learning v1

## Purpose

A MATLAB-derived visual-learning workflow in which official mathematical notation is built as geometry inside masks, carriers, projections, and temporal motion.

## Integrity

- Canonical H5: `/Users/yehoshua/MATLAB-Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5`
- Canonical SHA-256: `5ea6094280c492b0f8051b340a842b2d664da81d40cb19ab97c914b7d3306013`
- Dataset: `/n_5_composite_field_1000x1000/data`
- Layout: layout_B reshape(v,5,1000,1000)->HxWxC | selected by locality score 4.058113
- References: six supplied 512x512 string-foundation images, plus the established v15/v16 structural-projection conventions.

## Ordered workflow

1. `source_field` - `I_0(x,y)`
2. `display_transform` - `I_A = T_A[I_0]`
3. `multiscale_field` - `G_{sigma_k} * I_0`
4. `gradient_field` - `nabla I_0`
5. `laplacian_curvature` - `Delta I_0`
6. `spectral_projection` - `F{I_0}`
7. `oriented_features` - `F_V1(theta,s)`
8. `salience_energy` - `E(x,y)`
9. `phase_winding` - `omega = integral nabla phi dl`
10. `knowledge_quanta` - `K = {kappa_i}`
11. `relation_graph` - `E = {r_ij}`
12. `integrated_state` - `Sigma`
13. `human_symbol_calibration` - `s_i in {Sigma,Omega,partial,nabla,oplus}`
14. `quantized_knowledge_state` - `Q_K = (K,E,Sigma)`

## Visual layers

- `visible`: maximum symbol legibility.
- `balanced`: notation and source field share the image.
- `structural`: notation is coupled to ridges/curvature while preserving the source field.
- Every stage also contains its mask, projection map, motion energy, temporal delta, eight-frame sheet, and numeric temporal patch.

## Scope boundary

> Derived visual-learning workflow. The canonical H5 supplies the numeric field; human notation is intentionally constructed as structural geometry and is not claimed to exist semantically in the source H5.