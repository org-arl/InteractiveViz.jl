export ifigure, addcanvas!, addaxes!, addcursor!
export HeatmapCanvas, ScatterCanvas, LineCanvas

const curviz = Ref{Union{Viz,Nothing}}(nothing)

const keymap = Dict(
  :pan_left => Keyboard.left,
  :pan_right => Keyboard.right,
  :pan_up => Keyboard.up,
  :pan_down => Keyboard.down,
  :zoom_x_out => Keyboard.left_bracket,
  :zoom_x_in => Keyboard.right_bracket,
  :zoom_y_out => Keyboard.minus,
  :zoom_y_in => Keyboard.equal,
  :brightness_down => Keyboard.comma,
  :brightness_up => Keyboard.period,
  :contrast_up => Keyboard.semicolon,
  :contrast_down => Keyboard.apostrophe,
  :reset => Keyboard._0
)

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
  x = left(xyrect) + (i - left(ijrect)) * width(xyrect) / width(ijrect)
  y = bottom(xyrect) + (j - bottom(ijrect)) * height(xyrect) / height(ijrect)
  (x, y)
end

function ij2xy(p::Point2f0, c::Canvas)
  x, y = ij2xy(p[1], p[2], c)
  Point2f0(x, y)
end

function ij2xy(p::ℛ, c::Canvas)
  x1, y1 = ij2xy(left(p), bottom(p), c)
  x2, y2 = ij2xy(right(p), top(p), c)
  ℛ(x1, y1, x2-x1, y2-y1)
end

function xy2ij(x, y, c::Canvas)
  ijrect = c.ijhome[]
  xyrect = c.xyrect[]
  i = left(ijrect) + (x - left(xyrect)) * width(ijrect) / width(xyrect)
  j = bottom(ijrect) + (y - bottom(xyrect)) * height(ijrect) / height(xyrect)
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
    xscale = width(xyrect) / width(c.ijrect)
    yscale = height(xyrect) / height(c.ijrect)
    c.xyrect[] = ℛ(
      left(xyrect) + xscale*(left(c.ijhome) - left(c.ijrect)),
      bottom(xyrect) + yscale*(bottom(c.ijhome) - bottom(c.ijrect)),
      xscale * width(c.ijhome),
      yscale * height(c.ijhome)
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
    round(Int, left(ijrect) - dx[1]),
    round(Int, bottom(ijrect) + dx[2]),
    width(ijrect),
    height(ijrect)
  )
  (c.datasrc.rubberband && rubberband) || realigncanvas!(c)
  updatecanvas!(c)
end

function zoomcanvas!(c::Canvas, sx; rubberband=true)
  c.datasrc.xzoom || c.datasrc.yzoom || return
  c.datasrc.xzoom || sx[1] == 1 || (sx = [1, sx[2]])
  c.datasrc.yzoom || sx[2] == 1 || (sx = [sx[1], 1])
  ijrect = c.ijrect[]
  x0 = left(ijrect) + width(ijrect)/2
  y0 = bottom(ijrect) + height(ijrect)/2
  w = sx[1] * width(ijrect)
  h = sx[2] * height(ijrect)
  c.ijrect[] = ℛ(
    round(Int, x0 - w/2),
    round(Int, y0 - h/2),
    round(Int, w),
    round(Int, h)
  )
  (c.datasrc.rubberband && rubberband) || realigncanvas!(c)
  updatecanvas!(c)
end

