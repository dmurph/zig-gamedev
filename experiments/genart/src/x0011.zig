const std = @import("std");
const math = std.math;
const sdl = @import("zsdl2");
const gl = @import("zopengl").bindings;
const xcommon = @import("xcommon");

pub const name = "generative art experiment: x0011";
pub const display_width = 1024 * 1;
pub const display_height = 1024 * 1;

var fs_postprocess: gl.Uint = 0;
var prng = std.Random.DefaultPrng.init(123);
var random = prng.random();

const Particle = struct {
    x: f32 = 0.0,
    y: f32 = 0.0,
    frame: u32 = 0,
    num_frames: u32 = 50,
    step: u32 = 0,
};

var particles = [_]Particle{.{}} ** 200;

pub fn draw() void {
    for (&particles) |*p| {
        if (p.step == 0) {
            p.x += 0.01;
        } else if (p.step == 1) {
            p.y += 0.01;
        } else if (p.step == 2) {
            p.x -= 0.01;
        } else if (p.step == 3) {
            p.y -= 0.01;
        }

        if (p.frame == p.num_frames) {
            p.frame = 0;
            p.step += 1;
            if (p.step == 4) p.step = 0;
        }
        p.frame += 1;
    }

    gl.enable(gl.BLEND);
    gl.useProgram(0);
    gl.loadIdentity();
    gl.color3f(1, 1, 1);
    gl.begin(gl.POINTS);
    for (particles) |p| {
        gl.vertex2f(p.x, p.y);
    }
    gl.end();

    gl.textureBarrier();

    gl.disable(gl.BLEND);
    gl.useProgram(fs_postprocess);
    gl.loadIdentity();
    gl.begin(gl.TRIANGLES);
    gl.vertex2f(-1.0, -1.0);
    gl.vertex2f(3.0, -1.0);
    gl.vertex2f(-1.0, 3.0);
    gl.end();
}

pub fn init() !void {
    for (&particles) |*p| {
        p.x = -1.25 + 2.0 * random.float(f32);
        p.y = -1.25 + 2.0 * random.float(f32);
        p.num_frames = 20 + random.uintLessThan(u32, 100);
    }

    try sdl.gl.setSwapInterval(1);

    gl.clearBufferfv(gl.COLOR, 0, &[_]f32{ 0.0, 0.0, 0.0, 0.0 });
    gl.matrixLoadIdentityEXT(gl.PROJECTION);
    gl.pointSize(9.0);
    gl.blendFunc(gl.ONE, gl.ONE);
    gl.disable(gl.MULTISAMPLE);

    fs_postprocess = gl.createShaderProgramv(gl.FRAGMENT_SHADER, 1, &@as([*:0]const gl.Char, 
        \\  #version 460 compatibility
        \\  #extension NV_bindless_texture : require
        \\
        \\  layout(location = 0) uniform sampler2DMS display_texh;
        \\
        \\  void main() {
        \\      vec3 color = texelFetch(display_texh, ivec2(gl_FragCoord.xy), gl_SampleID).rgb;
        \\      color = color / (color + 1.0);
        \\      gl_FragColor = vec4(color, 1.0);
        \\  }
    ));
    gl.programUniformHandleui64NV(fs_postprocess, 0, xcommon.display_texh);
}
