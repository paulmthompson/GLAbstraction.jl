immutable TextureParameters{NDim}
    minfilter::Symbol
    magfilter::Symbol # magnification
    repeat   ::NTuple{NDim, Symbol}
end

type Texture{T <: GLArrayEltypes, NDIM} <: GPUArray{T, NDIM}
    id              ::GLuint
    texturetype     ::GLenum
    pixeltype       ::GLenum
    internalformat  ::GLenum
    format          ::GLenum
    parameters      ::TextureParameters{NDIM}
    size            ::NTuple{NDIM, Int}
    buffer          ::Nullable{GLBuffer{T}} # Textures can be optionally created from a buffer, in which case we need a reference to the buffer
end

is_texturearray(t::Texture)  = t.texturetype == GL_TEXTURE_2D_ARRAY
is_texturebuffer(t::Texture) = t.texturetype == GL_TEXTURE_BUFFER

colordim{T}(::Type{T})       = length(T)
colordim{T<:Real}(::Type{T}) = 1

function set_packing_alignment(a) # at some point we should specialize to array/ptr a
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1)
    glPixelStorei(GL_UNPACK_ROW_LENGTH, 0)
    glPixelStorei(GL_UNPACK_SKIP_PIXELS, 0)
    glPixelStorei(GL_UNPACK_SKIP_ROWS, 0)
end


function Texture{T, NDim}(
        data::Ptr{T}, dims::NTuple{NDim, Int};
        internalformat::GLenum = default_internalcolorformat(T),
        texturetype   ::GLenum = default_texturetype(NDim),
        format        ::GLenum = default_colorformat(T),
        parameters... # rest should be texture parameters
    )
    texparams = TextureParameters(T, NDim; parameters...)
    id = glGenTextures()
    glBindTexture(texturetype, id)
    set_packing_alignment(data)
    numbertype = julia2glenum(eltype(T))
    glTexImage(texturetype, 0, internalformat, dims..., 0, format, numbertype, data)
    texture = Texture{T, NDim}(
        id, texturetype, numbertype, internalformat, format,
        texparams,
        dims, Nullable{GLBuffer{T}}()
    )
    set_parameters(texture)
    texture
end

#=
Constructor for empty initialization with NULL pointer instead of an array with data.
You just need to pass the wanted color/vector type and the dimensions.
To which values the texture gets initialized is driver dependent
=#
Texture{T <: GLArrayEltypes, N}(::Type{T}, dims::NTuple{N, Int}; kw_args...) =
    Texture(convert(Ptr{T}, C_NULL), dims; kw_args...)

#=
Constructor for a normal array, with color or Abstract Arrays as elements.
So Array{Real, 2} == Texture2D with 1D Colorant dimension
Array{Vec1/2/3/4, 2} == Texture2D with 1/2/3/4D Colorant dimension
Colors from Colors.jl should mostly work as well
=#
Texture{T <: GLArrayEltypes, NDim}(image::Array{T, NDim}; kw_args...) =
    Texture(pointer(image), size(image); kw_args...)

#=
Constructor for Array Texture
=#
Texture{T <: GLArrayEltypes}(data::Vector{Matrix{T}}; kw_args...) =
    Texture(data; texturetype=GL_TEXTURE_2D_ARRAY, kw_args...)


function Texture{T <: GLArrayEltypes}(
        data::Vector{Array{T, 2}};
        internalformat::GLenum = default_internalcolorformat(T),
        texturetype::GLenum    = GL_TEXTURE_2D_ARRAY,
        format::GLenum         = default_colorformat(T),
        parameters...
    )
    texparams = TextureParameters(T, 3; parameters...)
    id = glGenTextures()

    glBindTexture(texturetype, id)

    numbertype = julia2glenum(eltype(T))

    layers  = length(data)
    dims    = map(size, data)
    maxdims = foldp((0,0), dims) do v0, x
        a = max(v0[1], x[1])
        b = max(v0[2], x[2])
        (a,b)
    end
    set_packing_alignment(data)
    glTexStorage3D(GL_TEXTURE_2D_ARRAY, 1, internalformat, maxdims..., layers)
    for (layer, texel) in enumerate(data)
        width, height = size(texel)
        glTexSubImage3D(GL_TEXTURE_2D_ARRAY, 0, 0, 0, layer-1, width, height, 1, format, numbertype, texel)
    end

    texture = Texture{T, 3}(
        id, texturetype, numbertype,
        internalformat, format, texparams,
        tuple(maxdims..., layers), Nullable{GLBuffer{T}}()
    )
    set_parameters(texture)
    texture
