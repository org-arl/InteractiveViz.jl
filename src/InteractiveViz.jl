module InteractiveViz

using Makie

export iviz, datasource, HeatmapCanvas

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
  canvastype::Type
  generate!::Function
  xyrect::ℛ{Float64}       # default extents in data coordinates
  xmin::Float64 = -Inf64
  xmax::Float64 = Inf64
  ymin::Float64 = -Inf64
  ymax::Float64 = Inf64
  cmin::Float64 = 0.0
  cmax::Float64 = 1.0
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

function applyconstraints!(c)
  # TODO: apply constraints xmin, xmax, ymin, ymax, cmin, cmax
  # TODO: apply constraints minwidth, maxwidth, minheight, maxheight
end

function update!(c::Canvas; invalidate=true, delay=0.25, first=false)
  invalidate && (c.dirty[] = true)
  !isopen(c.parent.scene) && return
  !c.dirty[] && return
  !first && c.task[].state !== :done && return
  c.task[] = @async begin
    sleep(delay)
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
    applyconstraints!(c)
    c.datasrc.generate!(c.buf[], c.xyrect[])
    c.buf[] = c.buf[]  # force observable triggers
    c.dirty[] = false
  end
end

function pancanvas!(c, dx)
  !c.datasrc.xpan && !c.datasrc.ypan && return
  !c.datasrc.xpan && dx[1] != 0 && (dx = [0, dx[2]])
  !c.datasrc.ypan && dx[2] != 0 && (dx = [dx[1], 0])
  ijrect = c.ijrect[]
  c.ijrect[] = ℛ(
    round(Int, ijrect.left - dx[1]),
    round(Int, ijrect.bottom + dx[2]),
    ijrect.width,
    ijrect.height
  )
  update!(c)
end

function zoomcanvas!(c, sx)
  !c.datasrc.xzoom && !c.datasrc.yzoom && return
  !c.datasrc.xzoom && sx[1] != 1 && (sx = [1, sx[2]])
  !c.datasrc.yzoom && sx[2] != 1 && (sx = [sx[1], 1])
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
  update!(c)
end

function resetcanvas!(c)
  c.xyrect[] = c.datasrc.xyrect
  update!(c; delay=0)
end

function bindevents!(c)
  on(c.parent.scene.events.window_area) do win
    xyrect = c.xyrect[]
    xscale = xyrect.width / c.ijrect[].width
    yscale = xyrect.height / c.ijrect[].height
    c.ijhome[] = ℛ(win.origin[1], win.origin[2], win.widths[1], win.widths[2])
    c.ijrect[] = c.ijhome[]
    c.xyrect[] = ℛ(xyrect.left, xyrect.bottom, xscale*win.widths[1], yscale*win.widths[2])
    update!(c)
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
    ispressed(but, Keyboard._0) && resetcanvas!(c)
  end
end

function iviz(datasrc; width=800, height=600)
  scene = Scene(resolution=(width,height), camera=campixel!)
  viz = Viz(
    scene = scene,
    ijrect = Node(ℛ(0, 0, width, height)),
    children = Vector{Canvas}()
  )
  canvas = datasrc.canvastype(
    parent = viz,
    ijhome = Node(ℛ(0, 0, width, height)),
    ijrect = Node(ℛ(0, 0, width, height)),
    xyrect = Node(datasrc.xyrect),
    clim = Node((datasrc.cmin, datasrc.cmax)),
    buf = Node(zeros(Float32, width, height)),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  push!(viz.children, canvas)
  x = lift(r -> r.left : (r.left + r.width - 1), canvas.ijrect)
  y = lift(r -> r.bottom : (r.bottom + r.height - 1), canvas.ijrect)
  heatmap!(scene, x, y, canvas.buf; show_axis=false, colorrange=canvas.clim)
  bindevents!(canvas)
  display(scene)
  update!(canvas; first=true, delay=0)
  viz
end

function datasource(::Type{HeatmapCanvas}, f, x1, y1, x2, y2)
  DataSource(
    canvastype = HeatmapCanvas,
    generate! = f,
    xyrect = ℛ{Float64}(x1, y1, x2-x1, y2-y1)
  )
end

end # module
