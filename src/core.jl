export ifigure, addcanvas!, addaxes!, addcursor!
export HeatmapCanvas, ScatterCanvas, LineCanvas

const curviz = Ref{Union{Viz,Nothing}}(nothing)

function ifigure(; width=1024, height=768, hold=false, show=true)
  hold && curviz[] !== nothing && return curviz[]
  curviz[] = Viz(
    scene = Scene(resolution=(width,height), camera=campixel!),
    ijrect = Node(ℛ(0, 0, width, height)),
    selrect = Node(ℛ(0, 0, width, height)),
    children = Canvas[]
  )
  show && display(curviz[].scene)
  on(curviz[].scene.events.window_area) do win
    curviz[].ijrect[] = ℛ(win.origin[1], win.origin[2], win.widths[1], win.widths[2])
  end
  on(curviz[].scene.events.window_open) do b
    b || (curviz[] = nothing)
  end
  on(select_rectangle(curviz[].scene)) do r
    curviz[].selrect[] = ℛ(
      round(Int, r.origin[1]),
      round(Int, r.origin[2]),
      round(Int, r.widths[1]),
      round(Int, r.widths[2]))
  end
  curviz[]
end

function ij2xy(i, j, c::Canvas)
  ijrect = c.ijhome[]
  xyrect = c.xyrect[]
  x = (i - ijrect.left) * xyrect.width / (ijrect.width-1) + xyrect.left
  y = (j - ijrect.bottom) * xyrect.height / (ijrect.height-1) + xyrect.bottom
  (x, y)
end

function ij2xy(p::Point2f0, c::Canvas)
  x, y = ij2xy(p[1], p[2], c)
  Point2f0(x, y)
end

function ij2xy(p::ℛ, c::Canvas)
  x1, y1 = ij2xy(p.left, p.bottom, c)
  x2, y2 = ij2xy(p.left + p.width, p.bottom + p.height, c)
  ℛ(x1, y1, x2-x1, y2-y1)
end

function xy2ij(x, y, c::Canvas)
  ijrect = c.ijhome[]
  xyrect = c.xyrect[]
  i = (x - xyrect.left) * (ijrect.width-1) / xyrect.width + ijrect.left
  j = (y - xyrect.bottom) * (ijrect.height-1) / xyrect.height + ijrect.bottom
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

function updatecanvas!(c::Canvas; invalidate=true, delay=0.1, first=false)
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

function pancanvas!(c::Canvas, dx; rubberband=true)
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
  (c.datasrc.rubberband && rubberband) || realigncanvas!(c)
  updatecanvas!(c)
end

function zoomcanvas!(c::Canvas, sx; rubberband=true)
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
  (c.datasrc.rubberband && rubberband) || realigncanvas!(c)
  updatecanvas!(c)
end

function zoomcanvas!(c::Canvas, xyrect::ℛ)
  c.datasrc.xzoom || c.datasrc.yzoom || return
  c.datasrc.xzoom || (xyrect = ℛ(c.xyrect[].left, xyrect.bottom, c.xyrect[].width, xyrect.height))
  c.datasrc.yzoom || (xyrect = ℛ(xyrect.left, c.xyrect[].bottom, xyrect.width, c.xyrect[].height))
  if c.datasrc.xylock
    ratio = c.xyrect[].width / c.xyrect[].height
    if xyrect.width / xyrect.height > ratio
      xyrect = ℛ(xyrect.left, xyrect.bottom, xyrect.width, xyrect.width / ratio)
    else
      xyrect = ℛ(xyrect.left, xyrect.bottom, xyrect.height * ratio, xyrect.height)
    end
  end
  c.xyrect[] = xyrect
  updatecanvas!(c)
end

function brighten!(c::Canvas, dx)
  isdefined(c, :clim) || return
  clim = c.clim[]
  r = clim[2] - clim[1]
  c.clim[] = clim .- r*dx
end

function contrast!(c::Canvas, dx)
  isdefined(c, :clim) || return
  clim = c.clim[]
  r = clim[2] - clim[1]
  clim = clim .- [-r*dx, r*dx]
  clim[2] > clim[1] && (c.clim[] = (clim[1], clim[2]))
end

function resetcanvas!(c::Canvas)
  c.xyrect[] = c.datasrc.xyrect
  isdefined(c, :clim) && (c.clim[] = c.datasrc.clim)
  updatecanvas!(c; delay=0)
end