end



function Texture{T <: GLArrayEltypes}(buffer::GLBuffer{T})
    texture_type = GL_TEXTURE_BUFFER
    id = glGenTextures()
    glBindTexture(texture_type, id)
    internalformat = default_internalcolorformat(T)
    glTexBuffer(texture_type, internalformat, buffer.id)
    Texture{T, 1}(
        id, texture_type, julia2glenum(T), internalformat,
        default_colorformat(T), TextureParameters(T, 1),
        size(buffer), Nullable(buffer),
    )
end
texture_buffer{T <: GLArrayEltypes}(buffer::Vector{T}) =
    Texture(GLBuffer(buffer, buffertype=GL_TEXTURE_BUFFER, usage=GL_DYNAMIC_DRAW))


#=
Some special treatmend for types, with alpha in the First place

function Texture{T <: Real, NDim}(image::Array{ARGB{T}, NDim}, texture_properties::Vector{(Symbol, Any)})
    data = map(image) do colorvalue
        AlphaColorValue(colorvalue.c, colorvalue.alpha)
    end
    Texture(pointer(data), [size(data)...], texture_properties)
end
=#

#=
Creates a texture from an Image
=#
##function Texture(image::Image, texture_properties::Vector{(Symbol, Any)})
#    data = image.data
#    Texture(mapslices(reverse, data, ndims(data)), texture_properties)
#end


GeometryTypes.width(t::Texture)  = size(t, 1)
GeometryTypes.height(t::Texture) = size(t, 2)
depth(t::Texture)  = size(t, 3)


function Base.show{T,D}(io::IO, t::Texture{T,D})
    println(io, "Texture$(D)D: ")
    println(io, "                  ID: ", t.id)
    println(io, "                Size: ", reduce("Dimensions: ", size(t)) do v0, v1
        v0*"x"*string(v1)
    end)
    println(io, "    Julia pixel type: ", T)
    println(io, "   OpenGL pixel type: ", GLENUM(t.pixeltype).name)
    println(io, "              Format: ", GLENUM(t.format).name)
    println(io, "     Internal format: ", GLENUM(t.internalformat).name)
    println(io, "          Parameters: ", t.parameters)
end


# GPUArray interface:
function Base.unsafe_copy!{T}(a::Vector{T}, readoffset::Int, b::Texture{T, 1}, writeoffset::Int, len::Int)
    isnull(b.buffer) && error("copy! is only implemented for texture buffers for now")
    buffer = get(b.buffer)
    copy!(a, readoffset, buffer, writeoffset, len)
    glBindTexture(b.texturetype, b.id)
    glTexBuffer(b.texturetype, b.internalformat, buffer.id) # update texture
end

function Base.unsafe_copy!{T}(a::Texture{T, 1}, readoffset::Int, b::Vector{T}, writeoffset::Int, len::Int)
    isnull(a.buffer) && error("copy! is only implemented for texture buffers for now")
    buffer = get(a.buffer)
    copy!(buffer, readoffset, b, writeoffset, len)
    glBindTexture(a.texturetype, a.id)
    glTexBuffer(a.texturetype, a.internalformat, buffer.id) # update texture
end
function Base.unsafe_copy!{T}(a::Texture{T, 1}, readoffset::Int, b::Texture{T,1}, writeoffset::Int, len::Int)
    (isnull(a.buffer) || isnull(b.buffer)) && error("copy! is only implemented for texture buffers for now")
    abuffer, bbuffer = get(a.buffer), get(b.buffer)
    unsafe_copy!(abuffer, readoffset, bbuffer, writeoffset, len)

    glBindTexture(a.texturetype, a.id)
    glTexBuffer(a.texturetype, a.internalformat, abuffer.id) # update texture

    glBindTexture(b.texturetype, b.id)
    glTexBuffer(b.texturetype, b.internalformat, bbuffer.id) # update texture