function zoomcanvas!(c::Canvas, xyrect::ℛ)
  c.datasrc.xzoom || c.datasrc.yzoom || return
  c.datasrc.xpan || (xyrect = ℛ(xyrect; left=left(c.xyrect)))
  c.datasrc.ypan || (xyrect = ℛ(xyrect; bottom=bottom(c.xyrect)))
  c.datasrc.xzoom || (xyrect = ℛ(xyrect; width=width(c.xyrect)))
  c.datasrc.yzoom || (xyrect = ℛ(xyrect; height=height(c.xyrect)))
  if c.datasrc.xylock
    ratio = aspectratio(c.xyrect)
    if aspectratio(xyrect) > ratio
      xyrect = ℛ(xyrect; height=width(xyrect)/ratio)
    else
      xyrect = ℛ(xyrect; width=height(xyrect)*ratio)
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
  on(c.parent.scene.events.mousebuttons) do but
    ispressed(but, Mouse.right) && resetcanvas!(c)
  end
  on(c.parent.scene.events.keyboardbuttons) do but
    ispressed(but, keymap[:pan_left]) && pancanvas!(c, [-width(c.ijrect)/8, 0.0])
    ispressed(but, keymap[:pan_right]) && pancanvas!(c, [width(c.ijrect)/8, 0.0])
    ispressed(but, keymap[:pan_up]) && pancanvas!(c, [0.0, -height(c.ijrect)/8])
    ispressed(but, keymap[:pan_down]) && pancanvas!(c, [0.0, height(c.ijrect)/8])
    if c.datasrc.xylock
      ispressed(but, keymap[:zoom_x_out]) && zoomcanvas!(c, [1/1.2, 1/1.2])
      ispressed(but, keymap[:zoom_x_in]) && zoomcanvas!(c, [1.2, 1.2])
      ispressed(but, keymap[:zoom_y_out]) && zoomcanvas!(c,[1/1.2, 1/1.2])
      ispressed(but, keymap[:zoom_y_in]) && zoomcanvas!(c, [1.2, 1.2])
    else
      ispressed(but, keymap[:zoom_x_out]) && zoomcanvas!(c, [1/1.2, 1.0])
      ispressed(but, keymap[:zoom_x_in]) && zoomcanvas!(c, [1.2, 1.0])
      ispressed(but, keymap[:zoom_y_out]) && zoomcanvas!(c,[1.0, 1/1.2])
      ispressed(but, keymap[:zoom_y_in]) && zoomcanvas!(c, [1.0, 1.2])
    end
    ispressed(but, keymap[:brightness_down]) && brighten!(c, -0.1)
    ispressed(but, keymap[:brightness_up]) && brighten!(c, 0.1)
    ispressed(but, keymap[:contrast_down]) && contrast!(c, -0.1)
    ispressed(but, keymap[:contrast_up]) && contrast!(c, 0.1)
    ispressed(but, keymap[:reset]) && resetcanvas!(c)
  end
  on(c.parent.selrect) do r
    margin = 100
    ijrect = c.ijrect[]
    left(ijrect) - margin <= left(r) <= right(ijrect) + margin || return
    bottom(ijrect) - margin <= bottom(r) <= top(ijrect) + margin || return
    left(ijrect) - margin <= right(r) <= right(ijrect) + margin || return
    bottom(ijrect) - margin <= top(r) <= top(ijrect) + margin || return
    zoomcanvas!(c, ij2xy(r, c))
  end
end

function mkcanvas(::Type{HeatmapCanvas}, viz, ijhome, datasrc, kwargs)
  canvas = HeatmapCanvas(
    parent = viz,
    ijhome = ijhome,
    ijrect = Node(ijhome[]),
    xyrect = Node(datasrc.xyrect),
    clim = Node(datasrc.clim),
    buf = Node(zeros(Float32, width(ijhome), height(ijhome))),
    datasrc = datasrc,
    dirty = Node{Bool}(true),
    task = Ref{Task}()
  )
  x = lift(r -> left(r) : right(r), canvas.ijrect)
  y = lift(r -> bottom(r) : top(r), canvas.ijrect)
  heatmap!(viz.scene, x, y, canvas.buf; show_axis=false, colorrange=canvas.clim, kwargs...)
  on(ijhome) do r
    xscale = width(canvas.xyrect) / width(canvas.ijrect)
    yscale = height(canvas.xyrect) / height(canvas.ijrect)
    canvas.ijrect[] = r
    canvas.xyrect[] = ℛ(canvas.xyrect; width=xscale*width(canvas.ijrect), height=yscale*height(canvas.ijrect))
    canvas.buf[] = zeros(Float32, width(r), height(r))
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
  on(ijhome) do r
    canvas.ijrect[] = r
    updatecanvas!(canvas)
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
  on(ijhome) do r
    canvas.ijrect[] = r
    updatecanvas!(canvas)
  end
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

