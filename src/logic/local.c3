module logic;

bitstruct InlineParseFlags : ushort {
    bool in_bold       : 0;
    bool in_italic     : 1;
    bool in_strike     : 2;
    bool in_code       : 3;
    bool in_math       : 4;
    bool in_link       : 5;
    bool in_image      : 6;
    bool is_escaped    : 7;
    bool has_footnote  : 8;
}

bitstruct BlockParseFlags : ushort {
    bool is_fenced       : 0;
    bool is_callout      : 1;
    bool is_table_header : 2;
    bool is_task_item    : 3;
    bool is_checked      : 4;
    bool is_tight_list   : 5;
    bool has_frontmatter : 6;
}

bitstruct MathRenderFlags : ushort {
    bool display_mode    : 0;
    bool in_superscript  : 1;
    bool in_subscript    : 2;
    bool elevated_power  : 3;
    bool is_fraction_num : 4;
    bool is_fraction_den : 5;
    bool is_boxed        : 6;
    bool is_matrix_cell  : 7;
}

bitstruct TuiStateFlags : ushort {
    bool toc_open         : 0;
    bool search_active    : 1;
    bool search_has_match : 2;
    bool help_open        : 3;
    bool wrap_mode        : 4;
    bool needs_redraw     : 5;
    bool mouse_hover      : 6;
    bool line_sync_active : 7;
}

struct LocalScratchScope {
    Arena* arena;
    ArenaMark mark;
}

fn LocalScratchScope enter_scratch_scope(Arena* arena)
{
    LocalScratchScope scope;
    scope.arena = arena;
    scope.mark = arena.mark();
    return scope;
}

fn void LocalScratchScope.exit(LocalScratchScope* scope)
{
    if (scope.arena != null)
    {
        scope.arena.reset_to(scope.mark);
    }
}
