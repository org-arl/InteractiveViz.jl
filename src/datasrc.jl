using GeometryBasics
using SparseArrays
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

# FIXME too slow
function sample(data::Point2fSet, xrange, yrange)
  length(data.points) < length(xrange) * length(yrange) && return data
  ndx = findall(p -> xrange[1] ≤ p[1] ≤ xrange[end] && yrange[1] ≤ p[2] ≤ yrange[end], data.points)
  length(ndx) < length(xrange) * length(yrange) && return data
  #a = spzeros(Int, length(xrange), length(yrange))
  a = zeros(Int, length(xrange), length(yrange))
  for (p, n) ∈ @views zip(data.points[ndx], data.multiplicity[ndx])
    i = round(Int, (p[1] - first(xrange)) / step(xrange)) + 1
    j = round(Int, (p[2] - first(yrange)) / step(yrange)) + 1
    a[i,j] += n
  end
  #ii, jj, m = findnz(a)
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
end

function sample(data::Samples1D, xrange, yrange; pool=mean, interpolate=nearest)
  y = map(xrange) do x
    i = mapsto(data.x, x, step(xrange))
    isempty(i) ? interpolate(data.x, data.y, x) : mean(data.y[i])
  end
  Samples1D(xrange, y)
end

### 2D sampled data

struct Samples2D{S1<:AbstractVector,S2<:AbstractMatrix} <: Continuous2D
  x::S1
  y::S1
  z::S2
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

mapsto(xs, x, Δx) = findall(x̄ -> -Δx/2 ≤ x - x̄ < Δx/2, xs)

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