function bindevents!(c::Canvas)
  on(c.parent.scene.events.scroll) do dx
    pancanvas!(c, dx)
  end
  on(c.parent.scene.events.keyboardbuttons) do but
    ispressed(but, Keyboard.left) && pancanvas!(c, [-c.ijrect[].width/8, 0.0])
    ispressed(but, Keyboard.right) && pancanvas!(c, [c.ijrect[].width/8, 0.0])
    ispressed(but, Keyboard.up) && pancanvas!(c, [0.0, -c.ijrect[].height/8])
    ispressed(but, Keyboard.down) && pancanvas!(c, [0.0, c.ijrect[].width/8])
    if c.datasrc.xylock
      ispressed(but, Keyboard.left_bracket) && zoomcanvas!(c, [1/1.2, 1/1.2])
      ispressed(but, Keyboard.right_bracket) && zoomcanvas!(c, [1.2, 1.2])
      ispressed(but, Keyboard.minus) && zoomcanvas!(c,[1/1.2, 1/1.2])
      ispressed(but, Keyboard.equal) && zoomcanvas!(c, [1.2, 1.2])
    else
      ispressed(but, Keyboard.left_bracket) && zoomcanvas!(c, [1/1.2, 1.0])
      ispressed(but, Keyboard.right_bracket) && zoomcanvas!(c, [1.2, 1.0])
      ispressed(but, Keyboard.minus) && zoomcanvas!(c,[1.0, 1/1.2])
      ispressed(but, Keyboard.equal) && zoomcanvas!(c, [1.0, 1.2])
    end
    ispressed(but, Keyboard.comma) && brighten!(c, -0.1)
    ispressed(but, Keyboard.period) && brighten!(c, 0.1)
    ispressed(but, Keyboard.semicolon) && contrast!(c, -0.1)
    ispressed(but, Keyboard.apostrophe) && contrast!(c, 0.1)
    ispressed(but, Keyboard._0) && resetcanvas!(c)
  end
  on(c.parent.selrect) do r
    margin = 100
    ijrect = c.ijrect[]
    ijrect.left - margin <= r.left <= ijrect.left + ijrect.width + margin || return
    ijrect.bottom - margin <= r.bottom <= ijrect.bottom + ijrect.height + margin || return
    ijrect.left - margin <= r.left + r.width <= ijrect.left + ijrect.width + margin || return
    ijrect.bottom - margin <= r.bottom + r.height <= ijrect.bottom + ijrect.height + margin || return
    xyrect = ij2xy(r, c)
    zoomcanvas!(c, xyrect)
  end
end

