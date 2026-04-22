' clip_win.vbs — Windows clipboard helper for the Aseprite Hex Clipboard extension.
'
' Sets the Windows clipboard to the given text using the htmlfile COM object.
' Invoked via wscript.exe (GUI subsystem, no visible console window).
'
' Usage: wscript //nologo //B clip_win.vbs "text to copy"

If WScript.Arguments.Count < 1 Then WScript.Quit 1

Dim html
Set html = CreateObject("htmlfile")
html.parentWindow.clipboardData.SetData "text", WScript.Arguments(0)
