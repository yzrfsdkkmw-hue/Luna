# Neutral HDF5 Calculation Summary

## Dataset inventory

| dataset_path | matlab_shape | class | elements | mean | std | min | max |
|---|---:|---:|---:|---:|---:|---:|---:|
| `/n_2_e8_lattice/roots_2d` | `[2 240]` | `single` | 480 | 0 | 0.372663278232404 | -1 | 1 |
| `/n_2_e8_lattice/connections/a` | `[2 1832]` | `single` | 3664 | 0.000171556803458838 | 0.298891796367649 | -0.91608190536499 | 0.807451784610748 |
| `/n_2_e8_lattice/connections/b` | `[2 1832]` | `single` | 3664 | -0.000171556803458838 | 0.296935446763357 | -0.807451784610748 | 0.91608190536499 |
| `/n_2_e8_lattice/connections/d` | `[1832 1]` | `single` | 1832 | 0.127293015981711 | 0.0653756865759643 | 0.0113389464095235 | 0.219964057207108 |
| `/n_2_e8_lattice/laplacian_modes/modes` | `[12 240]` | `single` | 2880 | -0.00570390571828607 | 0.0643083825269592 | -1 | 0.450707674026489 |
| `/n_2_e8_lattice/laplacian_modes/xy` | `[2 240]` | `single` | 480 | 0 | 0.372663278232404 | -1 | 1 |
| `/n_2_e8_lattice/streamlines/logmag` | `[278629 1]` | `single` | 278629 | 4.04772787341624 | 0.5866046595973 | -0.507802069187164 | 4.77460098266602 |
| `/n_2_e8_lattice/streamlines/sid` | `[278629 1]` | `uint16` | 278629 | 602.766657454895 | 345.717048278389 | 1 | 1200 |
| `/n_2_e8_lattice/streamlines/xy` | `[2 278629]` | `single` | 557258 | 0.034175920315812 | 0.444546025544706 | -1.00019311904907 | 1.00135135650635 |
| `/n_3_defect_topology/charge` | `[2500 1]` | `int8` | 2500 | 0.0168 | 1.10426696147666 | -4 | 3 |
| `/n_3_defect_topology/degree` | `[2500 1]` | `int8` | 2500 | 5.9832 | 1.10426696147666 | 3 | 10 |
| `/n_3_defect_topology/pos` | `[2 2500]` | `single` | 5000 | -0.00613823315750924 | 0.605338716560678 | -1.61449503898621 | 1.54541456699371 |
| `/n_4_geodesic_field/curl` | `[48400 1]` | `single` | 48400 | -6.21882035307517e-12 | 1.22585626766939 | -12.6009435653687 | 13.1933851242065 |
| `/n_4_geodesic_field/raw_points` | `[2 194527]` | `single` | 389054 | -0.000715964502592912 | 0.154193521278625 | -0.934298276901245 | 0.950641751289368 |
| `/n_4_geodesic_field/vel` | `[2 48400]` | `single` | 96800 | -0.000122248778923485 | 0.0971417574588153 | -0.999995648860931 | 0.999995648860931 |
| `/n_4_geodesic_field/xy` | `[2 48400]` | `single` | 96800 | 0 | 0.637981933909369 | -1.10000002384186 | 1.10000002384186 |
| `/n_5_composite_field_1000x1000/data` | `[5 1000000]` | `single` | 5000000 | 0.335358783772005 | 0.197695296813411 | 0 | 1 |
| `/n_6_field_maps_v3_800x800/chamber_field/data` | `[3 640000]` | `single` | 1920000 | 0.419856533979001 | 0.359694988191539 | 0 | 1 |
| `/n_6_field_maps_v3_800x800/fuchsian_tiling/data` | `[5 640000]` | `single` | 3200000 | 0.179665091150773 | 0.327389909151943 | 0 | 1 |
| `/n_6_field_maps_v3_800x800/ginibre_field/data` | `[3 640000]` | `single` | 1920000 | 0.230726408669464 | 0.33634938623821 | 0 | 1 |
| `/n_6_field_maps_v3_800x800/modular_eta/data` | `[3 640000]` | `single` | 1920000 | 0.643769723221128 | 0.469908540750343 | 0 | 1 |
| `/n_6_field_maps_v3_800x800/weyl_field/data` | `[5 640000]` | `single` | 3200000 | 7.38356105032536 | 25.7284885052324 | -13.6551094055176 | 239.989440917969 |
| `/n_7_apollonian_circle_model/e8_chamber_angles` | `[9 1]` | `double` | 9 | 1.96349540849362 | 1.70043690396958 | 0 | 5.49778714378214 |
| `/spectral_mappings/crystal_colors` | `[9 7]` | `uint8` | 63 | 68.8412698412698 | 27.3703432328511 | 35 | 102 |
| `/spectral_mappings/crystal_stops` | `[9 1]` | `double` | 9 | 0.532222222222222 | 0.365471537119438 | 0 | 1 |
| `/spectral_mappings/phase_colors` | `[6 7]` | `uint8` | 42 | 68.8571428571429 | 27.2357113387081 | 35 | 102 |
| `/spectral_mappings/phase_stops` | `[6 1]` | `double` | 6 | 0.5 | 0.374165738677394 | 0 | 1 |

## Calculated checks

- connections distance check: true
  - edge_count: 1832
  - max_abs_difference: 5.2252841026279e-08
- roots match laplacian xy: true
  - exact_equal: true
  - antipodal_pair_count: 120
- charge relation check: true
  - relation: charge = 6 - degree
  - all_true: true
