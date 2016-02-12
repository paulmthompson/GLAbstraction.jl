module TestSetup

using GLAbstraction

include("macro_test.jl")
include("glfw_test.jl")
include("accessors.jl")
include("uniforms.jl")
include("texture.jl")
include("buffer_test.jl")
include("renderobj_test.jl")

end
