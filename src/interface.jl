using GeometryBasics
using FillArrays
using GLMakie

### interface

export iscatter, ilines, iheatmap
export iscatter!, ilines!, iheatmap!

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
iheatmap(z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(1:size(z,1), 1:size(z,2), z))
iheatmap(x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(x, y, z))
iheatmap(g, f::Function, xmin=0.0, xmax=1.0, ymin=0.0, ymax=1.0; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Function2D(f, xmin, xmax, ymin, ymax))
iheatmap(g, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(1:size(z,1), 1:size(z,2), z))
iheatmap(g, x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(x, y, z))

### implementation

function iviz(f, data::PointSet)
  lims = limits(data)
  xrange = range(lims[1], lims[2]; length=2)
  yrange = range(lims[3], lims[4]; length=2)
  qdata = sample(data, xrange, yrange)
  pts = Observable(qdata.points)
  fap = f(pts)
  reset_limits!(current_axis())
  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    pts[] = qdata.points
  end
  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])
  onany(update, resolution, axislimits)
  fap
end

function iviz(f, data::Continuous1D)
  lims = limits(data)
  r = range(lims[1], lims[2]; length=2)
  qdata = sample(data, r, nothing)
  x = Observable(qdata.x)
  y = Observable(qdata.y)
  fap = f(x, y)
  reset_limits!(current_axis())
  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    x.val = qdata.x
    y[] = qdata.y
  end
  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])
  onany(update, resolution, axislimits)
  fap
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
  reset_limits!(current_axis())
  function update(res, lims)
    xrange = range(lims.origin[1], lims.origin[1] + lims.widths[1]; length=round(Int, res[1]))
    yrange = range(lims.origin[2], lims.origin[2] + lims.widths[2]; length=round(Int, res[2]))
    qdata = sample(data, xrange, yrange)
    x.val = qdata.x
    y.val = qdata.y
    z[] = qdata.z
  end
  resolution = current_axis().scene.camera.resolution
  axislimits = current_axis().finallimits
  update(resolution[], axislimits[])
  onany(update, resolution, axislimits)
  fap
end
