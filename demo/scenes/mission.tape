Output ../assets/demo-mission.gif
Output build/demo-mission.txt
Set Width 1000
Set Height 500
Env COLUMNS "120"
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
Type `stty cols 120 rows 40 2>/dev/null || true`
Enter
Type `export COLUMNS=120`
Enter
Type `clear`
Enter
Show
Type `armory --dry-run grok-high -p "Refactor the parser"`
Sleep 500ms
Enter
Sleep 4s
