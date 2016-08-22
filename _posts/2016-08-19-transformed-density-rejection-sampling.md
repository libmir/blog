---
title: "Transformed density rejection sampling"
layout: post
date: 2016-08-22 03:20:19
author: wilzbach
categories: random
---

In the [first post][random-sampling] a short introduction to [non-uniform sampling][random-sampling]
was given. This post explains the Tinflex algorithm, which is implemented in
[`mir.random.flex`][flex-docs].

Idea
----

The main idea of the Flex algorithm is to split the density distribution
into multiple intervals and sample from these
constructed intervals using the [*composition*][rs-composition] method.
For each interval a *hat* and *squeeze* function can be constructed.
Thus with the approximated hat and squeeze function of a selected interval
a value $x$ can be sampled
using the [*rejection with inversion*][rs-rejection-with-inversion] method.

For example, with efficiency $\rho = 1.8$ the normal distribution is split
into six intervals with different hat and squeeze functions. The
efficiency of the sampling can iteratively be improved by splitting the composition
into more intervals and thus yielding a better approximation to the density function.

{% figure caption: "\\(\rho = 1.8\\), 6 intervals constructed" | class: "halfsize" %}
![](/images/figures/random/tf_example_normal_6.svg)
{% endfigure %}

{% figure caption: "\\(\rho = 1.25\\), 10 intervals constructed" | class: "halfsize" %}
![](/images/figures/random/tf_example_normal_10.svg)
{% endfigure %}

{% figure caption: "\\(\rho = 1.1\\), 14 intervals constructed" | class: "halfsize" %}
![](/images/figures/random/tf_example_normal_14.svg)
{% endfigure %}

{% figure caption: "\\(\rho = 1.01\\), 44 intervals constructed" | class: "halfsize" %}
![](/images/figures/random/tf_example_normal_44.svg)
{% endfigure %}

In the following we will quickly dive into the essential basics behind the Tinflex
algorithm. In case your last math lesson was long ago, feel free to jump directly to the examples
and come back when you want to understand the inner workings of the Tinflex algorithm
in more details.

Tinflex transformations
-----------------------

Remember that the Tinflex algorithm splits the density distribution into intervals
and constructs a hat and squeeze function for each interval.
For the approximation of a hat or squeeze function, the Tinflex algorithm
constructs linear functions for _concave_, _convex_ intervals (or both if the interval
contains only one inflection point).
However as most distributions aren’t _concave_, but
_log-concave_, Tinflex uses a family of transformations for the
probability density function (pdf) as it operates in _logspace_
and can thus “force” most distributions to be concave. The
transformations can be grouped in two classes: (1) $c \neq 0$ and (2) $c = 0$
, which will subsequently be analyzed.

### $c$-transformations with $c \neq 0$

The general transformation function is $T(x) = x^c$, however as its inverse
function is only defined in $\mathbb{C}$, its needs to be restricted to
positive numbers only:

{% latex centered %}
	T_c(x) = sgn(c) * x^c
{% endlatex %}

With the usual inversion rules and if $c > 0$ we get:

{% latex centered %}
	\begin{aligned}
		y &= x^c \\
		log(y) &= log(x^c) \\
		log(y) &= c * log(x) \\
		\frac{log(y)}{c} &= log(x) \\
		exp\left(\frac{log(y)}{c}\right) &= x
	\end{aligned}
{% endlatex %}

which is $y^{1 / c}$ and if $c < 0$ we obtain:

{% latex centered %}
	\begin{aligned}
		y &= -x^c \\
		log(y) &= log(-x^c) \\
		log(y) &= -c * log(x) \\
		\frac{log(y)}{c} &= -log(x) \\
		exp\left(\frac{log(y)}{c}\right) &= -x
	\end{aligned}
{% endlatex %}

which is $(-y)^{1 / c}$.

Thus in general the inverse function is defined as:

{% latex centered %}
	T_c^{-1}(x) = (sgn(c) * x)^{\frac{1}{c}}
{% endlatex %}

Two examples of $T_c$ transformations can be seen below:

{% figure caption: "\\(x^2\\) (blue) and it’s inverse \\(x^{1/2}\\) (green)" | class: "halfsize" %}
![](/images/figures/random/a_2_sgn_pow.svg)
{% endfigure %}

{% figure caption: "\\(-x^{-0.5}\\) (blue) and it’s inverse \\((-x)^{1/-0.5}\\) (green)" | class: "halfsize" %}
![](/images/figures/random/a_0_5_sgn_pow.svg)
{% endfigure %}

