---
layout: post
title:  "An introduction to non-uniform random sampling"
date:   2016-08-19 03:29:44 +0200
author: wilzbach
categories: random
---


The problem
-----------

This post will dive into the topic of sampling of non-uniform random numbers.
The problem statement is:
_given a uniform random generator, sample non-uniform random values._

The following subsections will introduce some of the basic methods of
non-uniform random sampling,
which are also used by the Tinflex algorithm implemented in [Mir][mir].

The inversion method
--------------------

The underlying idea of non-uniform random sampling is that given an _inverse function_
$F^{-1}$ for the cumulative density function (CDF)
of a target density $f(x)$, random values can be
mapped to a distribution.

More visually one can imagine this with the histogram and cumulative histogram
of a random distribution:

{% figure caption: "Exponential distribution" | class: "halfsize" %}
![Image](/images/figures/random/expo.svg)
{% endfigure %}

{% figure caption: "Exponential distribution, cumulative" | class: "halfsize" %}
![Image](/images/figures/random/inversion_sampling.svg)
{% endfigure %}

To sample a variable distributed according to the exponential distribution,
a point $y$ on the CDF graph can be sampled and then using the *inverse*
function its matching value $x$ can be obtained, e.g. if $0.4$ is sampled (first brown
line) the inverse yields $f^{-1}(0.4) = -log(1 - 0.4) = 0.51$, for $0.6$
(yellow) it is $0.91$ and for $0.9$ (last brown line) it is $2.30$,
respectively.

Hence, given $F^{-1}$,
values from the density can be sampled by using the given uniform random
generator of the interval $[0, 1]$.
For example, for the sampling procedure for the exponential distribution is:

```d
import std.math : log;
import std.random : rndGen, uniform;

S sample(S, RNG, FInv)(ref RNG gen, FInv finv)
{
    S u = uniform!("[]", S)(0, 1);
    return finv(u);
}

auto fInvExp = (S x) => -log(S(1) - x);
sample!double(rndGen, fInvExp)
```

However there are two big problems of the inversion method: (1) for most
densities the inverse CDF is not known or can’t be determined or (2) if
it can be determined it’s usually very computationally expensive
function (e.g. an iterative numeric approximation needs to be used if no
exact form can be found).

Play yourself
-------------

All code listed in this blog post is available [online][samplers]
and can be conveniently executed:

```d
wget https://raw.githubusercontent.com/wilzbach/flex-paper/master/samplers/inverse_expo.d
dub inverse_expo.d
```

The plots above were generated with the `inverse_expo.d` snippet, so give it a try
and play with them.

The rejection method
--------------------

A very popular alternative is the *rejection* method - often known as
*acceptance-rejection* sampling. It only requires one to know the
density function of a distribution. The general idea is that if a random variable
$(x, y)$ is distributed within the density $f$, then it has the density
$f$ (blue curve in Figure 2).

This means $x$ and $y$ can be uniformly sampled within an area that is
strictly larger than $f$ and check whether the generated point is in the
area covered by the density function. If it’s within the area the point
is *accepted* (black in Figure 2), otherwise it is *rejected* (brown in Figure 2)
and new points are sampled until a point, which is within the area and thus
can be accepted, is drawn.

More formally, a hat function $h(x)$ that majorizes the density function
$f(x)$ is needed. In other words $ \forall x \in [l, r]: f(x) < h(x)$,
where $l$ and $r$ are the left and right boundaries of an interval. The
hat function (green in Figure 2) is the boundary function for our target density
sampling. In this simple example the hat function is
the green, horizontal line $x = 1$.