# TODO: add support for legend
# TODO: add support for colorbar

function addaxes!(c::Canvas; inset=0, color=:black, frame=false, grid=false, border=0, bordercolor=:white, xlabel=missing, ylabel=missing, xticks=5, yticks=5, ticksize=10, textsize=15.0)
  scene = c.parent.scene
  if border > 0
    poly!(scene, lift(r -> Point2f0[
      (left(r) - border, bottom(r)),
      (right(r) + border, bottom(r)),
      (right(r) + border, bottom(r) - border),
      (left(r) - border, bottom(r) - border)
    ], c.ijhome); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (left(r) - border, top(r)),
      (right(r) + border, top(r)),
      (right(r) + border, top(r) + border),
      (left(r) - border, top(r) + border)
    ], c.ijhome); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (left(r), bottom(r)),
      (left(r) - border, bottom(r)),
      (left(r) - border, top(r)),
      (left(r), top(r))
    ], c.ijhome); show_axis=false, color=bordercolor)
    poly!(scene, lift(r -> Point2f0[
      (right(r), bottom(r)),
      (right(r) + border, bottom(r)),
      (right(r) + border, top(r)),
      (right(r), top(r))
    ], c.ijhome); show_axis=false, color=bordercolor)
  end
  r = c.ijhome
  inset != 0 && (r = lift(r -> ℛ(
    left(r) + inset, bottom(r) + inset,
    width(r) - 2*inset - 1, height(r) - 2*inset - 1), c.ijhome))
  if frame
    lines!(scene, lift(r -> Point2f0[
      (right(r), bottom(r)),
      (left(r), bottom(r)),
      (left(r), top(r)),
      (right(r), top(r)),
      (right(r), bottom(r))
    ], r); show_axis=false, color=color)
  else
    lines!(scene, lift(r -> Point2f0[
      (right(r), bottom(r)),
      (left(r), bottom(r)),
      (left(r), top(r))
    ], r); show_axis=false, color=color)
  end

  lims = c.xyrect

  if xticks > 0
    # 999 is a sentinel value, since Inf is Float64
    xticks_min, xticks_max = clamp.((xticks - 2, xticks + 2), 1, 999)
    # First, we optimize in dataspace
    tick_locations_xy = lift(lims) do lims
      return first(
          PlotUtils.optimize_ticks(
          left(lims),         # minimum of x in dataspace
          right(lims);        # maximum of x in dataspace
          k_min = xticks_min, # lower bound of number of ticks
          k_ideal = xticks,   # ideal number of ticks, user provided
          k_max = xticks_max  # upper bound of number of ticks
        )
      )
    end
    # then, we switch to screen space for the (i, j) space ticks
    # which are actually drawn
    tick_locations_ij = @lift first.(xy2ij.($tick_locations_xy, 0, Ref(c)))

    # draw tick marks
    tickmark_linesegs = lift(tick_locations_ij, r) do locs, r
      [
        Point2f0(loc, bottom(r)) =>
        Point2f0(loc, bottom(r) - ticksize)
        for loc ∈ locs
      ]
    end
    linesegments!(scene, tickmark_linesegs; show_axis=false, color=color)
    # draw grid
    if grid
      grid_linesegs = lift(tick_locations_ij, r) do locs, r
        [
          Point2f0(loc, bottom(r)) =>
          Point2f0(loc, top(r))
          for loc ∈ locs
        ]
      end
      linesegments!(scene, grid_linesegs; show_axis=false, color=color, linestyle=:dot)
    end
    # ticklabel + position string
    ticklabels_positions = lift(tick_locations_xy, r) do locs, r
      return Tuple{String, Point2f0}[
        (
          formatnum(loc),
          Point2f0(
            xy2ij(loc, 0, c)[1],
            bottom(r) - ticksize - textsize/2
          )
        )
        for loc in locs
      ]
    end
    annotations!(
      scene,
      ticklabels_positions;
      textsize = textsize,
      color = color,
      align = (:center, :center)
    )
  end

  if yticks > 0
    # 999 is a sentinel value, since Inf is Float64
    yticks_min, yticks_max = clamp.((yticks - 2, yticks + 2), 1, 999)
    # First, we optimize in dataspace
    tick_locations_xy = lift(lims) do lims
      return first(
          PlotUtils.optimize_ticks(
          bottom(lims),       # minimum of y in dataspace
          top(lims);          # maximum of y in dataspace
          k_min = yticks_min, # lower bound of number of ticks
          k_ideal = yticks,   # ideal number of ticks, user provided
          k_max = yticks_max  # upper bound of number of ticks
        )
      )
    end
    # then, we switch to screen space for the (i, j) space ticks
    # which are actually drawn
    tick_locations_ij = @lift last.(xy2ij.($tick_locations_xy, 0, Ref(c)))

    # draw tick marks
    tickmark_linesegs = lift(tick_locations_ij, r) do locs, r
      [
        Point2f0(left(r), loc) =>
        Point2f0(left(r) - ticksize, loc)
        for loc ∈ locs
      ]
    end
    linesegments!(scene, tickmark_linesegs; show_axis=false, color=color)
    # draw grid
    if grid
      grid_linesegs = lift(tick_locations_ij, r) do locs, r
        [
          Point2f0(left(r),  loc) =>
          Point2f0(right(r), loc)
          for loc ∈ locs
        ]
      end
      linesegments!(scene, grid_linesegs; show_axis=false, color=color, linestyle=:dot)
    end
    # ticklabel + position string
    ticklabels_positions = lift(tick_locations_xy, r) do locs, r
      return Tuple{String, Point2f0}[
        (
          formatnum(loc),
          Point2f0(
            float(left(r) - ticksize),
            xy2ij(0, loc, c)[2]
          )
        )
        for loc in locs
      ]
    end
    annotations!(
      scene,
      ticklabels_positions;
      textsize = textsize,
      color = color,
      align = (:right, :center)
    )
  end

  # TODO: remove hardcoded 50 and 75
  xlabel === missing || text!(scene, xlabel; position=lift(r ->
    (left(r) + width(r)/2 - 50, bottom(r) - 4*ticksize - textsize), r),
    textsize=textsize, color=color, align=(:center, :bottom))
  ylabel === missing || text!(scene, ylabel; position=lift(r ->
      (left(r) - 75, bottom(r) + height(r)÷2), r),
      textsize=textsize, color=color, align=(:center, :top), rotation=π/2)
  nothing
