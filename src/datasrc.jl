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
    issorted(x) || throw(ArgumentError("x must be ordered"))
    length(x) == length(y) || throw(ArgumentError("Size mismatch between x and y"))
    new{typeof(x),typeof(y)}(x, y)
  end
end

function sample(data::Samples1D, xrange, yrange; pool=extrema, interpolate=linear)
  xs = similar(xrange, 0)
  ys = Array{promote_type(eltype(data.y),Missing)}(undef, 0)
  sizehint!(xs, length(xrange))
  sizehint!(ys, length(xrange))
  i = firstindex(data.x)
  Δxby2 = step(xrange) / 2
  for j ∈ eachindex(xrange)
    x = xrange[j]
    if i ≤ lastindex(data.x) && data.x[i] < x + Δxby2
      i1 = findnext(≥(x - Δxby2), data.x, i)
      if i1 === nothing
        push!(xs, x)
        push!(ys, interpolate(data.x, data.y, x))
      else
        i2 = i1
        while i2+1 ≤ lastindex(data.x) && data.x[i2+1] < x + Δxby2
          i2 += 1
        end
        y = pool(data.y[i1:i2])
        if y isa Tuple
          if y[1] == y[2]
            push!(xs, x)
            push!(ys, y[1])
          else
            push!(xs, x)
            push!(xs, x)
            push!(xs, x)
            push!(xs, x)
            push!(ys, (y[1] + y[2]) / 2)
            push!(ys, y[1])
            push!(ys, y[2])
            push!(ys, (y[1] + y[2]) / 2)
          end
        else
          push!(xs, x)
          push!(ys, y)
        end
        i = i2 + 1
      end
    else
      push!(xs, x)
      push!(ys, interpolate(data.x, data.y, x))
    end
  end
  Samples1D(xs, ys)
end

### 2D sampled data

struct Samples2D{S1<:AbstractVector,S2<:AbstractMatrix} <: Continuous2D
  x::S1
  y::S1
  z::S2
  function Samples2D(x, y, z)
    issorted(x) || throw(ArgumentError("x must be sorted"))
    issorted(y) || throw(ArgumentError("y must be sorted"))
    size(z) == (length(x), length(y)) || throw(ArgumentError("Size mismatch between x, y and z"))
    new{promote_type(typeof(x),typeof(y)),typeof(z)}(x, y, z)
  end
end

function sample(data::Samples2D, xrange, yrange; pool=mean)
  z = map(Iterators.product(xrange, yrange)) do (x, y)
    j = mapsto(data.x, x, step(xrange))
    i = mapsto(data.y, y, step(xrange))
    (i < 1 || i > size(data.z, 1)) && return missing
    (j < 1 || j > size(data.z, 2)) && return missing
    pool(data.z[i,j])
  end
  Samples2D(xrange, yrange, z)
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


###############################
### helpers
###############################

function mapsto(xs, x, Δx)
  i1 = findfirst(≥(x - Δx/2), xs)
  i1 === nothing && return missing
  i2 = findlast(<(x + Δx/2), xs)
  i2 ≥ i1 || return missing
  i1:i2
end

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

function linear(xs::AbstractRange, ys, x)
  i = (x - first(xs)) / step(xs) + 1
  i⁻ = floor(Int, i)
  i⁺ = ceil(Int, i)
  (i⁻ < 1 || i⁺ > length(xs)) && return missing
  ys[i⁻] * (i⁺ - i) + ys[i⁺] * (i - i⁻)
end