{% figure caption: "Rejection sampling of \\(sin(x)\\) (blue). Hat function \\((x = 1)\\) is drawn
in green. Points are marked black when accepted, and brown when
rejected. The area of the distribution density is colored in grey." | class: "halfheight" %}
![Image](/images/figures/random/rejection_sampling.svg)
{% endfigure %}

It is important to see that for every point $x$, it needs to be evaluated whether $x$ is
within the density area $f(x)$. As $h(x)$ is by definition always larger
than $f(x)$ the formula $y \cdot h(x) \leq f(x)$ can be used to
programmatically check whether a generated point is within the target
density as it covers the entire density of $f(x)$ (as
$f(x) \in [0, 1]\  \forall x \in [\ell, r],\  y \in [0, 1]$)

Thus the basic rejection method is:

```d
import std.random : rndGen, uniform;
import std.math : PI, sin;
alias T = double;

S sample(RNG, Pdf, Hat, S)(ref RNG gen, Pdf pdf, Hat hat, S left, S right)
{
    for (;;)
    {
        // generate x with density proportional to hat(x)
        S x = uniform!("[]", S)(left, right, gen);

        // generate "vertical" variable y to evaluate x
        S y = uniform!("[]", S)(0, 1, gen);

        // check whether the sampled point is within the density
        if (y * hat(x) <= pdf(x))
            return x;
    }
}
auto pdf = (T) => sin(x);
auto hat = (T x) => 1;
sample(rndGen, pdf, hat, T(0.0), PI);
```

Furthermore the performance of this method depends heavily on the ratio
of $f(x) / h(x) = \alpha$, where $1 / \alpha$ is the average number of
needed iterations to sample one value.

Rejection with inversion
------------------------

With just a straight line as upper bound a high percentage of the sampled points
fall in uncovered areas and thus need to be sampled again.
Therefore a more generic *hat* function is necessary. If the inverse of the
*hat* function is known, the inversion method can be used to sample from
an arbitrary *hat* function using its inverse of the cumulative density function
within the interval boundaries. For example for $h(x) = 1$ the integral
is trivially $H(x) = x$
and thus the cumulative density in the interval $[0, \pi]$ is
$H_{CDF}(x) = \frac{1}{\pi} x$ (the highest value of $h(x)$ needs to yield 1).
Hence the inverse is $H_{CDF}^{-1} = \pi x$
and the sampling procedure can be generalized:

```d
import std.math : PI, sin;
import std.random : rndGen, uniform;
alias T = double;

S sample(S, RNG, Pdf, Hat, HatInv)(ref RNG gen, Pdf pdf, Hat hat,
                                   HatInv hatInvCDF)
{
    for (;;)
    {
        // generate x with density proportional to hat(x) by inversing u
        S u = uniform!("[]", S)(0, 1, gen);
        S x = hatInvCDF(u);

        // generate "vertical" variable y to evaluate x
        S y = uniform!("[]", S)(0, 1, gen);

        // check whether the sampled point is within the density
        if (y * hat(x) <= pdf(x))
            return x;
    }
}
auto pdf = (T x) => sin(x);
auto hat = (T x) => 1;
auto hatInvCDF = (T u) => u * PI;
sample!T(rndGen, pdf, hat, hatInvCDF);
```

The Tinflex algorithm, which will be explained in a [later post][tinflex-post],
can automatically construct a hat
function for any differentiable density function.

Squeeze functions
-----------------

Calculating the probability density function is often expensive, thus
defining a lower bound that can be evaluated much faster yields a
performance boost. This lower bound is called $s(x)$ which is majorized
by $f(x)$, i.e. $s(x) \leq f(x) \ \forall x \in [l, r]$. For the previous example the
squeeze function is $1 - |1 - 2x / \pi |$. If $x$ is below the
squeeze function, it can be accepted *without* the need to calculate the
density function as by definition every point in the squeeze function
$s(x)$ is also below $f(x)$.

{% figure caption: "Rejection sampling of \\(sin(x)\\) (blue). Hat function \\((x = 1)\\) is drawn
in green, whereas the squeeze function \\(1 - |1 - 2x / \pi | \\) is drawn
in red. Points are marked black when accepted, green when accepted directly with the squeeze function,
and brown if rejected. The area of the distribution density is colored in grey." | class: "halfheight" %}
![Image](/images/figures/random/rejection_sampling_squeeze.svg)
{% endfigure %}

Furthermore, the *sample* routine can be adapted:

```d
import std.math : abs, PI, sin;
import std.random : rndGen, uniform;
alias T = double;

S sample(S, RNG, Pdf, Hat, HatInv, Squeeze)(ref RNG gen, Pdf pdf, Hat hat,
                                            HatInv hatInvCDF, Squeeze sq)
{
    import std.random : uniform;
    for (;;)
    {
        // generate x with density proportional to hat(x) by inversing u
        S u = uniform!("[]", S)(0, 1, gen);
        S x = hatInvCDF(u);

        // generate "vertical" variable y to evaluate x
        S y = uniform!("[]", S)(0, 1, gen);
        S t = y * hat(x);

        // check whether the sampled point is below the squeeze
        if (t <= sq(x))
            return x;

        // check whether the sampled point is within the density
        if (y * hat(x) <= pdf(x))
            return x;
    }
}

auto pdf = (T) => sin(x);
auto hat = (T x) => 1;
auto hatInvCDF = (T u) => u * PI;
auto sq = (T x) => 1 - abs(1 - 2 * x / PI);
sample!S(rndGen, pdf, hat, hatInvCDF, sq);
```

Composition
-----------

A density function might be split into multiple parts with each having
it’s own hat and squeeze. Given multiple densities, one can
sample from the overall density by picking from each sampler according
to a given probability $p_i$ which is defined by their hat area. The following
figure shows a distribution that is composed out of multiple hat and
squeeze parts:

{% figure caption: "Distribution split into multiple hat (red) and squeeze (green) functions." | class: "halfheight" %}
![Image](/images/figures/random/dist_density_at_boundaries_b_0_hs.svg)
{% endfigure %}

A simple example of composing distributions is illustrated below. The
density function is composed out of an exponential distribution (left)
and a uniform distribution (right) and features a gap in the middle.

```d

import std.random: Mt19937, uniform, rndGen;
alias T = double;

S sample(S, RNG, Sampler)(ref RNG gen, Sampler[] samplers, S[] probs)
{
    import mir.random.discrete : discrete;
    // pick a sampler with prob_i
    auto ds = discrete(probs);
    // sample with the chosen sampler
    return samplers[ds(gen)](gen);
}

// for simplicity we setup only two different samplers
alias Sampler = T delegate(ref typeof(rndGen) gen);
S[] probs = [0.7, 0.3];
Sampler[] samplers = new Sampler[probs.length];

// a part of the exponential distribution on the left
samplers[0] = (ref typeof (gen) gen) {
    import std.math : log;
    auto finv = (S x) => -log(S(1) - x);
    S u = uniform!("[]", S)(0, 0.8);
    return finv(u);
};

// a uniform sampler on the right half
samplers[1] = (ref typeof (gen) gen) {
    return uniform!("[]", S)(2, 3, gen);
};

sample!T(gen, samplers, probs);
```

Drawing a value from a discrete distribution can be done in $\mathcal{O}(1)$
with the [`mir.random.discrete`][mir-discrete] package, which implements
the [Alias method][vose-91].

The result of our basic composition with different target probabilities
for the samples can be seen in the diagrams below. The Tinflex algorithm will
automatically generate intervals with hat and squeeze function for the
desired distribution that are connected with such a composition sampler.

{% figure caption: "\\(p = [0.7, 0.3]\\)" | class: "halfsize" %}
![](/images/figures/random/composed_dist_70_30.svg)
{% endfigure %}

{% figure caption: "\\(p = [0.7, 0.3]\\), cumulative" | class: "halfsize" %}
![](/images/figures/random/composed_dist_70_30_cum.svg)
{% endfigure %}

{% figure caption: "\\(p = [0.3, 0.7]\\)" | class: "halfsize" %}
![](/images/figures/random/composed_dist_30_70.svg)
{% endfigure %}

{% figure caption: "\\(p = [0.3, 0.7]\\), cumulative" | class: "halfsize" %}
![](/images/figures/random/composed_dist_30_70_cum.svg)
{% endfigure %}

[mir-discrete]: http://docs.mir.dlang.io/latest/mir_random_discrete.html

Where to go from here
---------------------

All example snippets are available [online][samplers] and can be run directly
with `dub` - the D package manager. In the [next post][tinflex-post]
the Tinflex algorithm will be explained, The Tinflex algorithm
automatically splits a differentiable random density function into intervals and
constructs hat and squeeze function for each interval.

Literature references
---------------------

- Devroye, Luc. ["Sample-based non-uniform random variate generation."][devroye-86] _Proceedings of the 18th conference on Winter simulation_. ACM, 1986.
- Vose, Michael D. ["A linear algorithm for generating random numbers with a given distribution."][vose-91] _IEEE Transactions on software engineering_ 17.9 (1991): 972-975.
- Hörmann, Wolfgang, Josef Leydold, and Gerhard Derflinger. [Automatic nonuniform random variate generation][hoermann-13]. _Springer Science & Business Media_, 2013.

[mir]: http://mir.dlang.io
[samplers]: https://github.com/wilzbach/flex-paper/tree/master/samplers)
[tinflex-post]: {{ site.baseurl }}/random/2016/08/22/transformed-density-rejection-sampling.html

[devroye-86]: http://www.eirene.de/Devroye.pdf
[vose-91]: http://citeseerx.ist.psu.edu/viewdoc/download?doi=10.1.1.398.3339&rep=rep1&type=pdf
[hoermann-13]: http://www.springer.com/us/book/9783540406525
