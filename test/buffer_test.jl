module Buffer_Test

using GLAbstraction, GLWindow, GLFW, ModernGL, GeometryTypes,FactCheck

win=create_glcontext("buffer test")

indexes = indexbuffer(GLuint[0,1,2])

v = Point2f0[Point2f0(0.0, 0.5), Point2f0(0.5, -0.5), Point2f0(-0.5,-0.5)]

verts = GLBuffer(v)

facts() do

end

GLFW.DestroyWindow(win)

end
