#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
;#Warn  ; Recommended for catching common errors, enable during debugging
#Persistent ; Keep the script running until the user exits it.
#SingleInstance

IniFile = %A_AppData%\BreakReminder\Settings.ini

; Open settings GUI if first run, else read settings from ini and run break timer

IfNotExist, %IniFile%
{	
	Goto, Start
}
else
{
	Gosub, ReadSettings
	Gosub, CheckTime	
}

Return

Start:

; Get effective screensize to show settings GUI in bottom right corner

SysGet, Mon, MonitorWorkArea

Bot = %MonBottom%
Width = %MonRight%
y := Bot - 180 
x := Width - 220  

; Settings GUI

Gui, -Caption +AlwaysOnTop  +owner
Gui, Color, Black
Gui, Font, s7, Verdana

Gui, Add, Text,  cGray x210 y1 , X

Gui, Add, Text, cGray x20 y80 , Break duration in minutes
Gui, Add, Text, cGray x20 y20 , Maximum working time in minutes

Gui, Font, s11, Verdana

Gui, Add, Text, cGray x170 y42 w20 
Gui, Add, Progress, xm-10 x20 y45 w100 BackgroundE6E6E6 h10 cA6A6A6 vInterval Range0-60, 50


Gui, Add, Text, cGray x170 y102 w20
Gui, Add, Progress, xm-10 x20 y105 w100 BackgroundE6E6E6 h10 cA6A6A6 vDuration Range0-15, 5

Gui, Font, s7 cGray, Verdana
Gui, Add, Checkbox, x20 y145 vRunAtStart gSetStart
Gui, Add, Text, cGray x50 y145, Run at Windows startup
Gui,show, x%x% y%y% w220 h180,LB

; If first run set controls to default, else read settings from ini and set controls to retrieved values

IfNotExist, %IniFile%
{
	ControlSetText, Static4, 50 , LB
	ControlSetText, Static5, 5 , LB
	Xi = 50
	Xd = 5	
	Gosub, WriteSettings
}
else
{
	Gosub, ReadSettings	
	ControlSetText, Static4, %IntervalRead% , LB
	ControlSetText, Static5, %DurationRead% , LB
	GuiControl,, Interval, %IntervalRead%
	GuiControl,, Duration, %DurationRead%
	if(WinStartRead = 1){		
		Control, Check, , Button1, LB		
	}
		
}

return


; If GUI is active catch mouse clicks, if mouse is on 'sliders' track movement while mousedown. If mouse is on top corner x close GUI

#IfWinActive,LB
{
~Lbutton::

;KeyWait,LButton

{
MouseGetPos,mXX,,,Control

If Control in Static1
{
	
	Gosub, WriteSettings
	Gui, Destroy
  Sleep, 200
  Gosub, CheckTime
	
}

If Control in msctls_progress321
{
	SetTimer, TrackInterval,0
}

If Control in msctls_progress322
{
	SetTimer, TrackDuration,0
}
}

Return
}

#If



TrackInterval: ; While mousedown on break interval 'slider' track movement and set GUI values accordingly

If !GetKeyState("LButton", "P")
{
   SetTimer, TrackInterval, off
   return
}

Xi := GetMouse(60)

GuiControl,, Interval, %Xi% ; Sets progress bar to mouse position.
ControlSetText, Static4, %Xi% , LB ; Sets text behind bar to corresponding value
return

TrackDuration: ; While mousedown on break duration 'slider' track movement and set GUI values accordingly

If !GetKeyState("LButton", "P")
{
   SetTimer, TrackDuration, off
   return
}

Xd := GetMouse(15)
GuiControl,, Duration, %Xd% ; Sets progress bar to mouse position.
ControlSetText, Static5, %Xd% , LB ; Sets text behind bar to corresponding value
return

ReadSettings: ; Read ini file

IniRead, IntervalRead, %IniFile%, Intervals, Interval1
IniRead, DurationRead, %IniFile%, Durations, Duration1
IniRead, WinStartRead, %IniFile%, Options, WinStartup
return

WriteSettings: ; Write ini file

Gui, Submit, NoHide

; Create folder if not exists, IniWrite cannot create folder

IfNotExist, %A_AppData%\BreakReminder\
	FileCreateDir, %A_AppData%\BreakReminder\

