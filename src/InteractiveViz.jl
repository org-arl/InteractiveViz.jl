module InteractiveViz

using Makie

export iviz, addcanvas!, datasource, HeatmapCanvas, ScatterCanvas, apply!

include("demo.jl")

# represents a rectangle
struct ℛ{T}
  left::T
  bottom::T
  width::T
  height::T
end

abstract type Canvas end

Base.@kwdef struct DataSource
  generate!::Function
  xyrect::ℛ{Float64}       # default extents in data coordinates
  data = missing
  rubberband::Bool = true
  clim::Tuple = (0.0, 1.0) # default color limits
  xmin::Float64 = -Inf64
  xmax::Float64 = Inf64
  ymin::Float64 = -Inf64
  ymax::Float64 = Inf64
  cmin::Float64 = -Inf64
  cmax::Float64 = Inf64
  xpan::Bool = true
  ypan::Bool = true
  cpan::Bool = true
  xzoom::Bool = true
  yzoom::Bool = true
  czoom::Bool = true
  minwidth::Float64 = 0
  maxwidth::Float64 = Inf64
  minheight::Float64 = 0
  maxheight::Float64 = Inf64
end

Base.@kwdef struct Viz
  scene::Scene
  ijrect::Node{ℛ{Int}}       # size of window in pixels
  children::Vector{Canvas}
end

function Base.show(io::IO, viz::Viz)
  display(viz.scene)
  for c ∈ viz.children
    updatecanvas!(c; first=true, delay=0)
  end
end

function Base.show(io::IO, c::Canvas)
  println(io, typeof(c))
end

Base.@kwdef struct HeatmapCanvas <: Canvas
  parent::Viz
  ijhome::Node{ℛ{Int}}       # home location for canvas in pixels
  ijrect::Node{ℛ{Int}}       # current location for canvas in pixels
  xyrect::Node{ℛ{Float64}}   # canvas extents in data coordinates
  clim::Node{Tuple}
  buf::Node{Matrix{Float32}}
  datasrc::DataSource
  dirty::Node{Bool}
  task::Ref{Task}
end

Base.@kwdef struct ScatterCanvas <: Canvas
  parent::Viz
  ijhome::Node{ℛ{Int}}       # home location for canvas in pixels
  ijrect::Node{ℛ{Int}}       # current location for canvas in pixels
  xyrect::Node{ℛ{Float64}}   # canvas extents in data coordinates
  buf::Node{Vector{Point2f0}}
  datasrc::DataSource
  dirty::Node{Bool}
  task::Ref{Task}
end

function ij2xy(i, j, c::Canvas)
  ijrect = c.ijrect[]
  xyrect = c.xyrect[]
  x = (i - ijrect.left) * xyrect.width / ijrect.width + xyrect.left
  y = (j - ijrect.bottom) * xyrect.height / ijrect.height + xyrect.bottom
  (x, y)
end

function ij2xy(p::Point2f0, c::Canvas)
  x, y = ij2xy(p[1], p[2], c)
  Point2f0(x, y)
end

function xy2ij(x, y, c::Canvas)
  ijrect = c.ijrect[]
  xyrect = c.xyrect[]
  i = (x - xyrect.left) * ijrect.width / xyrect.width + ijrect.left
  j = (y - xyrect.bottom) * ijrect.height / xyrect.height + ijrect.bottom
  (i, j)
end

function xy2ij(p::Point2f0, c::Canvas)
  i, j = xy2ij(p[1], p[2], c)
  Point2f0(i, j)
end

function xy2ij(dtype::DataType, x, y, c::Canvas)
  i, j = xy2ij(x, y, c)
  (round(dtype, i), round(dtype, j))
end

function applyconstraints!(c::Canvas)
  # TODO: apply constraints xmin, xmax, ymin, ymax, cmin, cmax
  # TODO: apply constraints minwidth, maxwidth, minheight, maxheight