end

function addcursor!(c::Canvas; position=nothing, color=:black, textsize=15.0, align=(:center, :center))
  if position === nothing
    position = lift(r -> (right(r) - 20, top(r) - 20), c.ijhome)
    align=(:right, :top)
  end
  s = Node(" ")
  text!(c.parent.scene, s; position=position, align=align, textsize=textsize, color=color)
  on(c.parent.scene.events.mouseposition) do ij
    if left(c.ijhome) <= ij[1] <= right(c.ijhome) && bottom(c.ijhome) <= ij[2] <= top(c.ijhome)
      x, y = ij2xy(ij[1], ij[2], c)
      if c isa HeatmapCanvas
        try
          s[] = formatnums(x, y, c.buf[][round(Int, ij[1] - left(c.ijhome)) + 1, round(Int, ij[2] - bottom(c.ijhome)) + 1])
        catch
          s[] = " "
        end
      else
        s[] = formatnums(x, y)
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

function formatnums(x...)
  s = ""
  for x1 ∈ x
    length(s) > 0 && (s *= ", ")
    s *= formatnum(x1)
  end
  " " * s * " "
end

function formatnum(x)
  x == 0 && return "0"
  abs(x) > 10000 && return @sprintf("%.0e", x)
  abs(x) >= 100 && return @sprintf("%.0f", x)
  abs(x) >= 10 && return @sprintf("%.1f", x)
  abs(x) >= 1 && return @sprintf("%.2f", x)
  abs(x) < 0.001 && return @sprintf("%.0e", x)
  @sprintf("%.3f", x)
end
