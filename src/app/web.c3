module app @feat(WASM);

import std::core::mem;
import ansi;
import ast;
import parser;
import render;

DString result;
usz length;

fn char* give(String text)
{
    length = text.len;
    return text.ptr;
}

fn char* reserve(usz size) @export("mdv_alloc") => (char*)mem::malloc((sz)(size ?: 1));

fn usz size() @export("mdv_length") => length;

fn char* page(char* text, usz size) @export("mdv_html")
{
    if (result.capacity() == 0) result.init(mem, 65536);
    result.clear();
    Document doc = parser::parse((String)text[:size]);
    defer doc.free();
    defer mem::free(text);
    render::html(&result, &doc.arena, doc.blocks);
    return give(result.str_view());
}

fn int themes() @export("mdv_themes") => ansi::themes();

fn char* name(int index) @export("mdv_theme_name") => give(ansi::title(index));

fn char* palette(int index) @export("mdv_theme_css")
{
    if (result.capacity() == 0) result.init(mem, 65536);
    result.clear();
    render::theme(&result, ansi::palette(index));
    return give(result.str_view());
}
