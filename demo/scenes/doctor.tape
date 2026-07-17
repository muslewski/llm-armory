Output ../assets/demo-doctor.gif
Output build/demo-doctor.txt
# Match mission chrome (JetBrainsMono @14 needs ~1600px for a usable pty).
# No forced COLUMNS — bash uses the real glyph-grid width.
Set Width 1600
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
Type `armory doctor`
Sleep 500ms
Enter
Sleep 4s
