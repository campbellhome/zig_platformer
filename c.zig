pub usingnamespace @cImport({
    @cInclude("bb.h");
    @cDefine("SOKOL_GLCORE33", "");
    @cInclude("sokol/sokol_app.h");
    @cInclude("sokol/sokol_gfx.h");
    @cInclude("sokol/util/sokol_gl.h");
    @cInclude("sokol/sokol_time.h");
    @cInclude("sokol/sokol_audio.h");
    @cDefine("CIMGUI_DEFINE_ENUMS_AND_STRUCTS", "");
    @cInclude("cimgui/cimgui.h");
    @cInclude("sokol/util/sokol_imgui.h");
    @cInclude("sokol/sokol_glue.h");
    @cInclude("stb/stb_image.h");
    @cInclude("soloud/include/soloud_c.h");
});