end
function gpu_setindex!{T, I <: Integer}(t::Texture{T, 1}, newvalue::Array{T, 1}, indexes::UnitRange{I})
    if isnull(t.buffer)
        glBindTexture(t.texturetype, t.id)
        texsubimage(t, newvalue, indexes)
    else
        b = get(t.buffer)
        glBindTexture(t.texturetype, t.id)
        b[indexes] = newvalue # set buffer indexes
        glTexBuffer(t.texturetype, t.internalformat, b.id) # update texture
    end
end

function gpu_setindex!{T, N}(t::Texture{T, N}, newvalue::Array{T, N}, indexes::Union{UnitRange,Integer}...)
    glBindTexture(t.texturetype, t.id)
    texsubimage(t, newvalue, indexes...)
end


function gpu_setindex!{T}(target::Texture{T, 2}, source::Texture{T, 2}, fbo=glGenFramebuffers())
    glBindFramebuffer(GL_FRAMEBUFFER, fbo);
    glFramebufferTexture2D(GL_READ_FRAMEBUFFER, GL_COLOR_ATTACHMENT0,
                           GL_TEXTURE_2D, source.id, 0);
    glFramebufferTexture2D(GL_DRAW_FRAMEBUFFER, GL_COLOR_ATTACHMENT1,
                           GL_TEXTURE_2D, target.id, 0);
    glDrawBuffer(GL_COLOR_ATTACHMENT1);
    w, h = map(minimum, zip(size(target), size(source)))
    glBlitFramebuffer(0, 0, w, h, 0, 0, w, h,
                      GL_COLOR_BUFFER_BIT, GL_NEAREST)
end



#=
function gpu_setindex!{T}(target::Texture{T, 2}, source::Texture{T, 2}, fbo=glGenFramebuffers())
    w, h = map(minimum, zip(size(target), size(source)))
    glCopyImageSubData( source.id, source.texturetype,
    0,0,0,0,
    target.id, target.texturetype,
    0,0,0,0, w,h,0);
end
=#
# Implementing the GPUArray interface
function gpu_data{T, ND}(t::Texture{T, ND})
    if isnull(t.buffer)
        result = Array(T, size(t))
        glBindTexture(t.texturetype, t.id)
        glGetTexImage(t.texturetype, 0, t.format, t.pixeltype, result)
        return result
    end
    return gpu_data(get(t.buffer))
end

function gpu_getindex{T}(t::GLAbstraction.Texture{T,1}, i::UnitRange{Int64})
    isnull(t.buffer) && error("getindex operation only defined for texture buffers")
    return get(t.buffer)[i]
end
function gpu_getindex{T}(t::GLAbstraction.Texture{T,1}, i::UnitRange{Int64}, j::UnitRange{Int64})
    isnull(t.buffer) && error("getindex operation only defined for texture buffers")
    return get(t.buffer)[i]
end
export resize_nocopy!
function resize_nocopy!{T, ND}(t::Texture{T, ND}, newdims::Tuple{Vararg{Int}})
    glBindTexture(t.texturetype, t.id)
    glTexImage(t.texturetype, 0, t.internalformat, newdims..., 0, t.format, t.pixeltype, C_NULL)
    t.size = newdims
    t
end

similar{T, NDim}(t::Texture{T, NDim}, newdims::Int...) = similar(t, newdims)
function similar{T, NDim}(t::Texture{T, NDim}, newdims::NTuple{NDim, Int})
    if isnull(t.buffer)
        return Texture(
            Ptr{T}(C_NULL),
            newdims, t.texturetype,
            t.pixeltype,
            t.internalformat,
            t.format,
            t.parameters
        )
    else
        buff = similar(get(t.buffer), newdims...)
        return Texture(buff)
    end
end
# Resize Texture
function gpu_resize!{T, ND}(t::Texture{T, ND}, newdims::NTuple{ND, Int})
    if isnull(t.buffer)
        # dangerous code right here...Better write a few tests for this
        newtex   = similar(t, newdims)
        old_size = size(t)
        gpu_setindex!(newtex, t)
        t.size   = newdims
        free(t)
        t.id     = newtex.id
        return t
    end
    # MUST. HANDLE. BUFFERTEXTURE. DIFFERENTLY ... Did I mention that this is ugly?
    buffer = get(t.buffer)
    resize!(buffer, newdims)
    glBindTexture(t.texturetype, t.id)
    glTexBuffer(t.texturetype, t.internalformat, buffer.id) #update data in texture
    t.size   = newdims
    t
