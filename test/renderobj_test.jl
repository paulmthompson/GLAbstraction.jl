module RenderObj_Test

using GLAbstraction, GLWindow, GLFW, ModernGL, GeometryTypes, FileIO, FactCheck

win=create_glcontext("render object test")

indexes = indexbuffer(GLuint[0,1,2])
v = Point2f0[Point2f0(0.0, 0.5), Point2f0(0.5, -0.5), Point2f0(-0.5,-0.5)]
verts = GLBuffer(v)

program=LazyShader(load(string(dirname(Base.source_path()),"/test.vert")),load(string(dirname(Base.source_path()),"/test.frag")))

const triangle = RenderObject(
	Dict(
		:vertex => verts,
		:name_doesnt_matter_for_indexes => indexes),program)

postrender!(triangle, render, triangle.vertexarray)

facts() do

end

GLFW.DestroyWindow(win)

end
