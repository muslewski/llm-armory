Output ../assets/demo-mission.gif
Output build/demo-mission.txt
# JetBrains Mono @ FontSize 14 ≈ 9.3px/col → Width 1200 ≈ 124 cols.
# Mission card longest line needs ~103 cols; comfortable margin, no wrap.
# Never export COLUMNS/stty larger than the glyph grid (that wraps mid-border).
Set Width 1200
Set Height 560
Set FontSize 14
Set Padding 20
Hide
Type `export GREEN_UI=/home/kento/.local/lib/green-ui.sh`
Enter
Type `export PATH="$HOME/.local/bin:$PATH"`
Enter
Type `export LLM_ARMORY_HOME="$HOME/Repositories/llm-armory"`
Enter
Type `export LLM_LAB_HOME="$LLM_ARMORY_HOME" ARMORY_HOME="$LLM_ARMORY_HOME"`
Enter
Type `unset LLM_GROK GROK_EFFORT GROK_MODEL LLM_PRESET LLM_SYSTEM_APPEND`
Enter
Type `export PS1='$ '`
Enter
Type `clear`
Enter
Show
Type `armory --dry-run grok-high -p "Refactor the parser"`
Sleep 500ms
Enter
Sleep 4s
