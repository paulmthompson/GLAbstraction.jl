module Uniform_Test

using GLAbstraction, GLWindow, GLFW, GeometryTypes, FixedSizeArrays, FactCheck

win=create_glcontext("uniform test")

a = Point4f0(0)
b = Point2f0(2)
c = Point4f0(b, 1,2)
d = Vec{4, Int}(b, 1,2)
d = Vec{4, UInt}(b, 1,2)


m  = Mat{4,3,Float32}(9f0)
m2 = Mat{3,3,Float32}(9f0)
m2 = Mat{3,3,Float32}(ntuple(x->0f0, 3), ntuple(x->0f0, 3), ntuple(x->0f0, 3))


gluniform(Int32(1), a)
gluniform(Int32(1), [a,a])
gluniform(Int32(1), m)
gluniform(Int32(1), [m, m])

facts() do

end

GLFW.DestroyWindow(win)

end
