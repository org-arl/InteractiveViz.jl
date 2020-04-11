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
  xylock::Bool = false
  minwidth::Float64 = 0
  maxwidth::Float64 = Inf64
  minheight::Float64 = 0
  maxheight::Float64 = Inf64
end

Base.@kwdef struct Viz
  scene::Scene
  ijrect::Node{ℛ{Int}}       # size of window in pixels
  selrect::Node{ℛ{Int}}      # last selected rectangle
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

Base.@kwdef struct LineCanvas <: Canvas
  parent::Viz
  ijhome::Node{ℛ{Int}}       # home location for canvas in pixels
  ijrect::Node{ℛ{Int}}       # current location for canvas in pixels
  xyrect::Node{ℛ{Float64}}   # canvas extents in data coordinates
  buf::Node{Vector{Point2f0}}
  datasrc::DataSource
  dirty::Node{Bool}
  task::Ref{Task}
end

Base.show(io::IO, x::Viz) = println(io, typeof(x))
Base.show(io::IO, x::Canvas) = println(io, typeof(x))
