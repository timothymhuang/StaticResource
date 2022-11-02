; BASIC STATUP TAGS
#NoEnv
#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%
log = 0 ; 0 = Error Logs, 1 = All Logs
log("Program Starting")
SetTimer, checkupdate, 5000

; GET REPO DIRECTORY
IniRead, localrepo, %A_ScriptDir%\config.ini, settings, localrepo
IniRead, reponame, %A_ScriptDir%\config.ini, settings, reponame
if (localrepo = "ERROR" || reponame = "ERROR"){
    Msgbox, 4096, GitHub Desktop Helper, config.ini is missing data or does not exist at all
    Exit
}

; SEE IF GIT WORKS
RunWait, cmd.exe /c git -v > %A_ScriptDir%\cmd.txt, %localrepo%, hide
FileRead, cmdoutput, %A_ScriptDir%\cmd.txt
if !(InStr(cmdoutput, "git version")){
    MsgBox, 4096, GitHub Desktop Helper, Please install Git. Make sure Git is also added to PATH. The download page will show in your browser.
    Run, https://git-scm.com/download/win
    Exit
}

; UPDATE TIMES
fetchhead := localrepo . "\.git\FETCH_HEAD"
orighead := localrepo . "\.git\ORIG_HEAD"
updatetime()

; STARTUP NOTIFICATION
notification("Started in "localrepo, 1)

; SCRIPT LOOP
Loop
{
    status := status()
    ;CoordMode, tooltip, Screen
    ;ToolTip, %lastfetch% | %lastpull% | %status% | %A_TickCount%, 0, 0

    if(status = "behind"){
        if git("pull") {
            Goto, breakout
        }
        if(WinActive("ahk_exe GitHubDesktop.exe")){
            Send, ^1
        }
        notification("Changes downloaded.")
    } else if(status = "ahead" || status() = "diverge") {
            if git("pull") {
                Goto, breakout
            }
            if git("push") {
                Goto, breakout
            }
            if(WinActive("ahk_exe GitHubDesktop.exe")){
                Send, ^1
            }
            notification("Changes uploaded")
    }

    breakout:
    Sleep, 5000
}

;
; ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
;

checkupdate:
api := getapi()
newversion := getini(api,"version")
IniRead, currentversion, %A_ScriptDir%\config.ini, settings, version
if (newversion != currentversion){
    UrlDownloadToFile, https://github.com/timothymhuang/api/blob/main/rocketry/githelperupdater.exe?raw=true, %A_ScriptDir%\githelperupdater.exe
    Run, %A_ScriptDir%\githelperupdater.exe
    ExitApp
}
Return

;
; ~~~~~~~~~~~~~~~~~
;

updatetime()
{
    global fetchheadtime
    global origheadtime
    global fetchhead
    global orighead
    global lastfetch
    global lastpull

    FileGetTime, fetchheadtime, %fetchhead%, M
    FileGetTime, origheadtime, %orighead%, M
    lastfetch := A_Now
    EnvSub, lastfetch, fetchheadtime, Minutes
    lastpull := A_Now
    EnvSub, lastpull, origheadtime, Minutes
}

git(action,stoperror:=0){
    global recurringnotif
    global localrepo

    RunWait, cmd.exe /c git %action% > %A_ScriptDir%\cmdgit.txt, %localrepo%, hide
    FileRead, cmdoutput, %A_ScriptDir%\cmdgit.txt
    log(action . "`n" . cmdoutput)
    if (action = "pull" && || cmdoutput = "" && false){
        notification("ERROR PULLING - Probably new changes to files that conflict with yours. Please open GitHub desktop and attempt to 'pull' to resolve issue.", 3)
        Sleep, 30000
        Return 1
    } else if (action = "push" && cmdoutput = "" && false) {
        notification("ERROR PUSHING - Probably because new changes exist that you need to download. Please open GitHub desktop and attempt to 'pull' to resolve issue.", 3)
        Sleep, 30000
        Return 1
    } else {
        Return 0
    }
}

status(){
    global recurringnotif
    global localrepo

    RunWait, cmd.exe /c git status > %A_ScriptDir%\cmdstatus.txt, %localrepo%, hide
    FileRead, cmdoutput, %A_ScriptDir%\cmdstatus.txt

    if instr(cmdoutput, "Your branch is behind"){
        Return "behind"
    } else if InStr(cmdoutput, "Your branch is up to date with"){
        Return "current"
    } else if InStr(cmdoutput, "Your branch is ahead of"){
        Return "ahead"
    } else if InStr(cmdoutput, "have diverged"){
        Return "diverge"
    } else {
        Msgbox % localrepo
        log("Invalid output when running git status`n"cmdoutput, 1)
        if (!recurringnotif) {
            recurringnotif := 1
            notification("An recurring error has occured. Check the logs for more information.", 3)
        }
        Return 0
    }
}

log(text, override:=0){
    global log
    if(log || override){
        FileAppend, `n%A_Now% - %text%, githelper.log
    }
}

notification(text, options:=""){
    global reponame
    TrayTip, GitHelper in %reponame%, %text%,, options
}

getapi(){
    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", "https://raw.githubusercontent.com/timothymhuang/api/main/rocketry/githelper.ini", true)
    whr.Send()
    whr.WaitForResponse()
    api := whr.ResponseText
    Return %api%
}

getini(payload,input){
    config := StrSplit(payload, "`n", "`r")
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