using GeometryBasics
using Statistics

###############################
### interface
###############################

abstract type DataSource end

abstract type PointSet <: DataSource end
abstract type Continuous1D <: DataSource end
abstract type Continuous2D <: DataSource end

"""
    sample(data::DataSource, xrange::StepRangeLen, yrange::StepRangeLen)

Samples the datasource at a finite resolution and within a viewport represented
by a `xrange` and `yrange`, and return samples. The return type depends on the
type of data source.

Sampling a `PointSet` results in a `Point2fSet` of sample points. Sampling a
`Continuous1D` results in a `Samples1D` of samples at the locations specified
by `xrange`, or denser. Sampling a `Continuous2D` results in a `Samples2D` of
samples at the locations specified by `xrange` and `yrange`.
"""
function sample end


###############################
### concrete implementations
###############################

### PointSet

struct Point2fSet{S1<:AbstractVector{Point2f},S2<:AbstractVector{Int}} <: PointSet
  points::S1
  multiplicity::S2
end

function sample(data::Point2fSet, xrange, yrange)
  length(data.points) < length(xrange) * length(yrange) && return data
  ndx = findall(p -> xrange[1] ≤ p[1] ≤ xrange[end] && yrange[1] ≤ p[2] ≤ yrange[end], data.points)
  length(ndx) < length(xrange) * length(yrange) && return data
  a = zeros(Int, length(xrange), length(yrange))
  for (p, n) ∈ @views zip(data.points[ndx], data.multiplicity[ndx])
    i = round(Int, (p[1] - first(xrange)) / step(xrange)) + 1
    j = round(Int, (p[2] - first(yrange)) / step(yrange)) + 1
    a[i,j] += n
  end
  ndx = findall(>(0), a)
  ii = map(x -> x.I[1], ndx)
  jj = map(x -> x.I[2], ndx)
  m = a[ndx]
  Point2fSet(Point2f.(xrange[ii], yrange[jj]), m)
end

### 1D sampled data

struct Samples1D{S1<:AbstractVector,S2<:AbstractVector} <: Continuous1D
  x::S1
  y::S2
  function Samples1D(x, y)
    length(x) == length(y) || throw(ArgumentError("Size mismatch between x and y"))
    new{typeof(x),typeof(y)}(x, y)
  end
end

function sample(data::Samples1D, xrange::AbstractRange, yrange; pool=extreme, interpolate=linear)
  n = length(pool(zeros(eltype(data.y))))
  xrange = narrow(xrange, data.x)
  xs = repeat(xrange; inner=n)
  ys = similar(data.y, length(xs))
  sample1D!(ys, data.x, data.y, xrange, n, pool, interpolate)
  Samples1D(xs, ys)
end

# kernel function separated out to improve inference
function sample1D!(ys, data_x, data_y, xrange, n, pool, interpolate)
  Threads.@threads for i ∈ eachindex(xrange)
    x = xrange[i]
    r = mapsto(data_x, x, step(xrange))
    y = r === nothing ? interpolate(data_x, data_y, x) : pool(@view data_y[r])
    ys[n*i-n+1:n*i] .= y
  end
end

### 2D sampled data

struct Samples2D{S1<:AbstractRange,S2<:AbstractMatrix} <: Continuous2D
  x::S1
  y::S1
  z::S2
  function Samples2D(x, y, z)
    size(z) == (length(x), length(y)) || throw(ArgumentError("Size mismatch between x, y and z"))
    new{promote_type(typeof(x),typeof(y)),typeof(z)}(x, y, z)
  end
end

