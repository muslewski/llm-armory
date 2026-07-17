Output ../assets/demo-rack.gif
Output build/demo-rack.txt
Set Width 1200
Set Height 640
# Slightly tighter chrome so the 4-column arsenal rack fits without wrapping.
Set FontSize 12
Set Padding 12
Env COLUMNS "140"
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
Type `stty cols 140 rows 40 2>/dev/null || true`
Enter
Type `export COLUMNS=140`
Enter
Type `clear`
Enter
Show
Type `armory --list`
Sleep 500ms
Enter
Sleep 4s
