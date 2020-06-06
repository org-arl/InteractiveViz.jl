# InteractiveViz.jl
Interactive visualization tools for Julia

### Yet another plotting package?

Julia already has a rich set of plotting tools in the form of the [Plots](https://github.com/JuliaPlots/Plots.jl) and [Makie](https://github.com/JuliaPlots/Makie.jl) ecosystems, and various backends for these. So why another plotting package?

_InteractiveViz_ is **not** a replacement for _Plots_ or _Makie_, but rather a graphics pipeline system developed on top of `Makie`. It has a few objectives:

- To provide a simple API to visualize large datasets (tens of millions of data points) easily.
- To enable interactivity, and be responsive even with large amounts of data.
- To render perceptually accurate summaries at large scale, allowing drill down to individual data points.
- To allow generation of data points on demand through a graphics pipeline, requiring computation only at a level of detail appropriate for display at the viewing resolution. Additional data points can be generated on demand when zooming or panning.

This package was partly inspired by the excellent [Datashader](https://datashader.org) package available in the Python ecosystem.

This package does not aim to provide comprehensive production quality plotting. It is aimed at interactive exploration of large datasets.

### Installation

```julia
julia>]
pkg> add InteractiveViz
```

### Dependencies

You'll need [Makie](https://github.com/JuliaPlots/Makie.jl) to see the plots _InteractiveViz_ generates.

### Usage

Detailed documentation for this package is still work-in-progress. The following examples should get you started:

Let's start off visualizing a simple function of one variable:
```julia
julia> using InteractiveViz
julia> iplot(sin, 0, 100);
```

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot1.png)

This displays the `sin()` function with the initial view set to the _x_-range of 0 to 100. You can however, pan and zoom beyond this range. Use the scroll wheel on your mouse, scroll gesture on your trackpad, or the arrow keys on your keyboard to pan. Draw selection box with your mouse to zoom, or use the "-", "+", "[" and "]" keys to zoom out/in in _y_/_x_ axes.

The first plot may take some time to show, as is common in the Julia ecosystem. If you want to speed this up, consider [precompiling Makie](https://github.com/JuliaPlots/Makie.jl#precompilation) into your system image.

Let's next try plotting 2 timeseries, each with 10 million points:
```julia
julia> iplot(hcat(5*sin.(0.02π .* (1:10000000)), randn(10000000)));
```

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot2a.png)

You can zoom and pan to see details:

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot2b.png)

Next, let us visualize the famous Mandelbrot set:
```julia
julia> using InteractiveViz.demo
julia> iheatmap(mandelbrot, -2, 0.66, -1, 1; overlay=true, axescolor=:white, cursor=true);
```

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot3a.png)

Try zooming in to a tiny part of the image, and see the fractal nature of the image render itself dynamically at full resolution!

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot3b.png)

You could of course plot a large heatmap stored in a matrix as well.
```julia
julia> iheatmap(randn(1000,10000), 0, 10, 0, 1);
```
By default, when the data is reduced to screen resolution, the graphics pipeline takes the mean of all data points mapped to a single pixel. While this is typically what you want, if you were looking for tiny peaks in the image, they may be averaged out and lost. You can change the `pooling=maximum` to modify this behavior.

Finally, let's try a scatter plot with a million points:
```julia
julia> iscatter(randn(1000000), randn(1000000); aggregate=true);
```
The `aggregate=true` option uses the graphics pipeline to reduce the data to screen resolution for plotting. This produces a responsive plot, but reduces the options you have for overlaying, adding color, or using other markers. If you wanted to avail those, don't aggregate:
```julia
julia> iscatter!(randn(10000) .- 1, randn(10000) .- 1; color=:blue);
```
The "!" versions of the plotting functions overlay the new plot on the previous plot, keeping the same _x_ and _y_ scales as far as possible.

![](https://raw.githubusercontent.com/org-arl/InteractiveViz.jl/master/docs/images/plot4.png)

You can add axes labels with keyword options `xlabel` and `ylabel`:
```julia
julia> iplot(sin, 0, 100; xlabel="time (samples)", ylabel="voltage");
```

While we haven't documented all the keyword options here, you'll find that most of the [plot attributes for Makie](http://makie.juliaplots.org/stable/plot-attributes.html) work as options in _InteractiveViz_.

While _InteractiveViz_ has much more to offer (multiple plots, linked axes, pan/zoom restrictions, etc) than the above use cases, the API is still evolving, and not yet documented. Other features such as colorbars and legends are work-in-progress and should be ready soon.

### Interactivity

Mouse or touchpad may be used for panning (scroll gestures) and zooming (select area to zoom). All interactions are also supported with keyboard bindings:

```
-/+          y-axis zoom out/in
[/]          x-axis zoom out/in
</>          brightness decrease/increase (heatmaps)
;/'          contrast decrease/increase (heatmaps)
arrow keys   pan left/right/up/down
0            reset zoom, pan, and color axis
```

The keymap can be modified if desired (see [discussion](https://github.com/org-arl/InteractiveViz.jl/issues/1) for details).

To enable data cursor (to get _x_, _y_ and _value_ (heatmaps) using mouse pointer), simply add `cursor=true` keyword argument to any of the plots.

### Feedback and comments

This package is in beta, and we welcome feedback and comments. Post them as [issues](https://github.com/org-arl/InteractiveViz.jl/issues) against this repository.