Please note that (1) in the Tinflex paper and Mir implementation this case is split
into multiple common cases to obtain simpler formulas and thus reduce numerical
errors. Furthermore, (2) only with $c = 0$ the transformation is
two-sided, thus for $c < 0$ the inverse transformation $T^{-1}(x)$
in $\mathbb{R}$ is only defined for $x < 0$.

### $c$-transformations with $c = 0$

The special case for $c = 0$ needs to be made as division by zero isn’t
defined, however for this case the natural logarithm and it's inverse
the exponential function can be used:

{% latex centered %}
	T_c(x) = log(x) \quad T_c^{-1}(x) = exp(x)
{% endlatex %}

{% figure caption: "Exponential function (green) and it’s inverse the natural log (blue)" | class: "halfheight halfheight-md" %}
![](/images/figures/random/log_exp.svg)
{% endfigure %}

### Input of Tinflex

Remember that $f(x)$ is the pdf, and is its transformation $\tilde{f}(x)$ is:

{% latex centered %}
	\tilde{f}(x) = T_c(f(x))
{% endlatex %}

The Tinflex algorithm expects the **log**-density, which means that for $c = 0$, no
transformation needs to be applied. However, for $c \neq 0$ the inverse
is needed. This mean we first need to apply the *inverse* $T_c^{-1}(x) = exp(x)$
and then apply the other $T_c$ transformation:

{% latex centered %}
	\begin{aligned}
		\tilde{f}(x) &= T_{c \neq 0}(T_0^{-1}(x))) \\
		&= T_{c \neq 0}(exp(x))) \\
		&= sgn(c) * exp(x)^c \\
		&= sgn(c) * exp(x * c)
	\end{aligned}
{% endlatex %}

Linear functions
----------------

### Construction of linear functions

For every interval with function $\tilde{f}$ (black),
we define the three linear functions: its left tangent (orange),
its right tangent (red), and its secant (blue):

{% figure caption: "Concave interval" | class: "halfsize" %}
![](/images/figures/random/tangent_secant_concave.svg)
{% endfigure %}

{% figure caption: "Convex interval" | class: "halfsize" %}
![](/images/figures/random/tangent_secant_convex.svg)
{% endfigure %}

As it can be seen in the graphs of the two major case categories (concave, convex)
at least one linear function is majorizing $\tilde{f}$ (e.g. both tangents in the concave case),
and at least one linear function is majorized by $\tilde{f}$ (e.g. the secant in the concave case).
[Botts et. al. (2011)][tinflex] distinguish between eight cases and prove that this observation
of finding at least one linear hat and squeeze function is valid
as long as there is at most one inflection point in the interval.

### Definition of the linear functions

The following definition for linear functions is used:

{% latex centered %}
	\tilde{f}(x) = \alpha + \beta * (x - x_0)
{% endlatex %}

Remember that the transformation is applied with $T_c(x)$ and that the hat
function majorizes the *transformed* pdf, whereas the *transformed* pdf
majorizes the squeeze function.

Both the left and right tangent can be defined as follows, where $x_0$ is either
$l$ or $r$:

{% latex centered %}
	tan_{x_0}(x) = \tilde{f}(x_0) + \tilde{f}'(x_0) * (x - x_0)
{% endlatex %}

Moreover for the secant we can pick either $\ell$ or $r$ as root point, and thus
only the definition of the slope $\beta$ is different:

{% latex centered %}
	sec(x) = \tilde{f}(\ell) + \frac{\tilde{f}(r) - \tilde{f}(\ell)}{r - \ell} * (x - \ell)
{% endlatex %}

With these definition we can integrate the linear function to calculate the area
below the hat and squeeze function. Furthermore, using the their integral the
inverse function for the cumulative density function can be calculated, which
is used to map a uniform point $u$ to a point $x$ which is proportional
to the density of $h(x)$. These details can be found in [Tinflex paper][tinflex]
and in the [Mir implementation][flex-source]. For [`mir.random.flex`][flex-docs] additional
[supplementary material][flex-paper] is provided which explains the used integrations,
inversions and approximations.
In the following a more practical side of the Tinflex algorithm will be given by showing
two examples for the construction of a random distribution with the Tinflex method.

Example 1: Dagum distribution
-----------------------------