; Error cathing if mouseposition variables are not declared if no change has been made in GUI after open, only write to ini if values are changed. 

If varExist("Xi")
	IniWrite, %Xi%, %IniFile%, Intervals, Interval1

If varExist("Xd")
 	IniWrite, %Xd%, %IniFile%, Durations, Duration1


 	IniWrite, %RunAtStart%, %IniFile%, Options, WinStartup

return

GetMouse(max) ; calculate position in 'slider' based on mouseposition in GUI, max is maximum value of slider
{
	MouseGetPos, mX  ; Gets mouse position relative to the Window.

	M := (mX -20) / 100 * max
	M := Round(M)

	; Restrict values to possible values in 'slider' 

	If M > %max%
		M := max

	If M < 1
		M = 1	

	return M
}


CheckTime: ; Set timer for lockscreen 

SetTimer, Lockscreen, Off
Gosub, ReadSettings
Time1 := IntervalRead * 60000
SetTimer, Lockscreen, -%Time1%
return

LockScreen: ; Create lockscreen for break duration set

;Move mouse to main screen so no taskbar on mouseclick

CoordMode, Mouse, Screen
MouseGetPos, xposi, yposi
MouseMove, 400, 400,0

BlockInput, MouseMove ; Block Mouse
SystemCursor("Off")

; If settings GUI is still open first write settings to ini then close settings GUI 


IfWinExist, LB
{
  Gosub, WriteSettings
  Sleep ,200
	Gui, Destroy
  
}

Gosub, ReadSettings ; Make sure lockscreen has updated break duration if above lines apply

startdim = 100 ; Starting point of screen dim, range is 0-255

CutOff = 0

; Define middle of screen for countdown clock

xpos := A_ScreenWidth / 2 - 140
ypos := A_ScreenHeight / 2 - 100

typos := ypos + 140
txpos := xpos - 140
DurationSeconds := DurationRead * 60 ; minutes to seconds

; Create screen covering GUI
Gui,color,000000
Gui, -Caption +AlwaysOnTop +owner
Gui,show, x0 y0 w%A_ScreenWidth% h%A_ScreenHeight%,Overlay

; Dim from 100 to 240 transparency in steps of 5

Loop, 30
{
	WinSet, Transparent, %startdim%, Overlay
	startdim += 5
	Sleep, 50
}

; Create countdown clock text Control
Gui, Font, s12, Verdana
Gui, Add, Text, x%txpos% y%typos% cGray, Press Pause/Break key on keyboard to skip, press again for settings
Gui, Font, s72, Verdana
Gui, Add, Text, x%xpos% y%ypos% cGray, 00:00 


; Count down seconds and derive xx:xx minutes:seconds string from seconds left  

While DurationSeconds != 0
{
	displaytime := FormatSeconds(DurationSeconds)
	StringRight, displaytime, displaytime, 5
	ControlSetText, Static2, %displaytime% , Overlay
	DurationSeconds -= 1
	Sleep, 1000
  If CutOff = 1
    break
}

; Close GUI after countdown is done and re-enable Mouse

Gui, Destroy
BlockInput, MouseMoveOff 
MouseMove, %xposi%, %yposi%,0
SystemCursor("On")
SetTimer, LockScreen, -%Time1%

return

FormatSeconds(NumberOfSeconds)  ; Convert the specified number of seconds to hh:mm:ss format.
{
    time = 19990101  ; *Midnight* of an arbitrary date.
    time += %NumberOfSeconds%, seconds
    FormatTime, mmss, %time%, mm:ss
    return NumberOfSeconds//3600 ":" mmss
    
}

LWin:: ; Disable Windows key
IfWinNotActive, Overlay
	Send {LWin}
return 

RWin:: ; Disable Windows key
IfWinNotActive, Overlay
	Send {RWin}
return 

; Break/Pause key hotkey, if pressed while countdown GUI is active cancel countdown. If not open settings GUI

Pause::
IfWinExist, Overlay
{	
  Gui, Destroy
	BlockInput, MouseMoveOff
  MouseMove, %xposi%, %yposi%,0
	SystemCursor("On") ; Error catch incase Pause key is pressed during break 
  CutOff = 1	
  Sleep, 200
} 
else 
{
    IfWinNotExist, LB        
         Goto, start
    IfWinExist, LB
    {
		  Gosub, WriteSettings
		  Gui, Destroy
      Goto, CheckTime
    }
}

