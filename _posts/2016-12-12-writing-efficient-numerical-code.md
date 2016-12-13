---
title: "Writing efficient numerical code in D"
layout: post
date: 2016-12-12
author: ljubobratovicrelja
categories: ndslice algorithm optimization
---

## Introduction

In this post I'd like give a brief overview of [`mir.ndslice.algorithm`](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html),
module equipped with iteration tools to allow convenient and fast processing of
multidimensional data. More importantly, I'd like to show some examples of it's usage, and how it can be easily utilized to
significantly improve performance of your numerical code.

*Note: It is assumed the reader is already somewhat familiar with ndslice
package <sup>[[1](#footndslice)]</sup>.*

### What does it offer?

`mir.ndslice.algorithm` module offers some basic multidimensional iteration algorithms, often seen in functional style programming, such as
[map](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#mapSlice), [fold](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#ndFold), [reduce](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#ndReduce), etc. There is a good amount of such [algorithms](http://dlang.org/phobos/std_algorithm_iteration.html)
already implemented in [Phobos](https://github.com/dlang/phobos), D's standard library, that are being used with great
success for some time now. What is special about `mir.ndslice.algorithm`, is that its integrated seamlessly
with rest of the *ndslice* package, by that allowing more natural flow of processing pipeline.

### LLVM acceleration

One of key components to make code based on `mir.ndslice.algorithm` blazingly fast, is to compile it with
*[LDC](https://github.com/ldc-developers/ldc)*, *LLVM* based D compiler<sup>[[2](#footldcversion)]</sup>.
Iteration algorithms in *ndslice* have been specially tailored to help *LDC* auto-vectorize kernels you write,
and also to apply unsafe floating point operations, else turned on with
[`@fastmath`](https://wiki.dlang.org/LDC-specific_language_changes#Attributes) attribute in *LDC*.
For more info on *LDC's* optimization techniques, you can check out
[this great article](http://johanengelen.github.io/ldc/2016/10/11/Math-performance-LDC.html),
by Johan Engelen.

--------------------------------------------------------------------------------------------

## Application

In past few months, we've been actively refactoring implementation details of [DCV](https://github.com/libmir/dcv),
computer vision library written in D, by replacing critical processing parts written in loops, with `mir.ndslice.algorithm`
equivalent. With minimal effort, we've managed to make code slightly cleaner, but more importantly - a lot faster!

All measuring presented in this post are made using following configuration:

| Model Identifier| MacBookPro13,1 |
| CPU | Intel Core i5-6360U @ 2.0 GHz |
| L3 Cache| 4 MB |
| Memory| 8 GB 1867 MHz LPDDR3 |
| OS | macOS Sierra 10.12.1 |

And here are the highlights from benchmarking comparison between before and after these refactorings:

|------------------------------------------------------------------------------------------|
| Algorithm                   | Previous Runtime [μs] | Current Runtime [μs] | Speedup [%] |
|------------------------------------------------------------------------------------------|
| harrisCorners (3x3) |1624687|278579|483 |
|------------------------------------------------------------------------------------------|
| harrisCorners (5x5) |4406410|328159|1242 |
|------------------------------------------------------------------------------------------|
| shiTomasiCorners (3x3)|1583896|223794|607 |
|------------------------------------------------------------------------------------------|
| shiTomasiCorners (5x5)|4422529|297106|1388 |
|------------------------------------------------------------------------------------------|
| extractCorners|3164128|355564|789 |
|------------------------------------------------------------------------------------------|
| threshold|124755|656|18917 |
|------------------------------------------------------------------------------------------|
| gray2rgb|441354|8918|4849 |
|------------------------------------------------------------------------------------------|
| hsv2rgb|433122|51392|742 |
|------------------------------------------------------------------------------------------|
| rgb2gray|262186|31813|724 |
|------------------------------------------------------------------------------------------|
| rgb2hsv|365969|65572|458 |
|------------------------------------------------------------------------------------------|
| convolution 1D (3) |124888|67486|85 |
|------------------------------------------------------------------------------------------|
| convolution 1D (5) |159795|68881|131 |
|------------------------------------------------------------------------------------------|
| convolution 1D (7)|206059|75361|173 |
|------------------------------------------------------------------------------------------|
| convolution 2D (3x3) |767058|120216|538 |
|------------------------------------------------------------------------------------------|
| convolution 2D (5x5)|1941055|360809|437 |
|------------------------------------------------------------------------------------------|
| convolution 2D (7x7)|3719552|865524|329 |
|------------------------------------------------------------------------------------------|
| convolution 3D (3x3)|2091025|374006|459 |
|------------------------------------------------------------------------------------------|
| convolution 3D (5x5)|5547364|1074208|416 |
|------------------------------------------------------------------------------------------|
| bilateralFilter (3x3)|6118754|1778482|244 |
|------------------------------------------------------------------------------------------|
| bilateralFilter (5x5)|16718651|4597027|263 |
|------------------------------------------------------------------------------------------|
| calcGradients|2244798|506101|343 |
|------------------------------------------------------------------------------------------|
| calcPartialDerivatives|428318|141520|202 |
|------------------------------------------------------------------------------------------|
| canny|4108987|758240|441 |
|------------------------------------------------------------------------------------------|
| filterNonMaximum|477543|38968|1125 |
|------------------------------------------------------------------------------------------|
| nonMaximaSupression|588455|84436|596 |
|------------------------------------------------------------------------------------------|
| remap|225780|62089|263 |
|------------------------------------------------------------------------------------------|
| warp|235169|63821|268 |
|------------------------------------------------------------------------------------------|

As you can see, speedups are massive - average in this set is 1356.54%, or if written as multiplier:
`mean(previous / current) = 14.57x`. But as I'll show you in this post, changes made to the algorithm implementations
were trivial. If you'd like to see complete benchmarking results, please take a look at
[PR](https://github.com/libmir/dcv/pull/58) implementing these changes.

*Discalmer: Please keep in mind DCV project is still far too young to be compared against proven computer vision toolkits such as
OpenCV. Optimizations done here are showing power of `mir.ndslice.algorithm`, but if you dive into implementation of these algorithms,
you'll notice most of them are implemented naively, without extensive optimization techniques applied. In future
we'll focus on [separable filtering](https://github.com/libmir/dcv/issues/85), followed by cache locality improvement.*

--------------------------------------------------------------------------------------------

## Examples

I'd like to show few examples of `mir.ndslice.algorithm`, but first we'll take a
look at the basic principle how it can efficiently replace loop-based code. And later
on we'll see how it can be used in a bit more complex algorithms.

### Basics

So, let's first examine the basic principle of utilizing iteration algorithms. This principle is also the
basis of that *DCV* refactoring I've mentioned. Say we have following code, written plainly in C-style
loops:

```d
@fastmath void someFunc(Slice!(2, float*) image) {
    for(size_t r; r < image.length!0; ++r) {
        for(size_t c; c < image.length!1; ++c) {
            // perform some processing on image pixel at [r, c]
        }
    }
}
```

... This code can be rewritten like so:

```d
import mir.ndslice.algorithm : ndEach;

@fastmath void kernel(ref float e)
{
    // perform that processing from inside those loops
}

image.ndEach!(kernel, Yes.vectorized);
```

So, instead of writing a function over the whole image, we could utilize [`ndEach`](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#ndEach)
to apply given kernel function to each pixel. Parameter `Yes.vectorized`  <sup>[[3](#footfm)]</sup> is telling the compiler to try to vectorize the operation using
[SIMD](https://en.wikipedia.org/wiki/SIMD) instructions, giving it significant performance boost on modern CPU architectures.
As said in the docs, [`ndEach`](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#ndEach)
iterates eagerly over the data. If processing should be rather evaluated lazily, we could utilize
[`mapSlice`](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#mapSlice).

### Convolution

To bring this example more down to earth, let's examine how we would implement classic
[image convolution](https://en.wikipedia.org/wiki/Kernel_(image_processing)#Convolution)
with these algorithms. We'll write classic, C-style implementation, and it's analogue with `mir.ndslice.algorithm`.
We will wrap both variants with `@fastmath` attribute, to be as fair as possible.
Here is the most trivial C-style implementation:

```d
@fastmath void convLoop(Slice!(2, F*) input, Slice!(2, F*) output, Slice!(2, F*) kernel)
{
    auto kr = kernel.length!0; // kernel row size
    auto kc = kernel.length!1; // kernel column size
    foreach (r; 0 .. output.length!0)
        foreach (c; 0 .. output.length!1)
        {
            // take window to input at given pixel coordinate
            Slice!(2, F*) window = input[r .. r + kr, c .. c + kc];

            // calculate result for current pixel
            F v = 0.0f;
            foreach (cr; 0 .. kr)
                foreach (cc; 0 .. kc)
                    v += window[cr, cc] * kernel[cr, cc];
            output[r, c] = v;
        }
}
```

Now let's examine how this would be implemented using `mir.ndslice.algorithm`:

```d
static @fastmath F kapply(F v, F e, F k) @safe @nogc nothrow pure
{
    return v + (e * k);
}

void convAlgorithm(Slice!(2, F*) input, Slice!(2, F*) output, Slice!(2, F*) kernel)
{
    import mir.ndslice.algorithm : ndReduce, Yes;
    import mir.ndslice.selection : windows, mapSlice;

    auto mapping = input
        // look at each pixel through kernel-sized window
        .windows(kernel.shape)
        // map each window to resulting pixel using convolution function
        .mapSlice!((window) {
            return ndReduce!(kapply, Yes.vectorized)(0.0f, window, kernel);
        });

    // assign mapped results to the output buffer.
    output[] = mapping[];
}
```

As you can see, we are replacing two double loops with few magic calls:

- [windows](http://dlang.org/phobos/std_experimental_ndslice_selection.html#windows): Convenient selector, allows us
to look at each pixel through kernel-sized window. It is effectively replacing first two loops in c-style function, automatically giving us the window slice.
- [mapSlice](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#mapSlice): mapping multidimensional slice by given
lambda.
- [ndReduce](http://docs.mir.dlang.io/latest/mir_ndslice_algorithm.html#ndReduce): apply reduce algorithm on each element of the window,
multiplying it with convolution kernel (mask) values. This is replacing third and fourth loop from first function.
This could also be the key for performance improvement, since its asking the compiler to vectorize given operation.

### Lazy evaluation?

We've said previously that `mapSlice` is evaluated lazily. And as you may have noticed, at the end of the `convAlgorithm`
function, we are evaluating the mapping function to the data, and assigning resulting values to the output buffer.
If instead we had needed lazy evaluated convolution, we could have just returned `mapping` value from the function,
so we could evaluate it lazily afterwards.

### Comparison

Complete benchmark source is located in the [Mir benchmark section](https://github.com/libmir/mir/blob/master/benchmarks/ndslice/convolution.d).
Let's compile this program, and make a comparison:

```
dub run --build=release-nobounds --compiler=ldmd2 --single convolution.d
```

Output on my machine is:

```
Running ./convolution
                     loops = 1 sec, 649 ms, 99 μs, and 6 hnsecs
     mir.ndslice.algorithm = 159 ms, 392 μs, and 9 hnsecs
```

So, for as little effort as this, I get **~10x speedup**! And hopefully many would agree that variant written with
`mir.ndslice.algorithm` is **much cleaner and less error prone**!

### Zipped tensors

D offers two ways to zip multiple ranges: [zip](http://dlang.org/phobos/std_range.html#.zip) and [lockstep](http://dlang.org/phobos/std_range.html#.lockstep).
Both of these functions provide easy-to-use syntax, and are very useful for common usage. Unfortunately, those are not so performance rewarding for multidimensional processing with `ndslice`. Instead, [`assumeSameStructure`](http://dlang.org/phobos/std_experimental_ndslice_slice.html#.assumeSameStructure) should be used.
This function zips two [`Slice`](http://dlang.org/phobos/std_experimental_ndslice_slice.html#.Slice) objects of the same
structure (shape and strides). It offers same dimension-wise range interface as `Slice` does (and by that is compatible with
`mir.ndslice.algorithm`), and can perform faster than general purpose utilities `zip` and `lockstep`.

To explain this concept further, let's examine following function:

```d
void binarizationLockstep(Slice!(2, F*) input, F threshold, Slice!(2, F*) output)
in
{
    assert(output.shape == input.shape);
}
body
{
    import std.range : lockstep;
    foreach(i, ref o; lockstep(input.byElement, output.byElement))
    {
        o = (i > threshold) ? F(1) : F(0);
    }
}
```

So, this is most basic binarization, based on given threshold. Special part to care about, related
to `lockstep`, is that [`byElement`](http://dlang.org/phobos/std_experimental_ndslice_selection.html#.byElement)
call on each input `Slice` - it returns element-wise iterable range. This range is really powerful - it
works even with non-contiguous memory and multidimensional arrays. But because of the complexity of implementation
which allows this, it can slow down performance considerably.

Let's replace `lockstep` with `assumeSameStructure`, and see how that affects the implementation:

```d
void binarizationAssumeSameStructure(Slice!(2, F*) input, F threshold, Slice!(2, F*) output)
in
{
    assert(output.structure == input.structure);
}
body
{
    import mir.ndslice.algorithm : ndEach;
    import mir.ndslice.slice : assumeSameStructure;

    assumeSameStructure!("input", "output")(input, output).ndEach!( (p) {
        p.output = (p.input > threshold) ? F(1) : F(0);
    });
}
```

We can notice right away there's a change in the assertion check in the input contract of the function -
`assert(output.structure == input.structure)`. As previously said, and as the name implies, `assumeSameStructure` requires
this so. This means one of these slices should not be non-contiguous. We can also notice `byElement` is not used in
this instance.

Now, let's examine performance differences by running the [benchmark program](https://github.com/libmir/mir/blob/master/benchmarks/ndslice/binarization.d).
On my machine result is following:

```d
Running ./binarization
                  lockstep = 169 ms, 871 μs, and 4 hnsecs
       assumeSameStructure = 39 ms, 105 μs, and 9 hnsecs
```

So, `assumeSameStructure` gives us about **4.5x** speedup. Also it is important to note this gives us interface compatible
with `ndslice` iteration algorithms.

--------------------------------------------------------------------------------------------

## Conclusion

In these two examples we've achieved some nice performance improvements with very little effort using `mir.ndslice.algorithm`,
and other `ndslice` utilities. We have also seen the improvement could be even better if `mir.ndslice.algorithm` solutions are
applied to more complex code you might encounter in numerical library such as *DCV*.
I personally would argue that every newcomer to D, coming for some numerical computing, would **have** to be introduced to `ndslice` and
it's submodules. And, I hope this post will inspire people to give it a spin, so we would have some more projects built on top of it,
growing our young **scientific ecosystem in D**!

-------------------------------------------------------------------------
<small><a name="footndslice"></a>[1] [*std.experimental.ndslice*](https://dlang.org/phobos/std_experimental_ndslice.html)
is the package providing structures and tools for multidimensional data processing. [*mir.ndslice*](https://github.com/libmir/mir#notes)
is the development version of `std.experimental.ndslice` in [**Mir**](https://github.com/libmir/mir), Generic Numerical Library for Science and Machine Learning. Note that `mir.ndslice` and `std.experimental.ndslice` will
removed and a new replacement will be provided as solid integrated solution to replace `ndslice`, `std.algorithm`, and `std.range`.</small>

<small><a name="footldcversion"></a>[2] Mir works with LDC compilers of version 1.1.0 beta 5 and later.</small>

<small> <a name="footfm"></a>[3]  The Future Mir Std library would not need `Yes.vectorized` and `Yes.fastmath` flags. </small>
