' clip_win.vbs — sets the Windows clipboard via clip.exe, no visible window.
' Usage: wscript //nologo //B clip_win.vbs "text"
If WScript.Arguments.Count < 1 Then WScript.Quit 1

Dim shell, fso, tmpPath, f
Set shell = CreateObject("WScript.Shell")
Set fso   = CreateObject("Scripting.FileSystemObject")

' Write to a temp file — avoids echo quirks and special-character issues.
tmpPath = fso.BuildPath(shell.ExpandEnvironmentStrings("%TEMP%"), "aseclip.txt")
Set f = fso.OpenTextFile(tmpPath, 2, True, 0)
f.Write WScript.Arguments(0)
f.Close

' Window style 0 = hidden. True = wait for clip.exe to finish before deleting.
shell.Run "cmd /c clip < """ & tmpPath & """", 0, True
fso.DeleteFile tmpPath, True
