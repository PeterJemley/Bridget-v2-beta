# TransformBench

A standalone command-line tool for benchmarking coordinate transformation performance as part of Phase 5 optimization work.

## Overview

TransformBench generates performance benchmarks across multiple input sizes and configurations to validate latency and throughput improvements and guard against regressions.

## Usage

### Run All Benchmarks

```bash
cd TransformBench
swift run TransformBench
```

This will generate:
- `benchmarks/baseline.json` - Control benchmarks (no caching)
- `benchmarks/phase5.1.json` - Full benchmark suite with various cache configurations

### Build and Run

```bash
cd TransformBench
swift build
swift run TransformBench
```

## Benchmark Categories

### Control Benchmarks
- **control_no_cache_*n***: Baseline performance without any caching

### Matrix Cache Benchmarks  
- **matrix_only_*n***: Performance with matrix caching enabled
- **matrix_plus_point_*n***: Performance with both matrix and point caching

### Input Sizes
- 1 point (single transformation)
- 64 points (small batch)
- 1,000 points (medium batch)  
- 10,000 points (large batch)

## Output Format

Results are written as JSON with the following structure:

```json
{
  "name": "control_no_cache_1",
  "n": 1,
  "p50": 9.059906005859375e-06,
  "p95": 1.0013580322265625e-05,
  "throughputPtsPerS": 110376.42105263157,
  "notes": "ref=seattleReference->seattleReference"
}
```

## Integration with Phase 5

This tool supports the Phase 5 optimization plan:

- **Step 0**: Establish clean baseline
- **Step 7**: Benchmark and tune optimizations
- **Gate H**: Verify targets met or retune plan produced

## Dependencies

- Swift 5.9+
- macOS 13+
- Accelerate framework (for SIMD/vDSP operations)

## Files

- `main.swift` - Benchmark runner and CLI interface
- `Package.swift` - Swift Package Manager configuration
- `Sources/TransformBench/` - Core transformation service files

For detailed benchmarking guidance, see `BridgetDocumentation.docc/BenchmarkingGuide.docc`.
