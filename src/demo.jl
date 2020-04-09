module Demo

#using Makie: RGBAf0

export mandelbrotset!

function mandelbrot(c, n)
  z = zero(ComplexF64)
  for j ∈ 0:n-1
    z = z^2 + c
    abs(z) > 2.0 && (return j)
  end
  return n
end

function mandelbrotset!(img, extents)
  width, height = size(img)
  xscale = extents.width / (width - 1)
  yscale = extents.height / (height - 1)
  for y ∈ 1:height
    for x ∈ 1:width
      c = complex(extents.left + (x-1)*xscale, extents.bottom + (y-1)*yscale)
      img[x,y] = mandelbrot(c, 100) / 100
      #img[x,y] = RGBAf0(mandelbrot(c, 100) / 100, 0, 0, 0.8)
    end
  end
end

end # module