function sample(data::Samples2D, xrange::AbstractRange, yrange::AbstractRange; pool=max)
  xrange = intersection(xrange, data.x)
  yrange = intersection(yrange, data.y)
  z = zeros(eltype(data.z), length(xrange), length(yrange))
  Δx = step(xrange)
  if Δx == 0
    xis = 1:1
  else
    xi1 = findfirst(≥(first(xrange)), data.x)
    xi2 = findlast(≤(last(xrange)), data.x)
    xis = xi1:xi2
  end
  xxis = round.(Int, (data.x[xis] .- first(xrange)) ./ Δx) .+ 1
  Δy = step(yrange)
  if Δy == 0
    yis = 1:1
  else
    yi1 = findfirst(≥(first(yrange)), data.y)
    yi2 = findlast(≤(last(yrange)), data.y)
    yis = yi1:yi2
  end
  yyis = round.(Int, (data.y[yis] .- first(yrange)) ./ Δy) .+ 1
  parts = UnitRange{Int}[]
  i = 1
  for j ∈ 2:length(yyis)
    if yyis[i] != yyis[j]
      push!(parts, i:j-1)
      i = j
    end
  end
  push!(parts, i:length(yyis))
  sample2D!(z, xis, xxis, yis, yyis, parts, data.z, pool)
  Samples2D(xrange, yrange, z)
end

# kernel function separated out to improve inference
function sample2D!(z, xis, xxis, yis, yyis, parts, data_z, op)
  Threads.@threads for p ∈ parts
    for (yi, yyi) ∈ zip(@view(yis[p]), @view(yyis[p]))
      for (xi, xxi) ∈ zip(xis, xxis)
        z[xxi,yyi] = op(z[xxi,yyi], data_z[xi,yi])
      end
    end
  end
end

### 1D function

struct Function1D{T} <: Continuous1D
  f::T
end

sample(data::Function1D, xrange, yrange) = Samples1D(xrange, map(data.f, xrange))

### 2D function

struct Function2D{T} <: Continuous2D
  f::T
end

sample(data::Function2D, xrange, yrange) = Samples2D(xrange, yrange, [data.f(x,y) for x ∈ xrange, y ∈ yrange])


##########################################
### pooling and interpolation functions
##########################################

"""
    nearest(xs, ys, x)

Finds `y` from `ys` corresponding to the nearest `x` in `xs`. The 1D arrays
`xs` and `ys` must be of equal length, and the distance is measured as the
absolute difference.
"""
function nearest(xs, ys, x)
  (x < minimum(xs) || x > maximum(xs)) && return missing
  _, i = findmin(abs, x .- xs)
  ys[i]
end

function nearest(xs::AbstractRange, ys, x)
  i = round(Int, (x - first(xs)) / step(xs) + 1)
  (i < 1 || i > length(xs)) && return missing
  ys[i]
end

"""
    linear(xs, ys, x)

Finds `y` corresponding to the given `x` through linear interpolation of data.
The data is provided as 1D arrays `xs` and `ys` of equal length.
"""
function linear(xs::AbstractRange, ys, x)
  i = (x - first(xs)) / step(xs) + 1
  i⁻ = floor(Int, i)
  i⁺ = ceil(Int, i)
  (i⁻ < 1 || i⁺ > length(xs)) && return missing
  ys[i⁻] * (i⁺ - i) + ys[i⁺] * (i - i⁻)
end

"""
    extreme(x)

Returns tuple `(min(x), max(x))`. This is the same as `Base.extreme()`, but is
much faster.
"""
extreme(x) = (minimum(x), maximum(x))


###############################
### helpers
###############################

function mapsto(xs::AbstractRange, x, Δx)
  x + Δx / 2 < first(xs) && return nothing
  x - Δx / 2 > last(xs) && return nothing
  i1 = (x - Δx / 2 - first(xs)) / step(xs)
  i2 = (x + Δx / 2 - first(xs)) / step(xs)
  floor(i2) < i1 && return nothing
  max(ceil(Int, i1 + 1), 1):min(floor(Int, i2 + 1), length(xs))
end

function narrow(xrange, x)
  if first(xrange) < first(x)
    j = Int(cld(first(x) - first(xrange), step(xrange)))
    j > length(xrange) && return xrange[1:0]
    xrange = xrange[begin+j:end]
  end
  if last(xrange) > last(x)
    j = Int(cld(last(xrange) - last(x), step(xrange)))
    j > length(xrange) && return xrange[1:0]
    xrange = xrange[begin:end-j]
  end
  xrange
end

function intersection(xdisplayrange, xdatarange)
  x1 = findfirst(≥(first(xdisplayrange)), xdatarange)
  x2 = findlast(≤(last(xdisplayrange)), xdatarange)
  range(x1, x2; step=max(step(xdisplayrange), step(xdatarange)))
end