end

function realigncanvas!(c::Canvas)
  if c.ijhome[] != c.ijrect[]
    xyrect = c.xyrect[]
    xscale = xyrect.width / c.ijrect[].width
    yscale = xyrect.height / c.ijrect[].height
    c.xyrect[] = ℛ(
      xyrect.left + xscale*(c.ijhome[].left - c.ijrect[].left),
      xyrect.bottom + yscale*(c.ijhome[].bottom - c.ijrect[].bottom),
      xscale * c.ijhome[].width,
      yscale * c.ijhome[].height
    )
    c.ijrect[] = c.ijhome[]
  end
end

function updatecanvas!(c::Canvas; invalidate=true, delay=0, first=false)
  invalidate && (c.dirty[] = true)
  isopen(c.parent.scene) || return
  c.dirty[] || return
  first || c.task[].state === :done || return
  c.task[] = @async begin
    sleep(delay)
    realigncanvas!(c)
    applyconstraints!(c)
    c.datasrc.generate!(c.buf[], c)
    c.buf[] = c.buf[]  # force observable triggers
    c.dirty[] = false
  end
end

function pancanvas!(c::Canvas, dx)
  c.datasrc.xpan || c.datasrc.ypan || return
  c.datasrc.xpan || dx[1] == 0 || (dx = [0, dx[2]])
  c.datasrc.ypan || dx[2] == 0 || (dx = [dx[1], 0])
  ijrect = c.ijrect[]
  c.ijrect[] = ℛ(
    round(Int, ijrect.left - dx[1]),
    round(Int, ijrect.bottom + dx[2]),
    ijrect.width,
    ijrect.height
  )
  c.datasrc.rubberband || realign!(c)
  updatecanvas!(c)
end

function zoomcanvas!(c::Canvas, sx)
  c.datasrc.xzoom || c.datasrc.yzoom || return
  c.datasrc.xzoom || sx[1] == 1 || (sx = [1, sx[2]])
  c.datasrc.yzoom || sx[2] == 1 || (sx = [sx[1], 1])
  ijrect = c.ijrect[]
  x0 = ijrect.left + ijrect.width/2
  y0 = ijrect.bottom + ijrect.height/2
  width = sx[1] * ijrect.width
  height = sx[2] * ijrect.height
  c.ijrect[] = ℛ(
    round(Int, x0 - width/2),
    round(Int, y0 - height/2),
    round(Int, width),
    round(Int, height)
  )
  c.datasrc.rubberband || realign!(c)
  updatecanvas!(c)
end

function brighten!(c::Canvas, dx)
  isdefined(c, :clim) || return
  clim = c.clim[]
  r = clim[2] - clim[1]
  c.clim[] = clim .+ r*dx
end

function contrast!(c::Canvas, dx)
  isdefined(c, :clim) || return
  clim = c.clim[]
  r = clim[2] - clim[1]
  clim = clim .+ [-r*dx, r*dx]
  clim[2] > clim[1] && (c.clim[] = (clim[1], clim[2]))
end

function resetcanvas!(c::Canvas)
  c.xyrect[] = c.datasrc.xyrect
  isdefined(c, :clim) && (c.clim[] = c.datasrc.clim)
  updatecanvas!(c; delay=0)
end

