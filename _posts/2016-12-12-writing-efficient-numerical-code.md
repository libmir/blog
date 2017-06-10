---
title: "Writing efficient numerical code in D"
layout: post
date: 2016-12-12
author: ljubobratovicrelja
categories: ndslice algorithm optimization
---

## Introduction

This post gives a brief overview of some of [**mir-algorithm's**](http://docs.algorithm.dlang.io) modules,
which provide iteration tools allowing convenient and fast processing of multidimensional data. It also
presents some examples of usage, to demonstrate how this module can be easily utilized to significantly
improve performance of numerical code written in D.

*This article assumes the reader has a cursory understanding of the ndslice package. If not, please
consult [this](http://docs.algorithm.dlang.io/latest/mir_ndslice.html) before returning here.*

### What does *mir-algorithm* offer?

[**mir-algorithm**](http://docs.algorithm.dlang.io) is a suite packed with structures and algorithms for
multidimensional processing, amongst which are some of the algorithms often seen in functional style
programming, such as [map](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.map),
[reduce](http://docs.algorithm.dlang.io/latest/mir_ndslice_algorithm.html#.reduce), etc. There is a good
amount of such [algorithms](http://dlang.org/phobos/std_algorithm_iteration.html) already implemented
in [Phobos](https://github.com/dlang/phobos), D's standard library, that are being used with great
success for some time now. What is special about *mir-algorithm's* variant, is that it is integrated seamlessly
with rest of the *ndslice* package, which makes for elegantly flowing processing pipelines.

### LLVM acceleration

One key component that makes code based on *mir-algorithm* blazingly fast, is to compile it with
*[LDC](https://github.com/ldc-developers/ldc)*, the *LLVM* based D compiler<sup>[[1](#footldcversion)]</sup>.
Iteration algorithms in *ndslice* have been specially tailored to help *LDC* auto-vectorize computation
kernels written by the end user, and also to apply unsafe floating point operations, turned on with
[`@fastmath`](https://wiki.dlang.org/LDC-specific_language_changes#Attributes) attribute in *LDC*.
For more info on *LDC's* optimization techniques, you can check out
[this great article](http://johanengelen.github.io/ldc/2016/10/11/Math-performance-LDC.html) by Johan Engelen.

## Application

In past few months, [Mir team](https://github.com/libmir) has been actively refactoring implementation details of
[DCV](https://github.com/libmir/dcv), computer vision library written in D, by replacing critical processing parts
written in loops, with *mir-algorithm* equivalents. With minimal effort, we've managed to make code slightly cleaner,
but more importantly - a lot faster!

All measuring presented in this post are made using following configuration:

| Model Identifier| MacBookPro13,1 |
| CPU | Intel Core i5-6360U @ 2.0 GHz |
| L3 Cache| 4 MB |
| Memory| 8 GB 1867 MHz LPDDR3 |
| OS | macOS Sierra 10.12.1 |

And here are the highlights from benchmarking comparison between before and after these refactorings:

| Algorithm                   | Previous Runtime [s] | Current Runtime [s] | Speedup [%] |
|-----------------------------|----------------------:|-------------------:|-----------------:|
| harrisCorners (3x3) |1.62469|0.278579|483 |
| harrisCorners (5x5) |4.40641|0.328159|1242 |
| shiTomasiCorners (3x3)|1.5839|0.223794|607 |
| shiTomasiCorners (5x5)|4.42253|0.297106|1388 |
| extractCorners|3.16413|0.355564|789 |
| gray2rgb|0.441354|0.008918|4849 |
| hsv2rgb|0.433122|0.051392|742 |
| rgb2gray|0.262186|0.031813|724 |
| rgb2hsv|0.365969|0.065572|458 |
| convolution 1D (3) |0.124888|0.067486|85 |
| convolution 1D (5) |0.159795|0.068881|131 |
| convolution 1D (7)|0.206059|0.075361|173 |
| convolution 2D (3x3) |0.767058|0.120216|538 |
| convolution 2D (5x5)|1.94106|0.360809|437 |
| convolution 2D (7x7)|3.71955|0.865524|329 |
| convolution 3D (3x3)|2.09103|0.374006|459 |
| convolution 3D (5x5)|5.54736|1.07421|416 |
| bilateralFilter (3x3)|6.11875|1.77848|244 |
| bilateralFilter (5x5)|16.7187|4.59703|263 |
| calcGradients|2.2448|0.506101|343 |
| calcPartialDerivatives|0.428318|0.14152|202 |
| canny|4.10899|0.75824|441 |
| filterNonMaximum|0.477543|0.038968|1125 |
| nonMaximaSupression|0.588455|0.084436|596 |
| remap|0.22578|0.062089|263 |
| warp|0.235169|0.063821|268 |

Speedups are massive - average in this set is 676.7%, or if written as multiplier: `mean(previous / current) = 7.7x`.
But as shown below, changes made to the algorithm implementations were trivial. For the complete benchmarking results,
please take a look at the [pull request](https://github.com/libmir/dcv/pull/58) implementing these changes.

*Disclaimer: Please keep in mind the DCV project is still far too young to be compared against proven computer vision toolkits such as
OpenCV. Optimizations done here are showing the power of mir-algorithm, but if you dive into the implementation of these algorithms,
you'll notice most of them are implemented naively, without extensive optimizations. A future post will focus on
[separable filtering](https://github.com/libmir/dcv/issues/85), followed by cache locality improvement.*

## Examples

We'd like to show few examples of `mir-algorithm`, but first let's take a look at the basic principle of replacing
loop-based code with pipelines efficiently. And later on we'll see how it can be used in a bit more complex algorithms.

### Basics

So, let's first examine the basic principle of utilizing iteration algorithms. This principle is also the
basis of that *DCV* refactoring we've mentioned. Say we have following code, written plainly in C-style
loops:

```d
@fastmath void someFunc(Slice!(Contiguous, [2], float*) image) {
    for(size_t r; r < image.length!0; ++r) {
        for(size_t c; c < image.length!1; ++c) {
            // perform some processing on image pixel at [r, c]
        }
    }
}
```

This code can be rewritten like so:

```d
import mir.ndslice.algorithm : each;

@fastmath void kernel(ref float e)
{
    // perform that processing from inside those loops
}

image.each!(kernel);
```

So, instead of writing a function over the whole image, we could utilize [`each`](http://docs.algorithm.dlang.io/latest/mir_ndslice_algorithm.html#each)
to apply the given kernel function to each pixel. As said in the docs, [`each`](http://docs.algorithm.dlang.io/latest/mir_ndslice_algorithm.html#each)
iterates eagerly over the data. If processing should be rather evaluated lazily, we could utilize [`map`](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.map).

### Convolution

To make the example more concrete, let's examine how we would implement classic
[image convolution](https://en.wikipedia.org/wiki/Kernel_(image_processing)#Convolution) with these algorithms. We'll
write classic, C-style implementation, and its analogue with *mir-algorithm*. We will wrap both variants with
`@fastmath` attribute, to be as fair as possible. Here is the most trivial C-style implementation:

```d
@fastmath
void convLoop
(
    Slice!(Contiguous, [2], float*) input,
    Slice!(Contiguous, [2], float*) output,
    Slice!(Contiguous, [2], float*) kernel
)
{
    auto kr = kernel.length!0; // kernel row size
    auto kc = kernel.length!1; // kernel column size
    foreach (r; 0 .. output.length!0)
        foreach (c; 0 .. output.length!1)
        {
            // take window to input at given pixel coordinate
            Slice!(Canonical, [2], float*) window = input[r .. r + kr, c .. c + kc];

            // calculate result for current pixel
            float v = 0.0f;
            foreach (cr; 0 .. kr)
                foreach (cc; 0 .. kc)
                    v += window[cr, cc] * kernel[cr, cc];
            output[r, c] = v;
        }
}
```

Now let's examine how this would be implemented using *mir-algorithm*:

```d
static @fastmath float kapply(float v, float e, float k) @safe @nogc nothrow pure
{
    return v + (e * k);
}

void convAlgorithm
(
    Slice!(Contiguous, [2], float*) input,
    Slice!(Contiguous, [2], float*) output,
    Slice!(Contiguous, [2], float*) kernel
)
{
    import mir.ndslice.algorithm : reduce;
    import mir.ndslice.topology: windows, map;

    auto mapping = input
        // look at each pixel through kernel-sized window
        .windows(kernel.shape)
        // map each window to resulting pixel using convolution function
        .map!((window) {
            return reduce!(kapply)(0.0f, window, kernel);
        });

    // assign mapped results to the output buffer.
    output[] = mapping[];
}
```

The pipeline version replaces two double loops with a few magic calls:

- [windows](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.windows): Convenient selector, allows us
to look at each pixel through kernel-sized window. It is effectively replacing first two loops in c-style function, automatically giving us the window slice.
- [map](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.map): mapping multidimensional slice by given lambda.
- [reduce](http://docs.algorithm.dlang.io/latest/mir_ndslice_algorithm.html#.reduce): apply reduce algorithm on each element of the window,
multiplying it with convolution kernel (mask) values. This is replacing third and fourth loop from first function.
This could also be the key for performance improvement, since its well suited to be auto-vectorized by *LLVM*.

### Lazy evaluation?

As it is previously noted, `map` is evaluated lazily. At the end of the `convAlgorithm`
function, we are evaluating the mapping function to the data, and assigning resulting values to the output buffer.
If instead we had needed lazy evaluated convolution, we could have just returned `mapping` value from the function,
so we could evaluate it lazily afterwards.

### Comparison

Complete benchmark source is located in the [Mir benchmark section](https://github.com/libmir/mir/blob/master/benchmarks/ndslice/convolution.d).
Let's compile this program, and make a comparison:

```
dub run --build=release-nobounds --compiler=ldmd2 --single convolution.d
```

Output is:

```
Running ./convolution
                     loops = 1 sec, 649 ms, 99 μs, and 6 hnsecs
     mir.ndslice.algorithm = 159 ms, 392 μs, and 9 hnsecs
```

So, for as little effort as this, we get **~10x speedup**! And hopefully many would agree that the variant written with
*mir-algorithm* is **much cleaner and less error prone**!

### Zipped tensors

D offers two ways to zip multiple ranges: [zip](http://dlang.org/phobos/std_range.html#.zip) and
[lockstep](http://dlang.org/phobos/std_range.html#.lockstep). Both of these functions provide easy-to-use syntax and are
very useful for common usage. Unfortunately, those are not so performance rewarding for multidimensional processing with
`ndslice`. Instead, [`mir.ndslice.topology.zip`](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.zip) should
be used. This function zips two slices of the same structure (shape and strides). It offers same dimension-wise range
interface as [`Slice`](http://docs.algorithm.dlang.io/latest/mir_ndslice_slice.html#.Slice) does (and by that is compatible
with the rest of the *mir-algorithm*), and can perform faster than general purpose utilities Phobos' `zip` and `lockstep`.

To explain this concept further, let's examine following function:

```d
@fastmath
void binarizationLockstep
(
    Slice!(Contiguous, [2], float*) input,
    float threshold,
    Slice!(Contiguous, [2], float*) output
)
in
{
    assert(output.shape == input.shape);
}
body
{
    import mir.ndslice.topology : flattened;
    import std.range : lockstep;
    foreach(i, ref o; lockstep(input.flattened, output.flattened))
    {
        o = (i > threshold) ? float(1) : float(0);
    }
}
```

So, this is a most basic binarization, based on given threshold. To zip those matrices using `std.range.lockstep`, we first had to
flatten them with [`mir.ndslice.topology.flattened`](http://docs.algorithm.dlang.io/latest/mir_ndslice_topology.html#.flattened), to
construct a vector, i.e. one-dimensional array, so it can be inserted into `lockstep`, as classic [D range](https://tour.dlang.org/tour/en/basics/ranges).

Let's replace `std.range.lockstep` with `mir.ndslice.topology.zip`, and see how that affects the implementation:

```d
@fastmath @nogc nothrow @safe
void binarizationZip
(
    Slice!(Contiguous, [2], float*) input,
    float threshold,
    Slice!(Contiguous, [2], float*) output
)
{
    import mir.ndslice.algorithm : each;
    import mir.ndslice.topology : zip;

    zip(input, output).each!( (z) {
        z.b = z.a > threshold ? 1.0f : 0.0f;
    });
}
```

This one looks pretty much the same as previous one, with slight difference of utilizing `mir.ndslice.toplogy.zip` instead of `std.range.lockstep`.
Also, now there's no need to flatten slices, since `mir.ndslice.algorithm.each` works on multidimensional data. But if you take
one more look at the signature of these two functions you'll notice a difference in annotated attibutes:

```d
@fastmath
void binarizationLockstep(...);

@fastmath @nogc nothrow @safe
void binarizationZip(...);
```

`std.range.lockstep` is not `nothrow`, not `@nogc`, and not `@safe`, but `mir.ndslice.topology.zip` is! 


Now, let's compare the impact of these changes on performance by running the [benchmark program](https://github.com/libmir/mir/blob/master/benchmarks/ndslice/binarization.d).
The results are as follows:

```d
Running ./binarization
                  lockstep = 169 ms, 871 μs, and 4 hnsecs
                       zip = 39 ms, 105 μs, and 9 hnsecs
```

So, `mir.ndslice.topology.zip` gives us about **4.5x** speedup. Also it is important to note this gives us interface compatible
with `ndslice` iteration algorithms, and also gives us freedom to write `nothrow @nogc @safe` code!

## Conclusion

In these two examples we've achieved some nice performance improvements with very little effort by using *mir-algorithm* suite. We
have also seen the improvement could be even better if *mir-algorithm* solutions are applied to more complex code you might encounter
in numerical library such as *DCV*. We would argue that every newcomer to D, having an interest in numerical computing, should take
a close look at `ndslice` and its submodules. And, we hope this post will inspire people to give it a spin, so we would have some
more projects built on top of it, growing our young **scientific ecosystem in D**!

## Acknowledgements

Thanks to Ilya Yaroshenko, Sebastian Wilzbach, Andrei Alexandrescu and Johan Engelen for helping out with truly informative reviews!

-------------------------------------------------------------------------
<small><a name="footldcversion"></a>[1] Mir works with LDC compilers of version 1.1.0 beta 5 and later.</small>
