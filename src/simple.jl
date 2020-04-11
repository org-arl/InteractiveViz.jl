export iplot, iplot!, iscatter, iscatter!, iheatmap

# TODO: add support for multichannel plots
# TODO: add support for SignalBuf

iplot(y::AbstractVector; kwargs...) = iplot(1:length(y), y; kwargs...)
iplot!(y::AbstractVector; kwargs...) = iplot!(1:length(y), y; kwargs...)

function iplot(x::AbstractVector, y::AbstractVector, x1=missing, x2=missing, y1=missing, y2=missing; axes=true, axescolor=:black, overlay=false, cursor=false, kwargs...)
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
  datasrc = DataSource(
    generate! = subset!,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    data = hcat(x, y),
    xmin = minimum(x),
    xmax = maximum(x)
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(LineCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iplot!(x::AbstractVector, y::AbstractVector; kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = DataSource(
    generate! = subset!,
    xyrect = prev.datasrc.xyrect,
    data = hcat(x, y),
    xmin = minimum(x),
    xmax = maximum(x)
  )
  c = addcanvas!(LineCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

function iplot(f::Function, x1=0.0, x2=1.0, y1=missing, y2=missing; axes=true, axescolor=:black, overlay=false, cursor=false, data=missing, kwargs...)
  x2 <= x1 && error("Bad x range")
  if y1 === missing || y2 === missing
    y1a, y2a = autorange(f.(x1 .+ rand(1000)*(x2-x1)), 0.1)
    y1 === missing && (y1 = y1a)
    y2 === missing && (y2 = y2a)
  end
  y2 <= y1 && error("Bad y range")
  datasrc = DataSource(
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    data = data
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(LineCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iplot!(f::Function; data=missing, kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = DataSource(
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = prev.datasrc.xyrect,
    data = data
  )
  c = addcanvas!(LineCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

function iscatter(x::AbstractVector, y::AbstractVector, x1=missing, x2=missing, y1=missing, y2=missing; axes=true, axescolor=:black, overlay=false, cursor=false, kwargs...)
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
  datasrc = DataSource(
    generate! = subset!,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    data = hcat(x, y),
    xmin = minimum(x),
    xmax = maximum(x),
    ymin = minimum(y),
    ymax = maximum(y)
  )
  viz = ifigure()
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(ScatterCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
  cursor && addcursor!(c, color=axescolor)
  c
end

function iscatter!(x::AbstractVector, y::AbstractVector; kwargs...)
  viz = ifigure(hold=true)
  length(viz.children) == 0 && error("No previous canvas available to plot over")
  prev = viz.children[end]
  datasrc = DataSource(
    generate! = subset!,
    xyrect = prev.datasrc.xyrect,
    data = hcat(x, y),
    xmin = minimum(x),
    xmax = maximum(x),
    ymin = minimum(y),
    ymax = maximum(y)
  )
  c = addcanvas!(ScatterCanvas, viz, datasrc; rect=prev.ijrect, kwargs...)
  c.xyrect[] = prev.xyrect[]
  c
end

function iheatmap(z::AbstractMatrix)
  # TODO
end

function iheatmap(f::Function, x1=0.0, x2=1.3, y1=0.0, y2=1.0; axes=true, axescolor=:black, overlay=false, cursor=false, data=missing, kwargs...)
  x2 <= x1 && error("Bad x range")
  y2 <= y1 && error("Bad y range")
  viz = ifigure()
  datasrc = DataSource(
    generate! = (b, c) -> apply!(f, b, c),
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1),
    data = data
  )
  ijrect = axes && !overlay ? inset(viz.ijrect, 100, 50, 100, 50) : viz.ijrect
  c = addcanvas!(HeatmapCanvas, viz, datasrc; rect=ijrect, kwargs...)
  axes && addaxes!(c; color=axescolor, inset = overlay ? 100 : 0, border = overlay ? 0 : 150)
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

inset(r::ℛ, left, right, bottom, top) = ℛ(r.left + left, r.bottom + bottom, r.width - left - right, r.height - bottom - top)
inset(r::Node{ℛ{T}}, left, right, bottom, top) where T = lift(r -> ℛ(r.left + left, r.bottom + bottom, r.width - left - right, r.height - bottom - top), r)