end

texsubimage{T}(t::Texture{T, 1}, newvalue::Array{T, 1}, xrange::UnitRange, level=0) = glTexSubImage1D(
    t.texturetype, level, first(xrange)-1, length(xrange), t.format, t.pixeltype, newvalue
)
function texsubimage{T}(t::Texture{T, 2}, newvalue::Array{T, 2}, xrange::UnitRange, yrange::UnitRange, level=0)
    glTexSubImage2D(
        t.texturetype, level,
        first(xrange)-1, first(yrange)-1, length(xrange), length(yrange),
        t.format, t.pixeltype, newvalue
    )
end
texsubimage{T}(t::Texture{T, 3}, newvalue::Array{T, 3}, xrange::UnitRange, yrange::UnitRange, zrange::UnitRange, level=0) = glTexSubImage3D(
    t.texturetype, level,
    first(xrange)-1, first(yrange)-1, first(zrange)-1, length(xrange), length(yrange), length(zrange),
    t.format, t.pixeltype, newvalue
)


function Base.start{T}(t::Texture{T, 1})
    isnull(t.buffer) && error("start operation only defined for texture buffers")
    start(get(t.buffer))
end
function Base.next{T}(t::Texture{T, 1}, state::Tuple{Ptr{T}, Int})
    isnull(t.buffer) && error("next operation only defined for texture buffers")
    next(get(t.buffer), state)
end
function Base.done{T}(t::Texture{T, 1}, state::Tuple{Ptr{T}, Int})
    isnull(t.buffer) && error("done operation only defined for texture buffers")
    isdone = done(get(t.buffer), state)
    if isdone
        glBindTexture(t.texturetype, t.id)
        glTexBuffer(t.texturetype, t.internalformat, get(t.buffer).id)
    end
    isdone
end




function default_colorformat(colordim::Integer, isinteger::Bool, colororder::AbstractString)
    colordim > 4 && error("no colors with dimension > 4 allowed. Dimension given: ", colordim)
    sym = "GL_"
    # Handle that colordim == 1 => RED instead of R
    color = colordim == 1 ? "RED" : colororder[1:colordim]
    # Handle gray value
    integer = isinteger ? "_INTEGER" : ""
    sym *= color * integer
    return eval(symbol(sym))
end
default_colorformat{T <: Real}(::Type{T})           = default_colorformat(1, T <: Integer, "RED")
default_colorformat{T <: AbstractArray}(::Type{T})  = default_colorformat(length(T), eltype(T) <: Integer, "RGBA")
default_colorformat{T <: FixedVector}(::Type{T})    = default_colorformat(length(T), eltype(T) <: Integer, "RGBA")
default_colorformat{T}(::Type{GrayA{T}})            = GL_LUMINANCE_ALPHA
default_colorformat{T <: Colorant}(::Type{T})       = default_colorformat(length(T), eltype(T) <: Integer, string(T.name.name))


function default_internalcolorformat{T}(::Type{GrayA{T}})
    s=sizeof(T)*8
    eval(symbol("GL_LUMINANCE$(s)_ALPHA$(s)"))
end


@generated function default_internalcolorformat{T}(::Type{T})
    cdim = colordim(T)
    if cdim > 4 || cdim < 1
        error("$(cdim)-dimensional colors not supported")
    end
    eltyp = eltype(T)
    sym = "GL_"
    sym *= "RGBA"[1:cdim]
    bits = sizeof(eltyp) * 8
    sym *= bits <= 32 ? string(bits) : error("$(T) has too many bits")
    if eltyp <: AbstractFloat
        sym *= "F"
    elseif eltyp <: FixedPoint
        sym *= eltyp <: UFixed ? "" : "_SNORM"
    elseif eltyp <: Signed
        sym *= "I"
    elseif eltyp <: Unsigned
        sym *= "UI"
    end
    s = symbol(sym)
    :($(s))
end

#Supported texture modes/dimensions
function default_texturetype(ndim::Integer)
    ndim == 1 && return GL_TEXTURE_1D
    ndim == 2 && return GL_TEXTURE_2D
    ndim == 3 && return GL_TEXTURE_3D
    error("Dimensionality: $(ndim), not supported for OpenGL texture")
