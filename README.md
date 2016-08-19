# blog


Install
-------

```
bundler install --path vendor/bundle
bundle exec jekyll serve
```

To compile:

```
bundle exec jekyll build
```

Latex
-----

### Inline

```
A inline formulate: {% latex %} E = mc^2 {% endlatex %}.
```

### Separate line

```
{% latex centered %}
E = mc^2
{% endlatex %}
```

Syntax highlighting
-------------------

<pre lang="no-highlight"><code>```d
var s = "JavaScript syntax highlighting";
alert(s);
```
</code></pre>


### With line numbers (WIP)

```
{% highlight d linenos %}
void main()
{
	writeln("aa");
}
{% endhighlight %}
```

See the [Markdown cheatsheet](https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet)
for more featurs. Github-flavored markdown is supported.

Plugins
-------

### [jekyll-katex-block](https://github.com/drewsberry/jekyll-katex-block)

- allows server-side rendering of LaTeX formulas (-> extremely fast)
- KaTeX files in `js` and `css` should be updated from time to time (it's still under heavy development)

### [jekyll-figure](https://github.com/paulrobertlloyd/jekyll-figure)

- `{% figure %}`

### Other

- needs rouge `>= 1.11.0` for the [D lexer](https://github.com/jneen/rouge/pull/435)


How to add figures
------------------

- generate `.svg`s (e.g. `inkscape --export-plain-svg=expo.svg expo.pdf`)
