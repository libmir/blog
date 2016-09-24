---
title: "Mir.GLAS vs OpenBLAS vs Intel MKL vs Apple Accelerate: AVX2 GEMM"
layout: post
date: 2016-09-23
author: 9il
categories: glas benchmark openblas
---

The post represents performance benchmark for general matrix-matrix multiplication
between [Mir.GLAS](https://github.com/libmir/mir), [OpenBLAS](https://github.com/xianyi/OpenBLAS),
and two closed source BLAS implementations from Intel and Apple.

OpenBLAS is the default BLAS implementation for most of numerical and scientific projects, for example [Julia Programing Language](http://julialang.org/).
OpenBLAS [Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) computation kernels [were written in assembler](https://github.com/xianyi/OpenBLAS/blob/develop/kernel/x86_64/sgemm_kernel_16x4_haswell.S).

Mir GLAS is [LLVM](http://llvm.org)-accelerated Generic Linear Algebra Subroutines. It has single generic kernel for all targets, all floating point and complex types.
It is written completely in D for [LDC](https://github.com/ldc-developers/ldc) (LLVM D Compiler), without any assembler blocks.
In addition, Mir GLAS Level 3 kernels are not unrolled and produce tiny binary code.

Mir GLAS is truly generic comparing with C++ [Eigen](http://eigen.tuxfamily.org/).
To add new architecture or target an engineer just needs to extend small GLAS configuration file.
As of October 2016 configuration is available for X87, SSE2, AVX, and AVX2 instruction sets.

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

There are four charts:
 - single precisions numbers
 - double precisions numbers
 - single precisions complex numbers
 - double precisions complex numbers

Higher is better.

{% include bench_charts_1.html %}

### Conclusion

Mir GLAS is significantly faster then OpenBLAS and Apple Accelerate for almost all cases.
Mir GLAS average performance equals to Intel MKL, which is the best for Intel CPUs.
Due to its simple and generic architecture it can be easily configured for new targets.
