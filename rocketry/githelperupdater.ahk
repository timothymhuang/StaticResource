#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%

Process, Close, githelper.exe
UrlDownloadToFile, https://github.com/timothymhuang/api/blob/main/rocketry/githelper.exe?raw=true, %A_ScriptDir%\githelper.exe
api := getapi()
version := getini(api,"version")
IniWrite, %version%, %A_ScriptDir%\config.ini, settings, version
Run, %A_ScriptDir%\githelper.exe
Exit

getapi(){
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", "https://raw.githubusercontent.com/timothymhuang/api/main/rocketry/githelper.ini", true)
    whr.Send()
    whr.WaitForResponse()
    api := whr.ResponseText
    Return %api%
}

getini(payload,input){
    config := StrSplit(payload, "`n")
    Loop % config.Length()
    {
        checkline := config[A_Index]
        if(InStr(checkline, input . "=") = 1){
            output := SubStr(checkline, StrLen(input)+2)
            Return %output%
        }
    }
    Return "ERROR"
}