function mkcanvas(::Type{HeatmapCanvas}, viz, ijhome, datasrc, kwargs)
  canvas = HeatmapCanvas(
    parent = viz,
    ijhome = ijhome,
    ijrect = Node(ijhome[]),
    xyrect = Node(datasrc.xyrect),
    clim = Node(datasrc.clim),
    buf = Node(zeros(Float32, ijhome[].width, ijhome[].height)),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  x = lift(r -> r.left : (r.left + r.width - 1), canvas.ijrect)
  y = lift(r -> r.bottom : (r.bottom + r.height - 1), canvas.ijrect)
  heatmap!(viz.scene, x, y, canvas.buf; show_axis=false, colorrange=canvas.clim, kwargs...)
  on(ijhome) do r
    xscale = canvas.xyrect[].width/canvas.ijrect[].width
    yscale = canvas.xyrect[].height/canvas.ijrect[].height
    canvas.ijrect[] = r
    canvas.xyrect[] = ℛ(
      canvas.xyrect[].left, canvas.xyrect[].bottom,
      xscale * canvas.ijrect[].width, yscale * canvas.ijrect[].height)
    canvas.buf[] = zeros(Float32, r.width, r.height)
    updatecanvas!(canvas)
  end
  canvas
end

function mkcanvas(::Type{ScatterCanvas}, viz, ijhome, datasrc, kwargs)
  canvas = ScatterCanvas(
    parent = viz,
    ijhome = ijhome,
    ijrect = Node(ijhome[]),
    xyrect = Node(datasrc.xyrect),
    buf = Node(Point2f0[]),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  if :markersize ∈ keys(kwargs)
    scatter!(viz.scene, canvas.buf; show_axis=false, kwargs...)
  else
    scatter!(viz.scene, canvas.buf; show_axis=false, markersize=1, kwargs...)
  end
  canvas
end

function mkcanvas(::Type{LineCanvas}, viz, ijhome, datasrc, kwargs)
  canvas = LineCanvas(
    parent = viz,
    ijhome = ijhome,
    ijrect = Node(ijhome[]),
    xyrect = Node(datasrc.xyrect),
    buf = Node(Point2f0[(Inf32, Inf32)]),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  lines!(viz.scene, canvas.buf; show_axis=false, kwargs...)
  canvas
end

function addcanvas!(ctype, viz::Viz, datasrc::DataSource; rect=nothing, kwargs...)
  if rect === nothing
    ijhome = lift(r -> r, viz.ijrect)
  elseif rect isa ℛ
    ijhome = Node(rect)
  elseif rect isa Node
    ijhome = rect
  else
    ijhome = Node(ℛ(rect[1], rect[2], rect[3], rect[4]))
  end
  canvas = mkcanvas(ctype, viz, ijhome, datasrc, kwargs)
  push!(viz.children, canvas)
  bindevents!(canvas)
  isopen(viz.scene) && updatecanvas!(canvas; first=true, delay=0)
  canvas
end

# TODO: add support for xlabel, ylabel, title
# TODO: add support for legend
# TODO: add support for colorbar
# TODO: improve tick formatting

function addaxes!(c::Canvas; inset=0, color=:black, frame=false, grid=false, border=0, bordercolor=:white, xticks=5, yticks=5, ticksize=10, textsize=15.0)
  scene = c.parent.scene
  r = lift(r -> ℛ(r.left, r.bottom, r.width-1, r.height-1), c.ijhome)
  if border > 0
    poly!(scene, lift(r -> Point2f0[
      (r.left - border, r.bottom),
      (r.left + r.width + border, r.bottom),
      (r.left + r.width + border, r.bottom - border),
      (r.left - border, r.bottom - border)
    ], r); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (r.left - border, r.bottom + r.height),
      (r.left + r.width + border, r.bottom + r.height),
      (r.left + r.width + border, r.bottom + r.height + border),
      (r.left - border, r.bottom + r.height + border)
    ], r); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (r.left, r.bottom),
      (r.left - border, r.bottom),
      (r.left - border, r.bottom + r.height),
      (r.left, r.bottom + r.height)
    ], r); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (r.left + r.width, r.bottom),
      (r.left + r.width + border, r.bottom),
      (r.left + r.width + border, r.bottom + r.height),
      (r.left + r.width, r.bottom + r.height)
    ], r); show_axis=false, color=bordercolor)
  end
  inset != 0 && (r = lift(r -> ℛ(
    r.left + inset, r.bottom + inset,
    r.width - 2*inset - 1, r.height - 2*inset - 1), c.ijhome))
  if frame
    lines!(scene, lift(r -> Point2f0[
      (r.left + r.width, r.bottom),
      (r.left, r.bottom),
      (r.left, r.bottom + r.height),
      (r.left + r.width, r.bottom + r.height),
      (r.left + r.width, r.bottom)
    ], r); show_axis=false, color=color)
  else
    lines!(scene, lift(r -> Point2f0[
      (r.left + r.width, r.bottom),
      (r.left, r.bottom),
      (r.left, r.bottom + r.height)
    ], r); show_axis=false, color=color)
  end
  xticktext(i, c) = @sprintf(" %.3f ", ij2xy(i, 0, c)[1])
  if xticks > 0
    linesegments!(scene, lift(r -> [
      Point2f0(r.left + k * r.width / xticks, r.bottom) =>
      Point2f0(r.left + k * r.width / xticks, r.bottom - ticksize)
      for k ∈ 0:xticks
    ], r); show_axis=false, color=color)
    grid && linesegments!(scene, lift(r -> [
      Point2f0(r.left + k * r.width / xticks, r.bottom) =>
      Point2f0(r.left + k * r.width / xticks, r.bottom + r.height)
      for k ∈ 0:xticks
    ], r); show_axis=false, color=color, linestyle=:dot)
    for k ∈ 0:xticks
      text!(scene, lift((r, xy) -> xticktext(r.left + k * r.width / xticks, c), r, c.xyrect);
        position=lift(r -> (r.left + k * r.width / xticks, r.bottom - ticksize - textsize/2), r),
        textsize=textsize, color=color,
        align=(:center, :center))
    end
  end
  yticktext(j, c) = @sprintf(" %.3f ", ij2xy(0, j, c)[2])
  if yticks > 0
    linesegments!(scene, lift(r -> [
      Point2f0(r.left, r.bottom + k * r.height / yticks) =>
      Point2f0(r.left - ticksize, r.bottom + k * r.height / yticks)
      for k ∈ 0:yticks
    ], r); show_axis=false, color=color)
    grid && linesegments!(scene, lift(r -> [
      Point2f0(r.left, r.bottom + k * r.height / yticks) =>
      Point2f0(r.left + r.width, r.bottom + k * r.height / yticks)
      for k ∈ 0:yticks
    ], r); show_axis=false, color=color, linestyle=:dot)
    for k ∈ 0:yticks
      text!(scene, lift((r, xy) -> yticktext(r.bottom + k * r.height / yticks, c), r, c.xyrect);
        position=lift(r -> (float(r.left - ticksize), r.bottom + k * r.height / yticks), r),
        textsize=textsize, color=color,
        align=(:right, :center))
    end
  end
  nothing
end

function addcursor!(c::Canvas; position=nothing, color=:black, textsize=15.0, align=(:center, :center))
  if position === nothing
    position = lift(r -> (r.left + r.width - 20, r.bottom + r.height - 20), c.ijhome)
    align=(:right, :top)
  end
  s = Node(" ")
  text!(c.parent.scene, s; position=position, align=align, textsize=textsize, color=color)
  on(c.parent.scene.events.mouseposition) do ij
    if c.ijhome[].left <= ij[1] < c.ijhome[].left + c.ijhome[].width &&
       c.ijhome[].bottom <= ij[2] < c.ijhome[].bottom + c.ijhome[].height
      x, y = ij2xy(ij[1], ij[2], c)
      if c isa HeatmapCanvas
        try
          s[] = @sprintf(" %.3f, %.3f, %.3f ", x, y, c.buf[][round(Int, ij[1])+1, round(Int, ij[2])+1])
        catch
          s[] = " "
        end
      else
        s[] = @sprintf(" %.3f, %.3f ", x, y)
      end
    else
      s[] = " "
    end
  end
  on(c.parent.scene.events.entered_window) do b
    b || (s[] = " ")
  end
  nothing
end