Assume you would want to draw random values from a non-common random distribution
like e.g. the [Dagum distribution](https://en.wikipedia.org/wiki/Dagum_distribution)
which has the following probability density function:

{% latex centered %}
	f(x) = \frac{ap}{x} \left( \frac{ (\frac{x}{b})^{ap}}{\left((\frac{x}{a})^a + 1\right)^{p+1}} \right)
{% endlatex %}

For simplicity of this example we fix $a$, $b$ and $p$ to $1$ and thus obtain:

{% latex centered %}
	f(x) = \frac{1}{(x + 1)^2}
{% endlatex %}

For the Tinflex algorithm the pdf function and its first and second derivative
need to be given in [log-space](#tinflex-transformations):

{% latex centered %}
	\tilde{f}(x) = log \left( \frac{1}{(x + 1)^2} \right)
{% endlatex %}

Its first and second derivative after $x$ are:

{% latex centered %}
	\tilde{f}'(x) = - \frac{2}{x + 1}  \quad \tilde{f}''(x) = \frac{2}{(x + 1)^2}
{% endlatex %}

In case you haven't used the [differentiation][wolfram-diff]
syntax on [Wolfram Alpha](http://www.wolframalpha.com), you should [familiarize][wolfram-diff] yourself with it.
For example, the correctness of [the first derivate][dagum-1st-derivative]
and [second derivative][dagum-2nd-derivative] can be quickly checked.
Last but not least, the Tinflex algorithm requires that each interval can have at most one inflection point.
Hence we need to check the [plot][dagum-plot] of $\tilde{f}(x)$ for inflection points.
However as there none if $x > 0$, we can freely pick any interval as starting intervals
and can thus construct the random distribution:

```d
import std.math : log, pow;

alias S = double;

// log-transformed pdf + first two derivatives
auto f0 = (S x) => cast(S) log(1 / pow(x + 1, 2));
auto f1 = (S x) => -2 / (1 + x);
auto f2 = (S x) => 2 / pow(1 + x, 2);

// which c-transformation function to use
S c = 0.5;

// the range of the interval that should be sampled from
// if there are multiple inflection points, more points need to be given
S[] points = [0, 10, S.max];

// target efficiency of hatArea / squeezeArea
S rho = 1.1;

flex(f0, f1, f2, c, points, rho);
```

{% figure caption: "Consecutive histogram" | class: "halfsize" %}
![](/images/figures/random/dist_dagum_hist.svg)
{% endfigure %}

{% figure caption: "Cumulative histogram" | class: "halfsize" %}
![](/images/figures/random/dist_dagum_hist_cum.svg)
{% endfigure %}

We can also have a look under the hood and inspect hat / squeeze plot
of the Dagum distribution (hat: red, squeeze: green).
For a clearer visibility only the range $[0, 3]$ is shown:

{% figure caption: "\\(\rho = 1.5\\), 4 intervals" | class: "halfsize" %}
![](/images/figures/random/dist_dagum_hs_rho_1.5.svg)
{% endfigure %}

{% figure caption: "\\(\rho = 1.1\\), 8 intervals" | class: "halfsize" %}
![](/images/figures/random/dist_dagum_hs_rho_1.1.svg)
{% endfigure %}

As it can be seen $\rho$ has a huge impact on the resulting speed, but _not_
on the statistical quality. Similarly the predefined intervals have only a slight
impact on the algorithm itself as e.g. they limit the left and right start border.
Picking a $c$-transformation can influence the numerical errors,
construction and sampling performance and even the number of intervals.
Hence usually a pre-definded transformation like $0$ (the "pure" log transformation) or $1$ is used.
However there are some restrictions, for example for unbounded domains $c > -1$ is required,
but $c$ also needs to be sufficiently small, so usually $-0.5$ is used.

[wolfram-diff]: https://reference.wolfram.com/language/tutorial/Differentiation.html
[dagum-1st-derivative]: http://www.wolframalpha.com/input/?i=D%5Blog+(1+%2F+(x+%2B+1)%5E2),+%7Bx,+1%7D%5D
[dagum-2nd-derivative]: http://www.wolframalpha.com/input/?i=D%5Blog+(1+%2F+(x+%2B+1)%5E2),+%7Bx,+2%7D%5D
[dagum-plot]: http://www.wolframalpha.com/input/?i=log+(1+%2F+(x+%2B+1)%5E2)

Example 2: Gompertz distribution
--------------------------------

Assume you would want to sample from the [Gompertz distribution](https://en.wikipedia.org/wiki/Gompertz_distribution)
which has the following probability density function:

{% latex centered %}
	f(x) = b \eta e^{bx} \ e^{\eta} \ exp(-\eta e^{bx})
{% endlatex %}

For simplicity, we set $\eta = 0.005$ and $b = 1.5$ and thus get

{% latex centered %}
	f(x) = 0.00753759 e^{-0.005 e^{1.5 x} + 1.5 x}
{% endlatex %}

And consequently in log-space:

{% latex centered %}
	\tilde{f}(x) = log \left( 0.00753759 e^{-0.005 e^{1.5 x} + 1.5 x} \right)
{% endlatex %}

Its first and second derivative after $x$ are:

{% latex centered %}
	\tilde{f}'(x) = 1.5-0.0075 e^{1.5 x}  \quad \tilde{f}''(x) = -0.01125 e^{1.5 x}
{% endlatex %}

Note that for [log-density][gompertz-plot] also no [inflection point][gompertz-inflection-point]
exists and thus we can define our sampling procedure:

```d
import std.math : log, pow;

alias S = double;

// log-transformed pdf + first two derivatives
auto f0 = (S x) => cast(S) log( S(0.00753759) * exp(S(-0.005) * exp(S(1.5) * x) + S(1.5) * x));
auto f1 = (S x) => S(1.5) - S(0.0075) * exp(1.5 * x);
auto f2 = (S x) => S(-0.01125) * exp(S(1.5) * x);

// which c-transformation function to use
S c = 1.5;

// the range of the interval that should be sampled from
S[] points = [0, 6, S.max];

// target efficiency of hatArea / squeezeArea
S rho = 1.1;

flex(f0, f1, f2, c, points, rho);
```

{% figure caption: "Consecutive histogram" | class: "halfsize" %}
![](/images/figures/random/dist_gompertz_hist.svg)
{% endfigure %}

{% figure caption: "Cumulative histogram" | class: "halfsize" %}
![](/images/figures/random/dist_gompertz_hist_cum.svg)
{% endfigure %}

We can also have a look under the hood and inspect hat / squeeze plot
of the Gompertz distribution (hat: red, squeeze: green).
For a clearer visibility only the range $[0, 6]$ is shown:

{% figure caption: "\\(\rho = 1.5\\), 8 intervals" | class: "halfsize" %}
![](/images/figures/random/dist_gompertz_hs_rho_1.5.svg)
{% endfigure %}

{% figure caption: "\\(\rho = 1.1\\), 14 intervals" | class: "halfsize" %}
![](/images/figures/random/dist_gompertz_hs_rho_1.1.svg)
{% endfigure %}

[gompertz-1st-derivative]: http://www.wolframalpha.com/input/?i=D%5Blog(0.00753759+e%5E(1.5+x-0.005+e%5E(1.5+x))),+%7Bx,+1%7D%5D
[gompertz-2nd-derivative]: http://www.wolframalpha.com/input/?i=D%5Blog(0.00753759+e%5E(1.5+x-0.005+e%5E(1.5+x))),+%7Bx,+2%7D%5D
[gompertz-plot]: http://www.wolframalpha.com/input/?i=log(1.5+*+0.005+*+e%5E%7B1.5x%7D+e%5E(0.005)+exp(-0.005+e%5E%7B1.5x%7D))
[gompertz-inflection-point]: http://www.wolframalpha.com/input/?i=D%5Blog(0.00753759+e%5E(1.5+x-0.005+e%5E(1.5+x))),+%7Bx,+2%7D%5D+%3D%3D+0

Benchmarks
----------

### Constructing intervals

In the following the [R Tinflex implementation][tinflex-r]
and the [Mir Flex implementation][flex-docs] are compared.
For the benchmark the time to construct the (Tin)flex intervals with efficiency $\rho$
for $n$ iterations has been measured:

$\rho$ | n   | Flex   | Tinflex
-------|-----|--------|--------
1.1    | 10K | 122 ms | 79.473s
1.01   | 1K  |  46 ms | 21.229s
1.001  | 1K  | 169 ms | 79.047s

Due to the enormous time consumption of the R implementation, the number of iterations
has been reduced from 10K to 1K for higher $\rho$.
With the Mir Flex implementation a performance boost performance boost for the construction phase
of the factor 500-600 in comparison to the R Tinflex implementation can be observed.

Not only has the D implementation been engineered very carefully with performance in mind,
but it also uses several tricks like a `BinaryHeap` to pick the best interval to split,
so that the _number of constructed intervals_ is also lower:

$\rho$  | Flex | Tinflex
--------|------|-----
1.5     | 8    | 9
1.1     | 15   | 20
1.01    | 45   | 49
1.001   | 141  | 175
1.0001  | 452  | 496
1.00001 | 1361 | 1824

The source of this benchmark is available [online][flex-tinflex-benchmark].

[flex-tinflex-benchmark]: https://gist.github.com/wilzbach/d9d2376a33ff52b22ee9046f8b20218a

### Sampling

A benchmark between multiple existing normal distributions samplers has been made.
All existing libraries ([dstats](https://github.com/DlangScience/dstats/blob/master/source/dstats/distrib.d),
[hap](https://github.com/WebDrake/hap/blob/master/source/hap/random/distribution.d),
[atmosphere](https://github.com/9il/atmosphere/blob/master/source/atmosphere/random.d))
use the [Box-Muller transformation](https://en.wikipedia.org/wiki/Box%E2%80%93Muller_transform)
to sample random values. Moreover intervals with `mir.random.flex` with three
different efficiencies $\rho$ ($1.3, 1.1, 1.001$) were constructed. The last method
is based on the WIP implementation of the [Ziggurat algorithm](https://github.com/libmir/mir/pull/261),
which is a specialized algorithm for monotone decreasing distributions.

Method			   | $\mu$ time| $\sigma^2$ time
-------------------|----------|------
boxMuller.naive    |   850 ms | 82 ms
boxMuller.dstats   |   801 ms |  2 ms
boxMuller.hap      |  3618 ms |  4 ms
boxMuller.atmos    |   934 ms |  2 ms
flexNormal.slow    |  1406 ms |  4 ms
flexNormal.medium  |  1206 ms |  1 ms
flexNormal.fast    |  1124 ms |  0 ms
ziggurat           |   357 ms |  5 ms

While one should look with care at performance benchmarks as statistical quality
is usually a higher goal than speed, it still can be seen that (1) investing more
time in constructing better approximated intervals is worth the investment if more values need
to be drawn and (2) there are specialized algorithm for very common random distributions
that of course should be preferred over generalized methods.

However, after all the goal of the Flex algorithm isn't to create the fastest random method, but
a _general applicable_ method that can be used to _create samplers for new distributions quickly_.

The source of this benchmark is directly available within the [Mir library][flex-benchmark].

[flex-benchmark]: https://github.com/libmir/mir/blob/master/benchmarks/flex/normal_dist.d

Where to go from here
---------------------

The Tinflex algorithm is available via the Mir library in [`mir.random.flex`][flex-docs].
Apart from the examples listed in this blog, [more examples][flex-examples]
are provided as part of Mir and can be conveniently executed with D's package manager `dub`.
If you want to dive deeper, you can also read the [Tinflex paper][tinflex],
browse the [Mir implementation][flex-source] or see the [supplementary material][flex-paper]
for the Mir implementation in which the used equations will be explained.

Literature references
---------------------

- Devroye, Luc. ["Sample-based non-uniform random variate generation."][devroye-86] _Proceedings of the 18th conference on Winter simulation_. ACM, 1986.
- Hörmann, Wolfgang. ["A rejection technique for sampling from T-concave distributions."][hoermann-95] _ACM Transactions on Mathematical Software (TOMS)_ 21.2 (1995): 182-193.
- Leydold, Josef, et al. ["An automatic code generator for nonuniform random variate generation."][leypold-03] _Mathematics and Computers in Simulation_ 62.3 (2003): 405-412.
- Botts, Carsten, Wolfgang Hörmann, and Josef Leydold. ["Transformed density rejection with inflection points."][tinflex] _Statistics and Computing_ 23.2 (2013): 251-260.
- Hörmann, Wolfgang, Josef Leydold, and Gerhard Derflinger. [Automatic nonuniform random variate generation][hoermann-13]. _Springer Science & Business Media_, 2013.

[random-sampling]: {{ site.baseurl }}/random/2016/08/19/intro-to-random-sampling.html
[rs-rejection-with-inversion]: {{ site.baseurl }}/random/2016/08/19/intro-to-random-sampling.html#rejection-with-inversion
[rs-composition]: {{ site.baseurl }}/random/2016/08/19/intro-to-random-sampling.html#composition
[flex-docs]: http://docs.mir.dlang.io/latest/mir_random_flex.html
[flex-examples]: https://github.com/libmir/mir/tree/master/examples/flex_plot
[flex-source]: https://github.com/libmir/mir/tree/master/source/mir/random/flex
[flex-paper]: http://files.wilzbach.me/mir/reports/tinflex.pdf
[tinflex]: http://epub.wu.ac.at/3158/1/techreport-110.pdf
[tinflex-r]: https://cran.r-project.org/web/packages/Tinflex/Tinflex.pdf

[devroye-86]: http://www.eirene.de/Devroye.pdf
[hoermann-95]: http://epub.wu.ac.at/1028/1/document.pdf
[leypold-03]: http://epub.wu.ac.at/364/1/document.pdf
[hoermann-13]: http://www.springer.com/us/book/9783540406525
