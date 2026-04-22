' daemon_win.vbs — background clipboard daemon for the Aseprite Hex Clipboard plugin.
' Polls a trigger file and pipes its contents into clip.exe.
' Arg 0: path to the trigger file to watch.
' Arg 1: path to write clipboard data (temp file for piping into clip).
' Send "STOP" as trigger content to exit cleanly.

If WScript.Arguments.Count < 2 Then WScript.Quit 1

Dim triggerPath, clipPath
triggerPath = WScript.Arguments(0)
clipPath    = WScript.Arguments(1)

Dim shell, fso
Set shell = CreateObject("WScript.Shell")
Set fso   = CreateObject("Scripting.FileSystemObject")

Do While True
    If fso.FileExists(triggerPath) Then
        Dim f, text
        Set f = fso.OpenTextFile(triggerPath, 1)
        text  = f.ReadAll
        f.Close
        fso.DeleteFile triggerPath, True

        If text = "STOP" Then Exit Do

        Set f = fso.OpenTextFile(clipPath, 2, True, 0)
        f.Write text
        f.Close
        shell.Run "cmd /c clip < """ & clipPath & """", 0, True
        fso.DeleteFile clipPath, True
    End If
    WScript.Sleep 30
Loop