end


const TEXTURE_PARAMETER_MAPPING = Dict(
    :clamp_to_edge          => GL_CLAMP_TO_EDGE,
    :mirrored_repeat        => GL_MIRRORED_REPEAT,
    :repeat                 => GL_REPEAT,

    :linear                 => GL_LINEAR, #Returns the value of the texture element that is nearest (in Manhattan distance) to the center of the pixel being textured.
    :nearest                => GL_NEAREST, #Returns the weighted average of the four texture elements that are closest to the center of the pixel being textured.
    :nearest_mipmap_nearest => GL_NEAREST_MIPMAP_NEAREST, #Chooses the mipmap that most closely matches the size of the pixel being textured and uses the GL_NEAREST criterion (the texture element nearest to the center of the pixel) to produce a texture value.
    :linear_mipmap_nearest  => GL_LINEAR_MIPMAP_NEAREST, #Chooses the mipmap that most closely matches the size of the pixel being textured and uses the GL_LINEAR criterion (a weighted average of the four texture elements that are closest to the center of the pixel) to produce a texture value.
    :nearest_mipmap_linear  => GL_NEAREST_MIPMAP_LINEAR, #Chooses the two mipmaps that most closely match the size of the pixel being textured and uses the GL_NEAREST criterion (the texture element nearest to the center of the pixel) to produce a texture value from each mipmap. The final texture value is a weighted average of those two values.
    :linear_mipmap_linear   => GL_LINEAR_MIPMAP_LINEAR, #Chooses the two mipmaps that most closely match the size of the pixel being textured and uses the GL_LINEAR criterion (a weighted average of the four texture elements that are closest to the center of the pixel) to produce a texture value from each mipmap. The final texture value is a weighted average of those two values.
)
map_texture_paramers{N}(s::NTuple{N, Symbol}) = map(map_texture_paramers, s)
function map_texture_paramers(s::Symbol, mapping=TEXTURE_PARAMETER_MAPPING)
    haskey(mapping, s) && return mapping[s]
    error("$s is not a valid texture parameter. Only $(keys(mapping)) are valid")
end


function TextureParameters(T, NDim;
        minfilter = T <: Integer ? :nearest : :linear,
        magfilter = minfilter, # magnification
        x_repeat  = :clamp_to_edge, #wrap_s
        y_repeat  = x_repeat, #wrap_t
        z_repeat  = x_repeat, #wrap_r
    )
    T <: Integer && (minfilter == :linear || magfilter == :linear) && error("Wrong Texture Parameter: Integer texture can't interpolate. Try :nearest")
    repeat = (x_repeat, y_repeat, z_repeat)
    TextureParameters(minfilter, magfilter, ntuple(i->repeat[i], NDim))
end
TextureParameters{T, NDim}(t::Texture{T, NDim}; kw_args...) = TextureParameters(T, NDim; kw_args...)



set_parameters{T, NDim}(t::Texture{T, NDim}; kw_args...) = set_parameters(t, TextureParameters(t; kw_args...))

function set_parameters{T, N}(t::Texture{T, N}, params::TextureParameters=t.parameters)
    result    = Array(Tuple{GLenum, GLenum}, N+2)
    data      = [name => map_texture_paramers(params.(name)) for name in fieldnames(params)]
    result[1] = (GL_TEXTURE_MIN_FILTER,        data[:minfilter])
    result[2] = (GL_TEXTURE_MAG_FILTER,        data[:magfilter])
    result[3] = (GL_TEXTURE_WRAP_S,            data[:repeat][1])
    N >= 2 && (result[4] = (GL_TEXTURE_WRAP_T, data[:repeat][2]))
    if N >= 3 && !is_texturearray(t) # for texture arrays, third dimension can not be set
        result[5] = (GL_TEXTURE_WRAP_R,        data[:repeat][3])
    end
    t.parameters = params
    set_parameters(t, result)
end

function set_parameters(t::Texture, parameters::Vector{Tuple{GLenum, GLenum}})
    glBindTexture(t.texturetype, t.id)
    for elem in parameters
        glTexParameteri(t.texturetype, elem...)
    end
    glBindTexture(t.texturetype, 0)
end
