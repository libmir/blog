---
title: "Mir.GLAS vs Eigen vs OpenBLAS vs Intel MKL vs Apple Accelerate: AVX2 GEMM"
layout: post
date: 2016-09-23
author: 9il
categories: glas benchmark openblas
---

This post presents performance benchmarks for general matrix-matrix multiplication
between [Mir.GLAS](https://github.com/libmir/mir), [OpenBLAS](https://github.com/xianyi/OpenBLAS),
and two closed source BLAS implementations from Intel and Apple.

OpenBLAS is the default BLAS implementation for most numerical and scientific projects, for example the [Julia Programing Language](http://julialang.org/) and [NumPy](http://www.numpy.org/).
OpenBLAS [Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) computation kernels [were written in assembler](https://github.com/xianyi/OpenBLAS/blob/develop/kernel/x86_64/sgemm_kernel_16x4_haswell.S).

Mir GLAS (Generic Linear Algebra Subprograms) has a single generic kernel for all CPU targets, all floating point types, and all complex types.
It is written completely in D for [LDC](https://github.com/ldc-developers/ldc) (LLVM D Compiler), without any assembler blocks.
In addition, Mir GLAS Level 3 kernels are not unrolled and produce tiny binary code, so they put less pressure on the instruction cache in large applications.

Mir GLAS is truly generic comparing with C++ [Eigen](http://eigen.tuxfamily.org/).
To add a new architecture or target an engineer just needs to extend one small GLAS configuration file.
As of October 2016 configurations are available for X87, SSE2, AVX, and AVX2 instruction sets.

### Machine and software

| CPU | 2.2 GHz Core i7 (I7-4770HQ) |
| RAM | 16 GB of 1600 MHz DDR3L SDRAM |
| Model Identifier | MacBookPro11,2 |
| OS | OS X 10.11.6 |
| Mir GLAS | v0.18.0, native target, single thread |
| OpenBLAS | v0.2.18, native target, single thread |
| Intel MKL | Recent, native target, single thread (sequential configurations) |
| Apple Accelerate | OS X 10.11.6, native target, single thread (sequential configurations) |

#### Source code
The benchmark source code can be found [here](https://github.com/libmir/mir/blob/master/benchmarks/glas/gemm_report.d).

Mir GLAS has native `mir.ndslice` interface. `mir.ndslice` is a development version of 
[std.experimental.ndslice](http://dlang.org/phobos/std_experimental_ndslice.html).


```d
// Performs: c := alpha a x b + beta c
// glas is a pointer to a GlasContext
glas.gemm(alpha, a, b, beta, c);
```

#### Environment variables to set single thread for cblas

| openBLAS | OPENBLAS_NUM_THREADS=1 |
| Accelerate (Apple) | VECLIB_MAXIMUM_THREADS=1 |
| Intel MKL | MKL_NUM_THREADS=1 |

OpenBLAS and Intel MKL have sequential configurations. Sequential configuration is preferred for benchmarks.

### Results

There are eight charts:
 - single precisions numbers x2
 - double precisions numbers x2
 - single precisions complex numbers x2
 - double precisions complex numbers x2

Higher is better.

{% include bench_charts_1.html %}

### Conclusion

Mir GLAS is significantly faster then OpenBLAS and Apple Accelerate for virtually all benchmarks and parameters.
Mir GLAS average performance equals to Intel MKL, which is the best for Intel CPUs.
Due to its simple and generic architecture it can be easily configured for new targets.

### Acknowledgements
Andrei Alexandrescu.
