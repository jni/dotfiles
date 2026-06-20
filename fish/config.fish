if status is-interactive
    # Commands to run in interactive sessions can go here
end

# Turn off syntax highlighting
for color in fish_color_command fish_color_comment fish_color_end \
             fish_color_escape fish_color_match fish_color_operator \
         fish_color_param fish_color_quote \
         fish_pager_color_description fish_pager_color_prefix
    set $color normal
end

set fish_color_autosuggestion white
set fish_color_error red

set fish_pager_color_progress white

# >>> mamba initialize >>>
# !! Contents within this block are managed by 'micromamba shell init' !!
set -gx MAMBA_EXE "/home/jni/.local/bin/micromamba"
set -gx MAMBA_ROOT_PREFIX "/home/jni/micromamba"
$MAMBA_EXE shell hook --shell fish --root-prefix $MAMBA_ROOT_PREFIX | source
# <<< mamba initialize <<<
micromamba activate all

alias mu micromamba

alias pbcopy wl-copy
alias pbpaste wl-paste

fish_add_path /home/jni/.local/bin

starship init fish | source
