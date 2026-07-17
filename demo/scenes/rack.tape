Output ../assets/demo-rack.gif
Output build/demo-rack.txt
Set Width 1200
Set Height 640
# Tighter chrome for the 4-column arsenal rack. JetBrainsMono @12 / pad 12
# on Width 1200 yields enough real cols for ~84-char table rows.
# No forced COLUMNS/stty — match the real pty only.
Set FontSize 12
Set Padding 12
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
Type `armory --list`
Sleep 500ms
Enter
Sleep 4s
