module GLFW_Test

using GLFW, FactCheck

facts() do

	@fact GLFW.Init() --> true

end

end
