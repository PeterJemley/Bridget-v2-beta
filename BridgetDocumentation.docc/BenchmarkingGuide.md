# Benchmarking Guide

Learn how to run and interpret coordinate transformation benchmarks for Phase 5.

## Overview

Phase 5 requires benchmarking across multiple input sizes and configurations to validate latency and throughput improvements and guard against regressions.

This guide covers two ways to run benchmarks:

- Bench Runner in CI
- Command-Line Tool for local runs

## Bench Runner in CI

Use the `TransformBenchRunner` test to generate JSON benchmark artifacts during CI. This test is disabled by default and enabled with an environment variable to avoid slowing down regular PR runs.

### Enable in CI

- GitHub Actions example:

```yaml
jobs:
  bench:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - uses: maxim-lobanov/setup-xcode@v1
        with: { xcode-version: '16.0' }
      - name: Run Benchmarks
        run: |
          export RUN_BENCH=1
          xcodebuild test -scheme YourAppScheme -destination 'platform=iOS Simulator,name=iPhone 15'
      - name: Upload Benchmarks
        uses: actions/upload-artifact@v4
        with:
          name: phase5.1-benchmarks
          path: benchmarks/*.json
        ```

## Command-Line Tool

For local development and detailed analysis, use the command-line benchmark tool:

```bash
# Run all benchmarks
cd TransformBench
swift run TransformBench

# Run specific benchmark categories
swift run TransformBench --matrix-cache
swift run TransformBench --batch-processing
swift run TransformBench --simd-vs-vdsp

# Generate detailed reports
swift run TransformBench --report --output benchmarks/detailed-report.json
```

## Benchmark Categories

### Matrix Cache Benchmarks

Tests the performance impact of matrix caching across different scenarios:

- **Single-point transformations** with and without matrix cache
- **Matrix cache hit rates** under various workloads
- **Cache invalidation** performance impact
- **Memory usage** of matrix cache

### Batch Processing Benchmarks

Evaluates throughput improvements from batch processing:

- **Small batches** (1-32 points): SIMD vs scalar
- **Medium batches** (64-1,024 points): vDSP vs SIMD
- **Large batches** (1,024+ points): vDSP with different chunk sizes
- **Concurrency scaling** with multiple batch workers

### SIMD vs vDSP Benchmarks

Validates numerical accuracy and performance:

- **Numerical agreement** between SIMD and vDSP implementations
- **Performance comparison** across different input sizes
- **Precision validation** (must agree within 1e-12)

## Interpreting Results

### Latency Metrics

- **p50**: Median latency (typical user experience)
- **p95**: 95th percentile latency (worst-case scenarios)
- **p99**: 99th percentile latency (outlier handling)

### Throughput Metrics

- **Points per second**: Raw transformation throughput
- **Batches per second**: Batch processing efficiency
- **Memory bandwidth**: Data movement efficiency

### Success Criteria

Phase 5 targets:

- **Latency**: p95 per-record reduced ≥30% with matrix caching
- **Throughput**: batch throughput ≥50k points/sec (target hardware)
- **Accuracy**: SIMD/vDSP within 1e-12 vs baseline
- **Stability**: cache eviction/metrics stable; no error-log regressions

## Benchmark Configuration

### Input Sizes

Standard test sizes for comprehensive coverage:

- **1 point**: Single transformation
- **64 points**: Small batch
- **1,024 points**: Medium batch
- **10,000 points**: Large batch
- **100,000 points**: Stress test

### Coordinate Systems

Test across all supported coordinate system pairs:

- Seattle API ↔ Seattle Reference
- WGS84 ↔ Seattle Reference
- Seattle Reference ↔ Seattle API
- Cross-system transformations

### Bridge Coverage

Include representative bridge scenarios:

- **Known bridges**: With specific transformation matrices
- **Unknown bridges**: Using default transformations
- **Mixed workloads**: Combination of bridge types

## Troubleshooting

### Common Issues

**High variance in results:**
- Ensure warmup runs (2-3 iterations before measurement)
- Check for background processes affecting CPU
- Verify consistent input data

**Memory pressure:**
- Monitor RSS during large batch tests
- Check for memory leaks in cache implementations
- Validate cache eviction policies

**Numerical discrepancies:**
- Verify double precision throughout pipeline
- Check for float downcasts in hot paths
- Validate SIMD/vDSP implementation consistency

### Performance Tips

- **CPU affinity**: Pin benchmarks to specific cores
- **I/O isolation**: Use in-memory test data
- **Determinism**: Fix random seeds for reproducible results
- **Warmup**: Always include warmup runs before measurement

## Artifacts

Benchmark runs generate several artifacts:

- **`benchmarks/baseline.json`**: Initial performance baseline
- **`benchmarks/phase5.1.json`**: Phase 5.1 optimization results
- **`benchmarks/phase5.2.json`**: Phase 5.2 advanced features results
- **`benchmarks/readme.md`**: Machine specs and configuration details

## Integration with Phase 5

This benchmarking system supports the Phase 5 optimization plan:

- **Step 0**: Establish clean baseline
- **Step 7**: Benchmark and tune optimizations
- **Step 8**: Validate rollout safety
- **Gate H**: Verify targets met or retune plan produced

For detailed implementation, see the Phase 5 runbook in `CoordinateTransformationPlanPhase5.md`.

## Quick Start

1. **Run the benchmark tool:**
   ```bash
   cd TransformBench
   swift run TransformBench
   ```

2. **Check results:**
   ```bash
   ls -la benchmarks/
   cat benchmarks/phase5.1.json
   ```

3. **View in Xcode:**
   - The `BenchmarkingGuide.md` file should now be visible in the navigator
   - The `TransformBench/` directory contains the standalone CLI tool
