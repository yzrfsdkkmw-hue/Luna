# System Lawfulness Anchor V1

## Status

`HYPOTHESIS_TO_TEST` — not a conclusion.

## Door-knock protocol

We do not break, force, or invent structure.

We define variables, test lawful equations, measure errors, and only then continue.

## Chronological mathematical chain

01. **Algebra: combining like terms**  
    `3x + 4x + 7 + 2x - 5 = 9x + 2`  
    Meaning: Same-type objects may be collected  
    Status: `ANCHOR`

02. **Algebra: distributive law**  
    `5(x + 2) + 3x - 4 = 8x + 6`  
    Meaning: A rule expands structure without changing value  
    Status: `ANCHOR`

03. **Algebra: coefficient extraction**  
    `a*x + b*x = (a+b)*x`  
    Meaning: Coefficient is the scalar weight of a direction  
    Status: `ANCHOR`

04. **Vector: dot product**  
    `dot(v,u) = sum(v_i*u_i)`  
    Meaning: Dot product measures directional agreement  
    Status: `ANCHOR`

05. **Vector: projection coefficient**  
    `coef = dot(v,u)/dot(u,u)`  
    Meaning: Coefficient measures how much v lives in direction u  
    Status: `ANCHOR`

06. **Vector: projected vector**  
    `proj_u(v) = coef*u`  
    Meaning: Projection is the shadow of v on u  
    Status: `ANCHOR`

07. **Vector: residual / leftover**  
    `residual = v - proj_u(v), and dot(residual,u)=0`  
    Meaning: Residual checks whether projection was mathematically clean  
    Status: `CHECK`

08. **Vector field**  
    `F(x,y) = [F1(x,y), F2(x,y)]`  
    Meaning: A vector is attached to every point  
    Status: `MODEL_OBJECT`

09. **Path / curve**  
    `gamma(t) = [x(t), y(t)]`  
    Meaning: A path selects points inside the field  
    Status: `MODEL_OBJECT`

10. **Velocity / tangent**  
    `u(t) = gamma_prime(t)`  
    Meaning: Velocity gives the local movement direction  
    Status: `MODEL_OBJECT`

11. **Metric speed squared**  
    `speed2(t) = dot(u(t),u(t)) under Euclidean metric`  
    Meaning: Speed squared is the metric length of movement  
    Status: `MEASURE`

12. **Hypothesis candidate**  
    `shadow_norm2(F,u) ?= speed2`  
    Meaning: The proposed sentence becomes measurable  
    Status: `HYPOTHESIS_TO_TEST`

13. **Action rule**  
    `Only continue if variables, dimensions, error, and counterexample are checked`  
    Meaning: No action without MATLAB anchor  
    Status: `GATEKEEPER`

## Projection anchor

Given vector `v` and target direction `u`:

```text
coef = dot(v,u) / dot(u,u)
proj_u(v) = coef * u
residual = v - proj_u(v)
dot(residual,u) should be approximately 0
```

## Proposed sentence

> Shadow of vector in vector field = geodesic speed squared

This sentence is split into measurable candidates:

1. `coef == speed2`
2. `norm(proj_u(F))^2 == speed2`
3. `signed_component(F along unit tangent)^2 == speed2`

## Interpretation rule

- If only candidate 1 passes: unusual; inspect units.
- If candidate 2 or 3 passes: projection-speed compatibility exists.
- If curvature/geodesic check fails: do not call it geodesic yet.
- If counterexample fails: the rule is conditional, not universal.

## Result files

- `3333_law_chain.csv`
- `4444_projection_tests.csv`
- `2222_hypothesis_metrics.json`
- `5555_case_A_geodesic_line_projection.png`
- `5556_case_B_curved_path_projection.png`
- `5557_case_C_perturbed_counterexample.png`
- `5558_metric_summary.png`
- `6666_manifest_sha256.txt`

## Final gate

Continue only if the next action has:

1. Defined variables
2. Defined formula
3. Numeric check
4. Counterexample
5. Reproducible output

