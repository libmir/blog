---
layout: post
title:  "Welcome!"
date:   2016-08-17 16:29:44 +0200
categories: random
---

```d
struct Discrete(T)
    if (isNumeric!T)
{

    /// Array with the original column value for a discrete value and its alternative
    private static struct AltPair
    {
        T prob; /// Probability p to select it by a coin toss, if this column is randomly picked
        size_t alt; /// Alternative value if coin toss at j fails
    }

    private AltPair[] arr;

    /**
    Initialize a discrete distribution sampler
    Params:
        probs = probabilities of the individual, discrete values
    Complexity: O(n), where n is the number of discrete values
    */
    this(const(T)[] probs)
    {
        debug
        {
            import mir.sum : sum, Summation;
            import std.math : approxEqual;
            assert(probs.sum!(Summation.fast).approxEqual(1.0), "Sum of the probabilities must be 1");
        }
        initialize(probs);
    }
```


A {% latex %} E = mc^2 {% endlatex %} b


{% latex centered %}
E = mc^2
{% endlatex %}
