
Pkg.rm("GLFW")

Pkg.clone("https://github.com/paulmthompson/GLFW.jl")
Pkg.build("GLFW")

Pkg.clone("https://github.com/paulmthompson/GLWindow.jl")

Pkg.checkout("GLWindow", "sd/rebuild")

Pkg.rm("GLAbstraction")
