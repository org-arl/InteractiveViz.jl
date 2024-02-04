using GeometryBasics
using FillArrays
using Makie

### figure-axis-plot container

struct FigureAxisPlotEx{T}
  fap::T
  update::Function
  params::Union{Nothing,Dict{Symbol,Any}}
end

function Base.getproperty(fapd::FigureAxisPlotEx, sym::Symbol)
  sym === :figure && return fapd.fap.figure
  sym === :axis && return fapd.fap.axis
  sym === :plot && return fapd.fap.plot
  return getfield(fapd, sym)
end

Base.display(fapd::FigureAxisPlotEx; kwargs...) = display(fapd.fap; kwargs...)
Base.display(screen::MakieScreen, fapd::FigureAxisPlotEx; kwargs...) = display(screen, fapd.fap; kwargs...)

function Base.show(io::IO, fapd::FigureAxisPlotEx)
  fapd.fap isa Makie.FigureAxisPlot && display(fapd.fap)
  return show(io, fapd.fap)
end

"""
  repaint(fapd::FigureAxisPlotEx)

Repaint a figure to update data that might have changed in the data source.
"""
repaint(fapd::FigureAxisPlotEx) = fapd.update()

### implementation

# The methods below make use of `redraw_limit`.
# When the user pans/zooms around the scene it can cause an excessive number of
# updates, as the scene is redrawn for every movement causing image tearing.
# Instead, we artificially limit the number of refreshes that occur.

function iviz(f, data::PointSet)
  lims = limits(data)
  xrange = range(lims[1], lims[2]; length=2)
  yrange = range(lims[3], lims[4]; length=2)
  qdata = sample(data, xrange, yrange)
  pts = Observable(qdata.points)
  fap = f(pts)
  if current_axis().limits[] == (nothing, nothing)
    xlims!(current_axis(), lims[1], lims[2])
    ylims!(current_axis(), lims[3], lims[4])
  end

  reset_limits!(current_axis())

  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    return pts[] = qdata.points
  end

  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])

  onany(resolution, axislimits) do res, axlimits
    if @isdefined(redraw_limit)
      close(redraw_limit)
    end
    redraw_limit = Timer(x -> update(res, axlimits), 0.1)
  end

  return FigureAxisPlotEx(fap, () -> update(resolution[], axislimits[]), nothing)
end

function iviz(f, data::Continuous1D)
  lims = limits(data)
  r = range(lims[1], lims[2]; length=2)
  qdata = sample(data, r, nothing)
  x = Observable(qdata.x)
  y = Observable(qdata.y)
  fap = f(x, y)

  if current_axis().limits[] == (nothing, nothing)
    xlims!(current_axis(), lims[1], lims[2])
  end

  reset_limits!(current_axis())

  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    x.val = qdata.x
    return y[] = qdata.y
  end

  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])

  onany(resolution, axislimits) do res, axlimits
    if @isdefined(redraw_limit)
      close(redraw_limit)
    end
    redraw_limit = Timer(x -> update(res, axlimits), 0.1)
  end

  return FigureAxisPlotEx(fap, () -> update(resolution[], axislimits[]), nothing)
end

function iviz(f, data::Continuous2D)
  lims = limits(data)
  rx = range(lims[1], lims[2]; length=2)
  ry = range(lims[3], lims[4]; length=2)
  qdata = sample(data, rx, ry)
  x = Observable(qdata.x)
  y = Observable(qdata.y)
  z = Observable(qdata.z)
  fap = f(x, y, z)

  if current_axis().limits[] == (nothing, nothing)
    xlims!(current_axis(), lims[1], lims[2])
    ylims!(current_axis(), lims[3], lims[4])
  end

  reset_limits!(current_axis())

  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    x.val = qdata.x
    y.val = qdata.y
    return z[] = qdata.z
  end

  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])

  onany(resolution, axislimits) do res, axlimits
    if @isdefined(redraw_limit)
      close(redraw_limit)
    end
    redraw_limit = Timer(x -> update(res, axlimits), 0.1)
  end

  return FigureAxisPlotEx(fap, () -> update(resolution[], axislimits[]), nothing)
end

### interface

iscatter(xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter(pts; kwargs...), Point2fSet(xy, nothing))
iscatter(x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter(pts; kwargs...), Point2fSet(Point2f.(x, y), nothing))
iscatter(g, xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter(g, pts; kwargs...), Point2fSet(xy, nothing))
iscatter(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter(g, pts; kwargs...), Point2fSet(Point2f.(x, y), nothing))
iscatter!(xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter!(pts; kwargs...), Point2fSet(xy, nothing))
iscatter!(x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter!(pts; kwargs...), Point2fSet(Point2f.(x, y), nothing))
iscatter!(g, xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter!(g, pts; kwargs...), Point2fSet(xy, nothing))
iscatter!(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter!(g, pts; kwargs...), Point2fSet(Point2f.(x, y), nothing))

ilines(f::Function, xmin=0.0, xmax=1.0; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Function1D(f, xmin, xmax))
ilines(y::AbstractVector; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Samples1D(eachindex(y), y))
ilines(x::AbstractVector, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Samples1D(x, y))
ilines(g, f::Function, xmin=0.0, xmax=1.0; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Function1D(f, xmin, xmax))
ilines(g, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Samples1D(eachindex(y), y))
ilines(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Samples1D(x, y))
ilines!(f::Function, xmin=0.0, xmax=1.0; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Function1D(f, xmin, xmax))
ilines!(y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Samples1D(eachindex(y), y))
ilines!(x::AbstractRange, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Samples1D(x, y))
ilines!(g, f::Function, xmin=0.0, xmax=1.0; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Function1D(f, xmin, xmax))
ilines!(g, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Samples1D(eachindex(y), y))
ilines!(g, x::AbstractRange, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Samples1D(x, y))

iheatmap(f::Function, xmin=0.0, xmax=1.0, ymin=0.0, ymax=1.0; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Function2D(f, xmin, xmax, ymin, ymax))
iheatmap(z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(1:size(z, 1), 1:size(z, 2), z))
iheatmap(x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(x, y, z))
iheatmap(g, f::Function, xmin=0.0, xmax=1.0, ymin=0.0, ymax=1.0; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Function2D(f, xmin, xmax, ymin, ymax))
iheatmap(g, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(1:size(z, 1), 1:size(z, 2), z))
iheatmap(g, x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(x, y, z))

iheatmap!(g::FigureAxisPlotEx, f::Function, xmin=0.0, xmax=1.0, ymin=0.0, ymax=1.0; kwargs...) = iviz((x, y, z) -> heatmap!(g.axis, x, y, z; kwargs...), Function2D(f, xmin, xmax, ymin, ymax))
iheatmap!(g::FigureAxisPlotEx, x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap!(g.axis, x, y, z; kwargs...), Samples2D(x, y, z))
iheatmap!(g::Axis, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap!(g, x, y, z; kwargs...), Samples2D(1:size(z, 1), 1:size(z, 2), z))
iheatmap!(g::FigureAxisPlotEx, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap!(g.axis, x, y, z; kwargs...), Samples2D(1:size(z, 1), 1:size(z, 2), z))

export iscatter, ilines, iheatmap
export iscatter!, ilines!, iheatmap!
export repaint
