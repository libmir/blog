---
title: "Mir.GLAS vs OpenBLAS: AVX2 GEMM"
layout: post
date: 2016-09-23
author: 9il
categories: glas benchmark openblas
---

The post represents [Mir GLAS](https://github.com/libmir/mir) vs [OpenBLAS](https://github.com/xianyi/OpenBLAS)
benchmark for general matrix-matrix multiplication.

OpenBLAS is default BLAS implementation for most numerical and scientific projects, for example [Julia Programing Language](http://julialang.org/).
OpenBLAS [Haswell](https://en.wikipedia.org/wiki/Haswell) kernels was written in assembler.

Mir GLAS is Generic Linear Algebra Subroutines. It has single generic kernel for all targets, all floating point and complex types.
It is written completely in D, without any assembler blocks.

Mir GLAS is truly generic comparing with C++ [Eigen](http://eigen.tuxfamily.org/).
To add new architecture or target an engineer just need to extend small GLAS configuration file.
As of October 2016 configuration is available for X87, SSE2, AVX, and AVX2 instruction sets.

### Machine and software

| CPU | 2.2 GHz Core i7 (I7-4770HQ) |
| RAM | 16 GB of 1600 MHz DDR3L SDRAM |
| Model Identifier | MacBookPro11,2 |
| OS | OS X 10.11.6 |
| Mir GLAS | v0.18.0, native target, single thread |
| OpenBLAS | v0.2.18, native target, single thread |


#### Source code
The benchmark source code can be found [here](https://github.com/libmir/mir/blob/master/benchmarks/glas/gemm_report.d).

Mir GLAS has native `mir.ndslice` interface. `mir.ndslice` is development version of 
[std.experimental.ndslice](dlang.org/phobos/std_experimental_ndslice.html).


```d
// Performs: c := alpha a x b + beta c
// glas is a pointer to a GlasContext
glas.gemm(alpha, a, b, beta, c);
```

#### Environment variables to set single thread for cblas

| openBLAS | OPENBLAS_NUM_THREADS=1 |
| Accelerate (Apple) | VECLIB_MAXIMUM_THREADS=1 |
| Intel MKL | MKL_NUM_THREADS=1 |

### Results

There are four charts:
 - single precisions numbers
 - double precisions numbers
 - single precisions complex numbers
 - double precisions complex numbers

Higher is better.

{% include bench_charts_1.html %}

### Conclusion

Mir GLAS is significantly faster then OpenBLAS for almost all cases.
Due to its generic nature it can be easily configured for new targets.