Exit

!F4::  ; Disable Alt+F4 if break window is active
IfWinExist, Overlay
{
    return
}
Else
{
    WinClose, A
    return
}

SetStart:

Gui, Submit, NoHide

If RunAtStart = 1
{
    SplitPath, A_Scriptname, , , , OutNameNoExt 
    LinkFile=%A_Startup%\%OutNameNoExt%.lnk 
    IfNotExist, %LinkFile% 
      FileCreateShortcut, %A_ScriptFullPath%, %LinkFile% 
    SetWorkingDir, %A_ScriptDir%
}
else
{
    SplitPath, A_Scriptname, , , , OutNameNoExt 
    LinkFile=%A_Startup%\%OutNameNoExt%.lnk 
    IfExist, %LinkFile% 
      FileDelete, %LinkFile% 
    SetWorkingDir, %A_ScriptDir%
}


return



; Function to check if variables are set, used in WriteSettings subroutine. Credit to SKAN from ahk forums 
; http://www.autohotkey.com/board/topic/7984-ahk-functions-incache-cache-list-of-recent-items/page-3#entry78387

VarExist(Var="")        {       ; * * * Determines a variable existence. * * *
                                ;
IfEqual, Var,,Return, 0         ; If no parameter, return 0
                                ;
VarAddr = % & %Var%             ; Obtain pointer to the variable
                                ;
q := "Var" . Chr(160)           ; x will contain a non-existing variable name
NonExistent := &%q%             ; Obtain pointer to the non-existing variable
                                ;
if ( VarAddr = NonExistent ) {  ; Compare both the pointers and
   Return, 0                    ; if equal, Return 0 to indicate that
                             }  ; the variable does not exist 
else                            ;
   If ( %Var% = "" )         {  ; If Var is empty Return 2
      Return, 2                 ;  
                             }  ;
Return 1                        ; If above conditions do not apply, Return 1
                        }       ; to indicate variable exists with data

; Function to hide/show the mouse cursor. Credit to shimanov from ahk forums
; http://www.autohotkey.com/board/topic/5727-hiding-the-mouse-cursor/#entry35098

SystemCursor(OnOff=1)   ; INIT = "I","Init"; OFF = 0,"Off"; TOGGLE = -1,"T","Toggle"; ON = others
{
   static AndMask, XorMask, $, h_cursor
      ,c0,c1,c2,c3,c4,c5,c6,c7,c8,c9,c10,c11,c12,c13  ; system cursors
        , b1,b2,b3,b4,b5,b6,b7,b8,b9,b10,b11,b12,b13  ; blank cursors
        , h1,h2,h3,h4,h5,h6,h7,h8,h9,h10,h11,h12,h13  ; handles of default cursors
   if (OnOff = "Init" or OnOff = "I" or $ = "")       ; init when requested or at first call
   {
      $ = h                                           ; active default cursors
      VarSetCapacity( h_cursor,4444, 1 )
      VarSetCapacity( AndMask, 32*4, 0xFF )
      VarSetCapacity( XorMask, 32*4, 0 )
      system_cursors = 32512,32513,32514,32515,32516,32642,32643,32644,32645,32646,32648,32649,32650
      StringSplit c, system_cursors, `,
      Loop %c0%
      {
         h_cursor   := DllCall( "LoadCursor", "uint",0, "uint",c%A_Index% )
         h%A_Index% := DllCall( "CopyImage",  "uint",h_cursor, "uint",2, "int",0, "int",0, "uint",0 )
         b%A_Index% := DllCall("CreateCursor","uint",0, "int",0, "int",0
                             , "int",32, "int",32, "uint",&AndMask, "uint",&XorMask )
      }
   }
   if (OnOff = 0 or OnOff = "Off" or $ = "h" and (OnOff < 0 or OnOff = "Toggle" or OnOff = "T"))
      $ = b       ; use blank cursors
   else
      $ = h       ; use the saved cursors

   Loop %c0%
   {
      h_cursor := DllCall( "CopyImage", "uint",%$%%A_Index%, "uint",2, "int",0, "int",0, "uint",0 )
      DllCall( "SetSystemCursor", "uint",h_cursor, "uint",c%A_Index% )
   }
}
