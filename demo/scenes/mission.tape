Output ../assets/demo-mission.gif
Output build/demo-mission.txt
Set Width 1000
Set Height 500
# Real pty cols ≈103 at FontSize 14 / Padding 20 — enough for the dry-run
# panel (~100 outer). Do NOT export COLUMNS/stty wider than the pty: the
# card then draws past the viewport and wraps, breaking box borders.
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
