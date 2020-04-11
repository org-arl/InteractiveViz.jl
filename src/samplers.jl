export apply!, subset!

function apply!(f::Function, buf::AbstractMatrix, c::Canvas)
  for j ∈ 1:size(buf,2)
    for i ∈ 1:size(buf,1)
      x, y = ij2xy(i, j, c)
      buf[i,j] = f(x, y)
    end
  end
end

function set!(buf, p, pt)
  if p < length(buf)
    p += 1
    buf[p] = pt
  else
    push!(buf, pt)
    p = length(buf)
  end
  p
end

function truncate!(buf, p)
  p < length(buf) && splice!(buf, p+1:length(buf))
end

function apply!(f::Function, buf::AbstractVector{Point2f0}, c::Canvas)
  xyrect = c.xyrect[]
  n = c.ijhome[].width
  p = 0
  for x ∈ range(xyrect.left, xyrect.left + xyrect.width; length=n+1)
    y = f(x)
    if y isa AbstractVector
      for k ∈ 1:length(y)
        ij = xy2ij(Point2f0(x, y[k]), c)
        p = set!(buf, p, ij)
      end
    else
      ij = xy2ij(Point2f0(x, y), c)
      p = set!(buf, p, ij)
    end
  end
  truncate!(buf, p)
end

function subset!(buf::AbstractVector{Point2f0}, c::Canvas)
  data = c.datasrc.data
  data === missing && return
  xyrect = c.xyrect[]
  p = 0
  for k in 1:size(data,1)
    if xyrect.left <= data[k,1] < xyrect.left + xyrect.width && xyrect.bottom <= data[k,2] < xyrect.bottom + xyrect.height
      ij = xy2ij(Point2f0(data[k,1], data[k,2]), c)
      if p < length(buf)
        p += 1
        buf[p] = ij
      else
        push!(buf, ij)
        p = length(buf)
      end
    end
  end
  p < length(buf) && splice!(buf, p+1:length(buf))
  length(buf) < 1 && push!(buf, Point2f0(Inf32, Inf32))  # needed because Makie does not like 0-point lines
end
