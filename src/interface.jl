using GeometryBasics
using FillArrays
using GLMakie

### interface

export iscatter, ilines, iheatmap
export iscatter!, ilines!, iheatmap!

iscatter(xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter(pts; kwargs...), Point2fSet(xy, Fill(1, length(xy))))
iscatter(x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter(pts; kwargs...), Point2fSet(Point2f.(x, y), Fill(1, length(x))))
iscatter(g, xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter(g, pts; kwargs...), Point2fSet(xy, Fill(1, length(xy))))
iscatter(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter(g, pts; kwargs...), Point2fSet(Point2f.(x, y), Fill(1, length(x))))
iscatter!(xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter!(pts; kwargs...), Point2fSet(xy, Fill(1, length(xy))))
iscatter!(x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter!(pts; kwargs...), Point2fSet(Point2f.(x, y), Fill(1, length(x))))
iscatter!(g, xy::AbstractVector{Point2f}; kwargs...) = iviz(pts -> scatter!(g, pts; kwargs...), Point2fSet(xy, Fill(1, length(xy))))
iscatter!(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz(pts -> scatter!(g, pts; kwargs...), Point2fSet(Point2f.(x, y), Fill(1, length(x))))

ilines(f::Function; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Function1D(f))
ilines(y::AbstractVector; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Samples1D(eachindex(y), y))
ilines(x::AbstractVector, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(x, y; kwargs...), Samples1D(x, y))
ilines(g, f::Function; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Function1D(f))
ilines(g, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Samples1D(eachindex(y), y))
ilines(g, x::AbstractVector, y::AbstractVector; kwargs...) = iviz((x, y) -> lines(g, x, y; kwargs...), Samples1D(x, y))
ilines!(f::Function; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Function1D(f))
ilines!(y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Samples1D(eachindex(y), y))
ilines!(x::AbstractRange, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(x, y; kwargs...), Samples1D(x, y))
ilines!(g, f::Function; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Function1D(f))
ilines!(g, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Samples1D(eachindex(y), y))
ilines!(g, x::AbstractRange, y::AbstractVector; kwargs...) = iviz((x, y) -> lines!(g, x, y; kwargs...), Samples1D(x, y))

iheatmap(f::Function; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Function2D(f))
iheatmap(z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(1:size(z,1), 1:size(z,2), z))
iheatmap(x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(x, y, z; kwargs...), Samples2D(x, y, z))
iheatmap(g, f::Function; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Function2D(f))
iheatmap(g, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(1:size(z,1), 1:size(z,2), z))
iheatmap(g, x::AbstractRange, y::AbstractRange, z::AbstractMatrix; kwargs...) = iviz((x, y, z) -> heatmap(g, x, y, z; kwargs...), Samples2D(x, y, z))

### implementation

function iviz(f, data::PointSet)
  lims = limits(data.points)
  xrange = range(lims[1]...; length=2)
  yrange = range(lims[2]...; length=2)
  qdata = sample(data, xrange, yrange)
  pts = Observable(qdata.points)
  fap = f(pts)
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
  qdata = sample(data, 0.0:1.0:1.0, nothing)
  x = Observable(qdata.x)
  y = Observable(qdata.y)
  fap = f(x, y)
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
  qdata = sample(data, 0.0:1.0:1.0, 0.0:1.0:1.0)
  x = Observable(qdata.x)
  y = Observable(qdata.y)
  z = Observable(qdata.z)
  fap = f(x, y, z)
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

function limits(pts::AbstractVector{Point2f})
  xlims = extrema(map(p -> p[1], pts))
  ylims = extrema(map(p -> p[2], pts))
  (xlims, ylims)
end
