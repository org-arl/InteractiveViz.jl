export iplot, iplot!, iscatter, iscatter!, iheatmap

const bgcolor = RGB(1,1,1)

# TODO: add support for SignalBuf
# TODO: provide access to pooling options

iplot(y::AbstractVecOrMat, args...; kwargs...) = iplot(1:size(y,1), y, args...; kwargs...)
iplot!(y::AbstractVecOrMat; kwargs...) = iplot!(1:size(y,1), y; kwargs...)

function iplot(x::AbstractVector, y::AbstractMatrix, args...; kwargs...)
  colors = distinguishable_colors(size(y,2)+1, [bgcolor])
  iplot(x, y[:,1], args...; color=colors[2], kwargs...)
  for k ∈ 2:size(y,2)
    iplot!(x, y[:,k]; color=colors[1+k], kwargs...)
  end
end

function iplot!(x::AbstractVector, y::AbstractMatrix; kwargs...)
  colors = distinguishable_colors(size(y,2)+1, [bgcolor])
  for k ∈ 1:size(y,2)
    iplot!(x, y[:,k]; color=colors[1+k], kwargs...)
  end
end

function iplot(x::AbstractVector, y::AbstractVector, x1=missing, x2=missing, y1=missing, y2=missing; axes=true, axescolor=:black, grid=false, overlay=false, cursor=false, kwargs...)
  length(x) != size(y,1) && error("x and y must be of equal length")
  if x1 === missing || x2 === missing
    x1a, x2a = autorange(x)
    x1 === missing && (x1 = x1a)
    x2 === missing && (x2 = x2a)
  end
  if y1 === missing || y2 === missing
    y1a, y2a = autorange(y, 0.1)
    y1 === missing && (y1 = y1a)
    y2 === missing && (y2 = y2a)
  end
  x2 <= x1 && error("Bad x range")
  y2 <= y1 && error("Bad y range")
  datasrc = datasource(;
    generate! = x isa AbstractRange ? linepool! : linecrop!,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    xmin = minimum(x),
    xmax = maximum(x),
    data = hcat(x, y),
    kwargs...
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(LineCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, grid=grid, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iplot!(x::AbstractVector, y::AbstractVector; kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = datasource(;
    generate! = linecrop!,
    xyrect = prev.datasrc.xyrect,
    xylock = prev.datasrc.xylock,
    data = hcat(x, y),
    kwargs...
  )
  c = addcanvas!(LineCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

function iplot(f::Function, x1=0.0, x2=1.0, y1=missing, y2=missing; axes=true, axescolor=:black, grid=false, overlay=false, cursor=false, kwargs...)
  x2 <= x1 && error("Bad x range")
  if y1 === missing || y2 === missing
    y1a, y2a = autorange(f.(x1 .+ rand(1000)*(x2-x1)), 0.1)
    y1 === missing && (y1 = y1a)
    y2 === missing && (y2 = y2a)
  end
  y2 <= y1 && error("Bad y range")
  datasrc = datasource(
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    kwargs...
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(LineCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, grid=grid, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iplot!(f::Function; kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = datasource(;
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = prev.datasrc.xyrect,
    xylock = prev.datasrc.xylock,
    kwargs...
  )
  c = addcanvas!(LineCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

function iscatter(x::AbstractVector, y::AbstractVector, x1=missing, x2=missing, y1=missing, y2=missing; aggregate=false, xylock=true, axes=true, axescolor=:black, grid=false, overlay=false, cursor=false, kwargs...)
  length(x) != length(y) && error("x and y must be of equal length")
  if x1 === missing || x2 === missing
    x1a, x2a = autorange(x)
    x1 === missing && (x1 = x1a)
    x2 === missing && (x2 = x2a)
  end
  if y1 === missing || y2 === missing
    y1a, y2a = autorange(y)
    y1 === missing && (y1 = y1a)
    y2 === missing && (y2 = y2a)
  end
  x2 <= x1 && error("Bad x range")
  y2 <= y1 && error("Bad y range")
  datasrc = datasource(;
    generate! = aggregate ? aggregate! : pointcrop!,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    xylock = xylock,
    xmin = minimum(x),
    xmax = maximum(x),
    ymin = minimum(y),
    ymax = maximum(y),
    data = hcat(x, y),
    kwargs...
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  if aggregate
    haskey(kwargs, :colormap) || (kwargs = merge(Dict((:colormap => :Greys)), kwargs))
    c = addcanvas!(HeatmapCanvas, viz, datasrc; rect=ijrect, kwargs...)
  else
    c = addcanvas!(ScatterCanvas, viz, datasrc; rect=ijrect, kwargs...)
  end
  axes && addaxes!(c; color=axescolor, grid=grid, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iscatter!(x::AbstractVector, y::AbstractVector; kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = datasource(;
    generate! = pointcrop!,
    xyrect = prev.datasrc.xyrect,
    xylock = prev.datasrc.xylock,
    data = hcat(x, y),
    kwargs...
  )
  c = addcanvas!(ScatterCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

# TODO: allow starting with a smaller view than the full z matrix
function iheatmap(z::AbstractMatrix, x1=0.0, x2=1.0, y1=0.0, y2=1.0; clim=missing, pooling=mean, axes=true, axescolor=:black, grid=false, overlay=false, cursor=false, kwargs...)
  x2 <= x1 && error("Bad x range")
  y2 <= y1 && error("Bad y range")
  clim === missing && (clim = extrema(z))
  viz = ifigure()
  datasrc = datasource(;
    generate! = (b, c) -> heatmappool!(b, c; pooling=pooling),
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    data = z,
    clim = clim,
    xmin = x1,
    xmax = x2,
    ymin = y1,
    ymax = y2,
    kwargs...
  )
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(HeatmapCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; grid=grid, color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iheatmap(f::Function, x1=0.0, x2=1.3, y1=0.0, y2=1.0; xylock=true, axes=true, axescolor=:black, grid=false, overlay=false, cursor=false, kwargs...)
  x2 <= x1 && error("Bad x range")
  y2 <= y1 && error("Bad y range")
  viz = ifigure()
  datasrc = datasource(;
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    xylock = xylock,
    kwargs...
  )
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(HeatmapCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; grid=grid, color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

### helpers

function autorange(y, margin=0.0)
  y1 = minimum(y)
  y2 = maximum(y)
  yr = y2 - y1
  if yr == 0
    y1 -= 0.5
    y2 += 0.5
  elseif margin != 0
    y1 -= margin*yr
    y2 += margin*yr
  end
  y1, y2
end

inset(r::ℛ, li, ri, bi, ti) = ℛ(left(r) + li, bottom(r) + bi, width(r) - li - ri, height(r) - bi - ti)
inset(r::Node{ℛ{T}}, li, ri, bi, ti) where T = lift(r -> ℛ(left(r) + li, bottom(r) + bi, width(r) - li - ri, height(r) - bi - ti), r)

function datasource(; kwargs...)
  dargs = Dict()
  for k ∈ fieldnames(DataSource)
    k ∈ keys(kwargs) && (dargs[k] = kwargs[k])
  end
  DataSource(; dargs...)
end
