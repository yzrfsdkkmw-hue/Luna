# Geodesic Velocity Calibration Summary

Project: `calibrate_geodesic_velocity_hypothesis_v1`

H5: `/MATLAB Drive/modelTRAINING/jsonhotel_unified_001_002_SAFE_20260628_181406.h5`

H5 SHA256: `f853d2d6c3829cecbecc655c67173aa68ce2d623b7aa41785333828589319d40`

## Calibration

- calibration_found: `0`
- calibration_source: `NOT_FOUND_IN_H5`
- dx_m: `NaN`
- dt_s: `NaN`

## Raw-gradient vg^2/c^2 test

- status: `CALIBRATION_REQUIRED`
- conclusion: H5 field was computed, but physical vg2/c2 comparison requires dx_m and dt_s.

## Unit-direction vg^2/c^2 test

- status: `CALIBRATION_REQUIRED`
- conclusion: H5 field was computed, but physical vg2/c2 comparison requires dx_m and dt_s.

## Required dx/dt thresholds if calibration is missing

Raw-gradient candidate:

- required dx/dt for vg^2 > c^2 at p99: `6812950274.6469917 m/s`
- required dx/dt for significant threshold: `21544440453.354206 m/s`

Unit-direction candidate:

- required dx/dt for vg^2 > c^2 at p99: `317387827.1491726 m/s`
- required dx/dt for significant threshold: `1003668435.4032116 m/s`

## Interpretation

The H5 field was computed, but physical comparison to c^2 was not finalized because dx_m and dt_s were not found inside the H5 and manual override was disabled.
