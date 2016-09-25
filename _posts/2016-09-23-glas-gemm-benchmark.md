---
title: "Numeric age for D: Mir GLAS is faster then OpenBLAS and Eigen"
layout: post
date: 2016-09-23
author: 9il
categories: glas benchmark openblas
---

This post presents performance benchmarks for general matrix-matrix multiplication
between [Mir.GLAS](https://github.com/libmir/mir), [OpenBLAS](https://github.com/xianyi/OpenBLAS),
[Eigen](http://eigen.tuxfamily.org/), and two closed source BLAS implementations from Intel and Apple.

OpenBLAS is the default BLAS implementation for most numeric and scientific projects, for example the [Julia Programing Language](http://julialang.org/) and [NumPy](http://www.numpy.org/).
The OpenBLAS [Haswell](https://en.wikipedia.org/wiki/Haswell_(microarchitecture)) computation kernels [were written in assembler](https://github.com/xianyi/OpenBLAS/blob/develop/kernel/x86_64/sgemm_kernel_16x4_haswell.S).

Mir GLAS (Generic Linear Algebra Subprograms) has a single generic kernel for all CPU targets, all floating point types, and all complex types.
It is written completely in D for [LDC](https://github.com/ldc-developers/ldc) (LLVM D Compiler), without any assembler blocks.
In addition, Mir GLAS Level 3 kernels are not unrolled and produce tiny binary code, so they put less pressure on the instruction cache in large applications.

Mir GLAS is truly generic comparing with C++ Eigen.
To add a new architecture or target, an engineer just needs to extend one small GLAS configuration file.
As of October 2016 configurations are available for the X87, SSE2, AVX, and AVX2 instruction sets.

### Machine and software

| CPU | 2.2 GHz Core i7 (I7-4770HQ) |
| L3 Cache | 6 MB |
| RAM | 16 GB of 1600 MHz DDR3L SDRAM |
| Model Identifier | MacBookPro11,2 |
| OS | OS X 10.11.6 |
| Mir GLAS | 0.18.0, single thread |
| OpenBLAS | 0.2.18, single thread |
| Eigen | 3.3-rc1, single thread (sequential configurations) |
| Intel MKL | 2017.0.098, single thread (sequential configurations) |
| Apple Accelerate | OS X 10.11.6, single thread (sequential configurations) |

#### Source code
The benchmark source code can be found [here](https://github.com/libmir/mir/blob/master/benchmarks/glas/gemm_report.d).
It contains Mir vs a CBLAS implementation benchmark.

Mir GLAS has native `mir.ndslice` interface. `mir.ndslice` is a development version of 
[std.experimental.ndslice](http://dlang.org/phobos/std_experimental_ndslice.html).
GLAS uses [`Slice!(2, T*)`](http://dlang.org/phobos/std_experimental_ndslice_slice.html#.Slice) for matrix representation. It is a plain structure
composed of two lengths, two strides, and a pointer type of `T*`.
GLAS calling conversion can be easily used in any programming language with C ABI support.

```d
// Performs: c := alpha a x b + beta c
// glas is a pointer to a GlasContext
glas.gemm(alpha, a, b, beta, c);
```

In the same time, CBLAS interface is unwieldy

```d
void cblas_sgemm (
	const CBLAS_LAYOUT layout,
	const CBLAS_TRANSPOSE TransA,
	const CBLAS_TRANSPOSE TransB,
	const int M,
	const int N,
	const int K,
	const float alpha,
	const float *A,
	const int lda,
	const float *B,
	const int ldb,
	const float beta,
	float *C,
	const int ldc)
```

#### Environment variables to set single thread for cblas

| openBLAS | OPENBLAS_NUM_THREADS=1 |
| Accelerate (Apple) | VECLIB_MAXIMUM_THREADS=1 |
| Intel MKL | MKL_NUM_THREADS=1 |

OpenBLAS and Intel MKL have sequential configurations. Sequential configuration is preferred for benchmarks.

#### Building Eigen

Eigen should be built with `EIGEN_TEST_AVX` and `EIGEN_TEST_FMA` flags:
```
mkdir build_dir
cd build_dir
cmake -DCMAKE_BUILD_TYPE=Release -DEIGEN_TEST_AVX=ON -DEIGEN_TEST_FMA=ON ..
make blas
```
Eigen 3.3-rc1 provides the Fortran BLAS interface.
[Netlib's CBLAS](http://www.netlib.org/blas/#_cblas) library can be used for the benchmark to provide CBLAS interface on top of Eigen.

### Results

There are eight charts:
 - single precisions numbers x2
 - double precisions numbers x2
 - single precisions complex numbers x2
 - double precisions complex numbers x2

Higher is better.

{% include bench_charts_1.html %}

### Conclusion

Mir GLAS is significantly faster than OpenBLAS and Apple Accelerate for virtually all benchmarks and parameters,
two times faster than Eigen and Apple Accelerate for complex matrix multiplication.
Mir GLAS average performance equals to Intel MKL, which is the best for Intel CPUs.
Due to its simple and generic architecture it can be easily configured for new targets.

### Acknowledgements
Andrei Alexandrescu, Martin Nowak, Johan Engelen.