function bindevents!(c::Canvas)
  on(c.parent.scene.events.window_area) do win
    if c.ijhome[].left == 0 && c.ijhome[].bottom == 0
      xyrect = c.xyrect[]
      xscale = xyrect.width / c.ijrect[].width
      yscale = xyrect.height / c.ijrect[].height
      c.ijhome[] = ℛ(win.origin[1], win.origin[2], win.widths[1], win.widths[2])
      c.ijrect[] = c.ijhome[]
      c.xyrect[] = ℛ(xyrect.left, xyrect.bottom, xscale*win.widths[1], yscale*win.widths[2])
      updatecanvas!(c)
    end
  end
  on(c.parent.scene.events.scroll) do dx
    pancanvas!(c, dx)
  end
  on(c.parent.scene.events.keyboardbuttons) do but
    ispressed(but, Keyboard.left) && pancanvas!(c, [-c.ijrect[].width/8, 0.0])
    ispressed(but, Keyboard.right) && pancanvas!(c, [c.ijrect[].width/8, 0.0])
    ispressed(but, Keyboard.up) && pancanvas!(c, [0.0, -c.ijrect[].height/8])
    ispressed(but, Keyboard.down) && pancanvas!(c, [0.0, c.ijrect[].width/8])
    ispressed(but, Keyboard.left_bracket) && zoomcanvas!(c, [1/1.2, 1/1.2])
    ispressed(but, Keyboard.right_bracket) && zoomcanvas!(c, [1.2, 1.2])
    ispressed(but, Keyboard.equal) && brighten!(c, -0.1)
    ispressed(but, Keyboard.minus) && brighten!(c, 0.1)
    ispressed(but, Keyboard.period) && contrast!(c, -0.1)
    ispressed(but, Keyboard.comma) && contrast!(c, 0.1)
    ispressed(but, Keyboard._0) && resetcanvas!(c)
  end
end

function addcanvas!(::Type{HeatmapCanvas}, viz::Viz, datasrc::DataSource; pos=nothing, kwargs...)
  width = viz.ijrect[].width
  height = viz.ijrect[].height
  if pos === nothing
    ijhome = ℛ(0, 0, width, height)
  elseif pos isa ℛ
    ijhome = pos
  else
    ijhome = ℛ(pos[1], pos[2], pos[3], pos[4])
  end
  canvas = HeatmapCanvas(
    parent = viz,
    ijhome = Node(ijhome),
    ijrect = Node(ijhome),
    xyrect = Node(datasrc.xyrect),
    clim = Node(datasrc.clim),
    buf = Node(zeros(Float32, width, height)),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  push!(viz.children, canvas)
  x = lift(r -> r.left : (r.left + r.width - 1), canvas.ijrect)
  y = lift(r -> r.bottom : (r.bottom + r.height - 1), canvas.ijrect)
  heatmap!(viz.scene, x, y, canvas.buf; show_axis=false, colorrange=canvas.clim, kwargs...)
  bindevents!(canvas)
  canvas
end

function addcanvas!(::Type{ScatterCanvas}, viz::Viz, datasrc::DataSource; pos=nothing, kwargs...)
  width = viz.ijrect[].width
  height = viz.ijrect[].height
  if pos === nothing
    ijhome = ℛ(0, 0, width, height)
  elseif pos isa ℛ
    ijhome = pos
  else
    ijhome = ℛ(pos[1], pos[2], pos[3], pos[4])
  end
  canvas = ScatterCanvas(
    parent = viz,
    ijhome = Node(ijhome),
    ijrect = Node(ijhome),
    xyrect = Node(datasrc.xyrect),
    buf = Node(Vector{Point2f0}()),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  push!(viz.children, canvas)
  scatter!(viz.scene, canvas.buf; show_axis=false, markersize=1, kwargs...)
  bindevents!(canvas)
  canvas
end

function iviz(; width=800, height=600)
  scene = Scene(resolution=(width,height), camera=campixel!)
  Viz(
    scene = scene,
    ijrect = Node(ℛ(0, 0, width, height)),
    children = Vector{Canvas}()
  )
end

function datasource(f, x1, y1, x2, y2; kwargs...)
  DataSource(
    generate! = f,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1);
    kwargs...
  )
end

function apply!(f::Function, buf, canvas::Canvas)
  for j ∈ 1:size(buf,2)
    for i ∈ 1:size(buf,1)
      x, y = ij2xy(i, j, canvas)
      buf[i,j] = f(x, y)
    end
  end
end

end # module
