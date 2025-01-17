; Twitch Channel Point Sounds v1.0.0 by hoffer (github.com/hoffer)
; Using GPT v2 license - Contribution is welcome!

; -----------------
; SETUP & MAIN LOOP
; -----------------

Gosub,Init

loop ; main script idle loop to enable 'minimize to tray' functionality
{
	WinGet,minmaxState,MinMax,% "ahk_id" scriptHwnd
	if (minmaxState = -1)
    {
        WinHide,% "ahk_id" scriptHwnd
		Menu,Tray,Icon
		loop
		{
			WinGet,minmaxState,MinMax,% "ahk_id" scriptHwnd
			if !(minmaxState = -1)
				break
			sleep,500
		}
	}
	sleep,500
}
reload
exitapp


Init:
    #Persistent
    #SingleInstance,Force
    #NoTrayIcon
    SetBatchLines, -1
    ComObjError(0) ; prevents it from yelling at me when i try to check an element that doesnt exist, else var check must be wrapped in a try statement
	version := "1.0.2"
	
    ; set up for minimizing to tray
    DetectHiddenWindows,On
    Menu,Tray,Click,1
    Menu,Tray,Tip,% "Twitch Channel Point Sounds (Click to restore)"
    Menu,Tray,NoStandard
    Menu,Tray,Add,Restore,RestoreLabel
    Menu,Tray,Add,Exit,ExitLabel
    Menu,Tray,Default,Restore
	
    Gui, +LastFound +OwnDialogs -MaximizeBox

    scriptHwnd := WinExist()
    Gui, Font, s10, Segoe UI
    Gui, Add, ListView, w600 x5 y5 r8 h200 gMyListView vMyListView, Redeem name|File path
    Gui, Add, Button, w100 x5 y210 gAddItem,% "Add Sound"
    Gui, Add, Button, w100 x115 y210 gAddTTS,% "Add TTS"
    Gui, Add, Button, w100 x225 y210 gRemoveItem,% "Remove"
    Gui, Add, Button, w100 x335 y210 gEditItemLabel,% "Edit"
    Gui, Add, Button, w100 x445 y210 gTestSound,% "Test sound"

    Gui, Add, Text, x5 y244 w600 0x10  ; Horizontal Line > Etched Gray


    if FileExist(A_ScriptDir . "\access_token.txt")
        FileRead,access_token,% A_ScriptDir . "\access_token.txt"
    else
        FileAppend,,% A_ScriptDir . "\access_token.txt",UTF-8


    if FileExist(A_ScriptDir . "\current_channel.txt")
        FileRead,current_channel,% A_ScriptDir . "\current_channel.txt"
    else
        FileAppend,,% A_ScriptDir . "\current_channel.txt",UTF-8

    if FileExist(A_ScriptDir . "\connect_on_start.txt")
        FileRead,connect_on_start,% A_ScriptDir . "\connect_on_start.txt"
    else
        FileAppend,% "0",% A_ScriptDir . "\connect_on_start.txt",UTF-8
		
	if (connect_on_start = "")
		connect_on_start := 0

    Gui, Add, Button, w100 x5 y251 gModifyLink vButtonLinkStatus,% ""
    Gui, Add, Text, w490 x115 y255 cGreen vTextLinkStatus,% ""

    Gui, Add, Button, w100 x753 y251 gToggleMonitor vToggleMonitor,% ""
    GuiControl,Text,ToggleMonitor,% "Enable Monitor"
    monitorStatus := "disabled"

    Gui, Add, Edit, Limit25 r1 w135 x612 y251 vChannelName hwndHwndChannelName,% current_channel
    SetEditCueBanner(HwndChannelName, "Channel name...")


    conlog_content := ""
    Gui, Font, s7.5 cBlack, Consolas
    Gui, Add, Edit, x612 y5 w240 h240 Vconlog_pane +ReadOnly,% conlog_content
    Gui, Font, s10, Segoe UI
	GuiControlGet,conlog_hwnd,Hwnd,conlog_pane
	SendMessage,0x115,7,0,,% "ahk_id " conlog_hwnd ; scroll to the bottom - 0x115 = WM_VSCROLL, 7 = SB_BOTTOM


    if (access_token)
    {
        authresult := ValidateFunc()
        if !authresult
            gosub,SetAsLinked
        else if (authresult = 401)
            gosub,SetAsLinkUnauthorized
        else if (authresult = "No connection")
            gosub,SetAsLinkCannotReach
    }
    else
        gosub,SetAsNotlinked


	Gui, Add, Text, x5 y286 w850 0x10  ; Horizontal Line > Etched Gray
	
	Gui,Font,cBlack

	Gui, Add, Link,x5 y290, <a href="https://github.com/hoffr/Twitch-Channel-Point-Sounds/issues">Report a bug</a> | <a href="https://github.com/hoffr/Twitch-Channel-Point-Sounds/releases">Check for updates</a> | Channel Point Sounds v%version% by hoffer
	
	Gui, Add, CheckBox, x620 y290 vconnect_on_start gCheckboxConnectOnStart Checked%connect_on_start%, Connect to channel on program start

    Gui, Show,,% "Twitch Channel Point Sounds"


    ; load ini contents into gui
    iniFileName := A_ScriptDir "\channelpointsounds_entries.ini"
    if FileExist(iniFileName)
        gosub,LoadINI
    else
        FileAppend,% "",% iniFileName

	if ((!authresult) && connect_on_start)
		gosub,EnableMonitor

return


ListLinesLabel:
	ListLines
return



; ---------------
; ACCOUNT LINKING
; ---------------


ModifyLink:
	if (accountSectionStatus = "linked")
		gosub,RemoveAccount
	else if (accountSectionStatus = "notlinked")
		gosub,AddAccount
return


SetAsLinked:
	; get username from token
	response := HTTPRequest("GET","https://api.twitch.tv/helix/users", ["Authorization: Bearer " access_token, "Client-Id: jrsf1mi49c951hksfjxgnuzovdu7jr"])
	parsed := JSON_parse(response)
	display_name := parsed.data.0.display_name

	; must be done at program start and then hourly for 3rd party apps that hold onto a token
	Gosub,ValidateLabel
	SetTimer,ValidateLabel,% 1000*60*60
	
	GuiControl,Text,ButtonLinkStatus,% "Remove account"
	
	Gui,Font,cGreen
	GuiControl,Font,TextLinkStatus
	
	GuiControl,Text,TextLinkStatus,% "Account linked: " display_name
	
	GuiControl,Enable,ToggleMonitor
	
	accountSectionStatus := "linked"
return


SetAsNotLinked:

	SetTimer,ValidateLabel,Off

	GuiControl,Text,ButtonLinkStatus,% "Link with Twitch"
	
	Gui,Font,cBlue
	GuiControl,Font,TextLinkStatus
	
	GuiControl,Text,TextLinkStatus,% "Account linking is required to monitor channel point redemptions."
	
	GuiControl,Text,ToggleMonitor,% "Enable Monitor"
	GuiControl,Disable,ToggleMonitor
	
	accountSectionStatus := "notlinked"
return


SetAsLinkUnauthorized:

	SetTimer,ValidateLabel,Off

	GuiControl,Text,ButtonLinkStatus,% "Link with Twitch"
	
	Gui,Font,cRed
	GuiControl,Font,TextLinkStatus
	
	GuiControl,Text,TextLinkStatus,% "Twitch account link was unsuccessful. Please try linking your account again."
	
	GuiControl,Text,ToggleMonitor,% "Enable Monitor"
	GuiControl,Disable,ToggleMonitor
	
	accountSectionStatus := "notlinked"
return


SetAsLinkCannotReach:

	SetTimer,ValidateLabel,Off

	GuiControl,Text,ButtonLinkStatus,% "Link with Twitch"
	
	Gui,Font,cRed
	GuiControl,Font,TextLinkStatus
	
	GuiControl,Text,TextLinkStatus,% "Can't connect to Twitch's servers! Please try again."
	
	GuiControl,Text,ToggleMonitor,% "Enable Monitor"
	GuiControl,Disable,ToggleMonitor
	
	accountSectionStatus := "notlinked"
return


OpenAuthURL:
	run,% "https://id.twitch.tv/oauth2/authorize?response_type=token&client_id=jrsf1mi49c951hksfjxgnuzovdu7jr&redirect_uri=https://hoffr.github.io/get_token.html&scope=channel%3Aread%3Aredemptions"
return


AddAccount:

	SetTimer,OpenAuthURL,-1000
	
	InputBox,access_token,Authentication Token,% "Authenticate this app on the webpage that just opened, then paste the resulting code here:"
	WinActivate,% "ahk_id" scriptHwnd
	if !access_token
		return
	
	Clipboard := "" ; for user safety
	
	; verify token
	authresult := ValidateFunc()
	if (authresult)
		return
	
	FileDelete,% A_ScriptDir . "\access_token.txt"
	FileAppend,% access_token,% A_ScriptDir . "\access_token.txt",UTF-8
	
	gosub,SetAsLinked
	
return


RemoveAccount:
	msgbox,1,% "Confirm",% "Remove Twitch account link from this program? Note that the link will still exist on Twitch's end for your account, accessible in Twitch 'Connections' settings."
	IfMsgbox,OK
	{
		if client
			gosub,DeleteWebSocket
		
		access_token := ""
		FileDelete,% A_ScriptDir . "\access_token.txt"
		FileAppend,,% A_ScriptDir . "\access_token.txt",UTF-8
		
		gosub,SetAsNotLinked
	}
return



; ------------------
; CONNECTION MONITOR
; ------------------


ToggleMonitor:
	if (monitorStatus = "disabled")
		gosub,EnableMonitor
	else if (monitorStatus = "enabled")
		gosub,DisableMonitor
return


EnableMonitor:
	
	GuiControlGet,current_channel,,ChannelName
	if !current_channel
	{
		LogToConsole("ERROR:`nYou must enter a Twitch channel name to monitor")
		return
	}
	
	FileDelete,% A_ScriptDir . "\current_channel.txt"
	FileAppend,% current_channel,% A_ScriptDir . "\current_channel.txt",UTF-8
	
	; convert channel name into a channel ID
	response := HTTPRequest("GET","https://api.twitch.tv/helix/users?login=" current_channel, ["Authorization: Bearer " access_token, "Client-Id: jrsf1mi49c951hksfjxgnuzovdu7jr"])
	parsed := JSON_parse(response)
	id := parsed.data.0.id
	if !id
	{
		LogToConsole("ERROR: Channel name doesn't seem to exist, or there could be an issue with your connection or account link.")
		return
	}
	
	; set up websocket messages
	channelID := id
	nonce := GenerateNonce(32)
	topics := "[""community-points-channel-v1." channelID """]"
	;topics := "[""community-points-channel-v1." channelID """,""channel-points-channel-v1." channelID """]" ; requires channel auth
	request := "{""type"":""LISTEN"",""nonce"":""" nonce """,""data"":{""topics"":" topics ",""access_token"":""" access_token """}}"
	ping := "{""type"":""PING""}"
	
	monitorStatus := "enabled"
	GuiControl,Text,ToggleMonitor,% "Disable Monitor"
	GuiControl,Enable,ToggleMonitor
	
	GoSub,ConnectWebSocketWithRetry
	
return


DisableMonitor:
	if client
		gosub,DeleteWebSocket
return


SetEditCueBanner(HWND, Cue) {  ; https://www.autohotkey.com/board/topic/76540-function-seteditcuebanner-ahk-l/
   Static EM_SETCUEBANNER := (0x1500 + 1)
   Return DllCall("User32.dll\SendMessageW", "Ptr", HWND, "Uint", EM_SETCUEBANNER, "Ptr", True, "WStr", Cue)
}


LogToConsole(logmsg)
{
	global conlog_content, conlog_pane, scriptHwnd, conlog_hwnd
	if !conlog_content
		newlines := ""
	else
		newlines := "`n`n"
	FormatTime,CurrentDateTime,,% "M/d/yyyy H:mm:ss"
	conlog_content .= newlines "[" CurrentDateTime "] " logmsg
	GuiControl,,conlog_pane,% conlog_content

	WinGet,minmaxState,MinMax,% "ahk_id" scriptHwnd
	if !(minmaxState = -1)
		SendMessage,0x115,7,0,,% "ahk_id " conlog_hwnd ; scroll to the bottom - 0x115 = WM_VSCROLL, 7 = SB_BOTTOM
}



; -------------------
; WEBSOCKET & WINHTTP
; -------------------


class PubSub extends WebSocket
{
	
	__New(url, events := 0, async := true, headers := "")
	{
		global pingJitter
		
		LogToConsole("WEBSOCKET OBJECT CREATED")
		
		base.__New(url,events,async,headers)
		
		; set up mandatory routine pings
		Random,pingJitter,0,500
		settimer,Ping,% ((1000 * 120) + pingJitter)
		
	}
	
	OnOpen(Event)
	{
		global request
		
		LogToConsole("CONNECTED")
		
		this.SendText(request) ; send listen request
	}
	
	SendText(text)
	{
		LogToConsole("SEND:`n" text)
		this.Send(text)
	}
	
	OnMessage(Event)
	{
		global itemArr, waitingForPong, queuedSound, tts_redeem_name
		
		LogToConsole("RECEIVE:`n" Event.data)
		
		parsed := JSON_parse(Event.data)
		
		if (parsed.type = "PONG")
			waitingForPong := False
		
		if (parsed.data.message)
		{
			parsed2 := JSON_parse(parsed.data.message)
			
			; be sure not to play sound twice for rewards that act as requests that can be fulfilled or refunded
			; so acting only on unfulfilled requests ensures we act only when the redemption is claimed by the user
			if !(parsed2.data.redemption.status = "UNFULFILLED")
				return
			
			if (parsed2.data.redemption.reward.title)
			{
				if ((tts_redeem_name) && (parsed2.data.redemption.reward.title = tts_redeem_name))
					TTS(parsed2.data.redemption.user_input)
				else
				{
					; parse item fields and play sound if the redeemed channel point item name matches one in our list
					loop % itemArr.Count()
					{
						splitArr := StrSplit(itemArr[A_Index],"|")
						
						if (parsed2.data.redemption.reward.title = splitArr[1])
						{
							queuedSound := splitArr[2]
							soundIsPlaying := True
							SetTimer,WaitPlaySound,100
							settimer,ReleaseSoundFile,% GetAudioDuration(splitArr[2]) * -1
							break
						}
					}
				}
			}
		}
	}
	
	OnClose(Event)
	{
		global client
		LogToConsole("DISCONNECTED:`n" (Event.data ? Event.data : "Unknown reason"))
		client := ""
	}
	
	__Delete()
	{
		Critical,On
		SetTimer,Ping,Off
		settimer,PongCheck,Off
		
		base.__Delete()
		
		LogToConsole("DISCONNECTED")
		LogToConsole("WEBSOCKET OBJECT DELETED")
		Critical,Off
	}

	Ping()
	{
		global ping, waitingForPong
		waitingForPong := True
		settimer,PongCheck,% ((1000 * 10) * -1)
		this.SendText(ping)
	}
	
}


ConnectWebSocketWithRetry:
	
	sleep,% ExponentialBackoff(True)
	
	loop ; attempt a connection, backoff and re-attempt if unsuccessful
	{
		if client
			client := ""
		
		if (monitorStatus = "disabled") ; if user presses the disable button we should stop trying to reconnect
			return
		
		client := new PubSub("wss://pubsub-edge.twitch.tv")
		
		loop 100 ; 10 second timeout per connection attempt
		{
			if (client.readyState = 1)
				return
			sleep,100
		}
		; connection attempt failed, try again after backoff
		LogToConsole("CONNECTION FAILED:`nreadyState: " client.readyState)
		sleep,% ExponentialBackoff(False)
	}
return


GenerateNonce(length) ; random string required for twitch connection
{
	charset := "abcdefghijklmnopqrstuvwxyz0123456789"

	loop % length
	{
		Random,randchar,1,% StrLen(charset)
		nonce .= SubStr(charset,randchar, 1)
	}
	
	return nonce
}


ExponentialBackoff(reset:=False)
{
	static time_ms
	if ((!time_ms) || reset)
		time_ms := 1000
	else
		time_ms := (time_ms * 2)
	if (time_ms >= (1000 * 120))
		time_ms := (1000 * 120)
	return time_ms
}


ValidateLabel:
	if !client
		return
	Critical,On
	ValidateFunc()
	Critical,Off
return


ValidateFunc()
{
	global access_token
	response := HTTPRequest("GET","https://id.twitch.tv/oauth2/validate", ["Authorization: Bearer " access_token])
	
	parsed := JSON_parse(response)
	
	if !(response)
	{
		LogToConsole("CONNECTION ERROR:`nCan't connect to Twitch's servers!")
		gosub,SetAsLinkCannotReach
		gosub,DeleteWebSocket
		return "No connection"
	}
	if (parsed.status = 401)
	{
		LogToConsole("AUTHENTICATION ERROR:`nGot 401 Unauthorized during validation (""" parsed.message """)")
		gosub,SetAsLinkUnauthorized
		gosub,DeleteWebSocket
		return 401
	}

	LogToConsole("Twitch authentication successful")
	return
}


Ping:
	if client
	{
		client.Ping()
		Random,pingJitter,0,500
		settimer,Ping,% ((1000 * 120) + pingJitter)
	}
return


PongCheck:
	if (client && waitingForPong)
	{
		LogToConsole("NO PONG FROM PING")
		gosub,ConnectWebSocketWithRetry
	}
return


DeleteWebSocket:
	client := ""
	monitorStatus := "disabled"
	GuiControl,Text,ToggleMonitor,% "Enable Monitor"
	GuiControl,Enable,ToggleMonitor
return


HTTPRequest(requestType, url, headers:="", message:="")
{
	static prev_request_time
	
	; enforce a 250ms delay between requests to avoid spamming the server
	if prev_request_time
		while ((A_TickCount - prev_request_time) < 250)
			sleep,20
	
	whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
	whr.Open(requestType, url, true)
	
	loop % headers.Count()
	{
		split := StrSplit(headers[A_Index],":")
		name := split[1]
		val := split[2]
		val = %val% ; traditional assignment trims trailing spaces
		whr.SetRequestHeader(name,val)
	}
	if (message = "")
		whr.Send()
	else
		whr.Send(message)
	
	whr.WaitForResponse()
	
	prev_request_time := A_TickCount
	
	return whr.ResponseText
}


JSON_parse(str)
{
	static htmlfile
	if !htmlfile
	{
		htmlfile := ComObjCreate("htmlfile")
		htmlfile.write("<meta http-equiv=""X-UA-Compatible"" content=""IE=edge"">")
	}
	return htmlfile.parentWindow.JSON.parse(str)
}



; -----
; SOUND
; -----


; 2 benefits over ahk's SoundPlay:
; 1. doesn't error when there's a dash in the file name
; 2. doesn't lock the file until another SoundPlay is called or the script exits
PlaySound(soundFile) {
	SND_SYNC := 0, SND_ASYNC := 1, SND_NODEFAULT := 2, SND_MEMORY := 4, SND_LOOP := 8, SND_NOSTOP := 16, SND_NOWAIT := 8192, SND_PURGE := 64, SND_APPLICATION := 128, SND_FILENAME := 262144
	DllCall("winmm.dll\PlaySound", AStr, soundFile, uint, 0, uint, (SND_NODEFAULT|SND_ASYNC))
}


TTS(str:="") ; speak, otherwise return speaking status
{
	static oVoice
	if !oVoice
	{
		oVoice := ComObjCreate("SAPI.SpVoice")
		voices := oVoice.GetVoices()
		for token in voices
			if InStr(token.GetDescription, "Mark")
				voice := (A_Index - 1)
		if !voice
			for token in voices
				if InStr(token.GetDescription, "David")
					voice := (A_Index - 1)
		oVoice.Voice := voices.Item(voice)
		oVoice.Rate := 1
	}
	if str
		oVoice.Speak(str,0x1) ; speak asynchronously
	return oVoice.Status.RunningState ; 2=speaking
}


GetAudioDuration(file) ; get duration of an audio file in ms (+/- 999ms)
{
	global 
	
	o := ComObjCreate("Shell.Application")
	SplitPath,file,file,directory
	od := o.namespace(directory)
	of := od.parsename(file)
	loop,50 ; 50 is an arbitrary number > 21 (number of possible file attributes we can get)
	{
		if(od.getdetailsof("",A_Index) == "Length")
		{
			length := od.getdetailsof(of,A_Index)
			break
		}
	}

	StringSplit,length,length,:
	len_ms := (3600000*length1+60000*length2+1000*length3) + 1000 ; +1000 bcuz length value can't see ms
	return len_ms
}


WaitPlaySound:
	if queuedSound
	{
		if soundIsPlaying
			return
		else
			PlaySound(queuedSound)
	}
	queuedSound := ""
	settimer,WaitPlaySound,Off
return


ReleaseSoundFile:
	soundIsPlaying := False
return



; ------------------------
; GUI - LISTVIEW & GENERAL
; ------------------------


LoadINI:
	IniRead,sections,% iniFileName
    if !sections
	{
		sectionArr := ""
        return
	}
	
	sectionArr := StrSplit(sections,"`n")
	itemArr := []
	
    GuiControl,-Redraw,MyListView
    loop % sectionArr.Count()
	{
        IniRead,redeemName,% iniFileName,% sectionArr[A_Index],% "RedeemName"
		IniRead,filePath,% iniFileName,% sectionArr[A_Index],% "FilePath"
		
		itemArr.Push(redeemName "|" filePath)
		
        LV_Add("",redeemName,filePath)
		
		if (filePath = "Text-to-speech engine")
			tts_redeem_name := redeemName
    }
	;LV_ModifyCol("","AutoHdr")
	LV_ModifyCol()
	GuiControl,+Redraw,MyListView
return


MyListView:
	Critical,On
	Gui +OwnDialogs
	if (A_GuiEvent = "DoubleClick")
	{
		EditItemFunc(A_EventInfo)
	}
	Critical,Off
return


AddItem:
	Critical,On
	Gui +OwnDialogs
	loop
	{
		InputBox,RowText1,% "Redeem name"
		if (ErrorLevel != 0) ; 0 = OK
		{
			Critical,Off
			return
		}
		if (RowText1 = "")
			msgbox,% "Text field cannot be blank, try again"
		if (InStr(RowText1,"\") || InStr(RowText1,"""") || InStr(RowText1,"|"))
		{
			msgbox,% "Text field cannot contain the following characters or else the script will break lol:`n\`n|`n"""
			RowText1 := ""
		}
	} until (RowText1)
	
	FileSelectFile,RowText2,,,,% "Audio (*.wav)"
	if (ErrorLevel != 0) ; 0 = OK
	{
		Critical,Off
		return
	}
	Random,sectionName,10000000000,99999999999
	
	IniWrite,% """" RowText1 """",% iniFileName,% sectionName,% "RedeemName"
	IniWrite,% """" RowText2 """",% iniFileName,% sectionName,% "FilePath"
	
	gosub,DeleteAllRows
	gosub,LoadINI
	Critical,Off
return


AddTTS:
	Critical,On
	Gui +OwnDialogs
	if tts_redeem_name
	{
		Critical,Off
		msgbox,% "Only one TTS can be present. Please remove the existing TTS entry before adding a new one"
		return
	}
	loop
	{
		InputBox,RowText1,% "Redeem name"
		if (ErrorLevel != 0) ; 0 = OK
		{
			Critical,Off
			return
		}
		if (RowText1 = "")
			msgbox,% "Text field cannot be blank, try again"
		if (InStr(RowText1,"\") || InStr(RowText1,"""") || InStr(RowText1,"|"))
		{
			msgbox,% "Text field cannot contain the following characters or else the script will break lol:`n\`n|`n"""
			RowText1 := ""
		}
	} until (RowText1)
	
	Random,sectionName,10000000000,99999999999
	
	IniWrite,% """" RowText1 """",% iniFileName,% sectionName,% "RedeemName"
	IniWrite,% "Text-to-speech engine",% iniFileName,% sectionName,% "FilePath"
	
	gosub,DeleteAllRows
	gosub,LoadINI
	Critical,Off
return


EditItemLabel:
	Critical,On
	Gui +OwnDialogs
	EditItemFunc(LV_GetNext())
	Critical,Off
return


EditItemFunc(selectedRow:="")
{
	global
	
	LV_GetText(RowText1_prev, selectedRow, 1)
	LV_GetText(RowText2_prev, selectedRow, 2)
	
	loop
	{
		InputBox,RowText1,% "Redeem name",,,,,,,,,% RowText1_prev
		if (ErrorLevel != 0) ; 0 = OK
			return
		if (RowText1 = "")
			msgbox,% "Text field cannot be blank, try again"
		if (InStr(RowText1,"\") || InStr(RowText1,"""") || InStr(RowText1,"|"))
		{
			msgbox,% "Text field cannot contain the following characters or else the script will break lol:`n\`n|`n"""
			RowText1 := ""
		}
	} until (RowText1)
	
	if (RowText2_prev != "Text-to-speech engine")
	{
		FileSelectFile,RowText2,,,,% "Audio (*.wav)"
		if (ErrorLevel != 0) ; 0 = OK
			return
	} else
		RowText2 := "Text-to-speech engine"
	
	IniDelete,% iniFileName,% sectionArr[selectedRow]
	
	Random,sectionName,10000000000,99999999999
	
	IniWrite,% """" RowText1 """",% iniFileName,% sectionName,% "RedeemName"
	IniWrite,% """" RowText2 """",% iniFileName,% sectionName,% "FilePath"
	
	gosub,DeleteAllRows
	gosub,LoadINI
}


RemoveItem:
	Critical,On
	Gui +OwnDialogs
	getNext := LV_GetNext()
	
	IniRead,filePath,% iniFileName,% sectionArr[getNext],% "FilePath"
	if (filePath = "Text-to-speech engine")
		tts_redeem_name := ""
	
	IniDelete,% iniFileName,% sectionArr[getNext]
    
	gosub,DeleteAllRows
	gosub,LoadINI
	Critical,Off
return


DeleteAllRows:
	GuiControl,-Redraw,MyListView
	LV_Modify(1,"+Select")
	while (LV_GetNext())
	{
		LV_Delete(1)
		LV_Modify(1,"+Select")
	}
	GuiControl,+Redraw,MyListView
return


TestSound:
	Critical,On
	
	soundTestRow := ""
	LV_GetText(soundTestRow, LV_GetNext(), 2)
	if !soundTestRow
	{
		Critical,Off
		return
	}
	if (soundTestRow != "Text-to-speech engine")
	{
		settimer,ReleaseSoundFile,% GetAudioDuration(soundTestRow) * -1
		PlaySound(soundTestRow)
	} else
		TTS(soundTestRow)
	Critical,Off
return


CheckboxConnectOnStart:
	GuiControlGet, connect_on_start
	FileDelete,% A_ScriptDir . "\connect_on_start.txt"
	FileAppend,% connect_on_start,% A_ScriptDir . "\connect_on_start.txt",UTF-8
return


RestoreLabel:
	Menu,Tray,NoIcon
	WinShow,% "ahk_id " scriptHwnd
	WinRestore,% "ahk_id " scriptHwnd
	WinActivate,% "ahk_id " scriptHwnd
	SendMessage,0x115,7,0,,% "ahk_id " conlog_hwnd ; scroll to the bottom - 0x115 = WM_VSCROLL, 7 = SB_BOTTOM
return


ExitLabel:
exitapp


GuiClose:
ExitApp



;--------------
; WEBSOCKET LIB
;--------------


; WebSocket.ahk by G33kDude: https://github.com/G33kDude/WebSocket.ahk
; 1:1 copied into this script for ease of compilation,
; then modified by github.com/hoffr to convert exception messages to console log lines + take appropriate subsequent action

class WebSocket {
	
	; The primary HINTERNET handle to the websocket connection
	; This field should not be set externally.
	Ptr := 0
	
	; Whether the websocket is operating in Synchronous or Asynchronous mode.
	; This field should not be set externally.
	async := 0
	
	; The readiness state of the websocket.
	; This field should not be set externally.
	readyState := 0
	
	; The URL this websocket is connected to
	; This field should not be set externally.
	url := ""
	
	; Internal array of HINTERNET handles
	HINTERNETs := []
	
	; Internal buffer used to receive incoming data
	cache := "" ; Access ONLY by ObjGetAddress
	cacheSize := 8192
	
	; Internal buffer used to hold data fragments for multi-packet messages
	recData := ""
	recDataSize := 0
	
	; Aborted connection Event
	EVENT_ABORTED := { status: 1006 ; WEB_SOCKET_ABORTED_CLOSE_STATUS
		, reason: "The connection was closed without sending or receiving a close frame." }

	_LastError(Err := -1)
	{
		static module := DllCall("GetModuleHandle", "Str", "winhttp", "Ptr")
		Err := Err < 0 ? A_LastError : Err
		hMem := ""
		DllCall("Kernel32.dll\FormatMessage"
		, "Int", 0x1100 ; [in]           DWORD   dwFlags
		, "Ptr", module ; [in, optional] LPCVOID lpSource
		, "Int", Err    ; [in]           DWORD   dwMessageId
		, "Int", 0      ; [in]           DWORD   dwLanguageId
		, "Ptr*", hMem  ; [out]          LPTSTR  lpBuffer
		, "Int", 0      ; [in]           DWORD   nSize
		, "Ptr", 0      ; [in, optional] va_list *Arguments
		, "UInt") ; DWORD
		return StrGet(hMem), DllCall("Kernel32.dll\LocalFree", "Ptr", hMem, "Ptr")
	}
	
	; Internal function used to load the mcode event filter
	_StatusSyncCallback()
	{
		if this.pCode
			return this.pCode
		b64 := (A_PtrSize == 4)
		? "i1QkDIPsDIH6AAAIAHQIgfoAAAAEdTWLTCQUiwGJBCSLRCQQiUQkBItEJByJRCQIM8CB+gAACAAPlMBQjUQkBFD/cQyLQQj/cQT/0IPEDMIUAA=="
		: "SIPsSEyL0kGB+AAACAB0CUGB+AAAAAR1MEiLAotSGEyJTCQwRTPJQYH4AAAIAEiJTCQoSYtKCEyNRCQgQQ+UwUiJRCQgQf9SEEiDxEjD"
		if !DllCall("crypt32\CryptStringToBinary", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", 0, "UInt*", s := 0, "Ptr", 0, "Ptr", 0)
		{
			LogToConsole("failed to parse b64 to binary")
			gosub,ConnectWebSocketWithRetry
			return
		}
		ObjSetCapacity(this, "code", s)
		this.pCode := ObjGetAddress(this, "code")
		if !DllCall("crypt32\CryptStringToBinary", "Str", b64, "UInt", 0, "UInt", 1, "Ptr", this.pCode, "UInt*", s, "Ptr", 0, "Ptr", 0) &&
		{
			LogToConsole("failed to convert b64 to binary")
			gosub,ConnectWebSocketWithRetry
			return
		}
		if !DllCall("VirtualProtect", "Ptr", this.pCode, "UInt", s, "UInt", 0x40, "UInt*", 0)
		{
			LogToConsole("failed to mark memory as executable")
			gosub,ConnectWebSocketWithRetry
			return
		}
		return this.pCode
		/* c++ source
			struct __CONTEXT {
				void *obj;
				HWND hwnd;
				decltype(&SendMessageW) pSendMessage;
				UINT msg;
			};
			void __stdcall WinhttpStatusCallback(
			void *hInternet,
			DWORD_PTR dwContext,
			DWORD dwInternetStatus,
			void *lpvStatusInformation,
			DWORD dwStatusInformationLength) {
				if (dwInternetStatus == 0x80000 || dwInternetStatus == 0x4000000) {
					__CONTEXT *context = (__CONTEXT *)dwContext;
					void *param[3] = { context->obj,hInternet,lpvStatusInformation };
					context->pSendMessage(context->hwnd, context->msg, (WPARAM)param, dwInternetStatus == 0x80000);
				}
			}
		*/
	}
	
	; Internal event dispatcher for compatibility with the legacy interface
	_Event(name, event)
	{
		this["On" name](event)
	}
	
	; Reconnect
	reconnect()
	{
		this.connect()
	}
	
	pRecData[] {
		get {
			return ObjGetAddress(this, "recData")
		}
	}
	
	__New(url, events := 0, async := true, headers := "")
	{
		this.url := url
		
		this.HINTERNETs := []
		
		; Force async to boolean
		this.async := async := !!async
		
		; Initialize the Cache
		ObjSetCapacity(this, "cache", this.cacheSize)
		this.pCache := ObjGetAddress(this, "cache")
		
		; Initialize the RecData
		; this.pRecData := ObjGetAddress(this, "recData")
		
		; Find the script's built-in window for message targeting
		dhw := A_DetectHiddenWindows
		DetectHiddenWindows, On
		this.hWnd := WinExist("ahk_class AutoHotkey ahk_pid " DllCall("GetCurrentProcessId"))
		DetectHiddenWindows, %dhw%
		
		; Parse the url
		if !RegExMatch(url, "Oi)^((?<SCHEME>wss?)://)?((?<USERNAME>[^:]+):(?<PASSWORD>.+)@)?(?<HOST>[^/:]+)(:(?<PORT>\d+))?(?<PATH>/.*)?$", m)
		{
			LogToConsole("Invalid websocket url")
			gosub,ConnectWebSocketWithRetry
			return
		}
		this.m := m
		
		; Open a new HTTP API instance
		if !(hSession := DllCall("Winhttp\WinHttpOpen"
			, "Ptr", 0  ; [in, optional]        LPCWSTR pszAgentW
			, "UInt", 0 ; [in]                  DWORD   dwAccessType
			, "Ptr", 0  ; [in]                  LPCWSTR pszProxyW
			, "Ptr", 0  ; [in]                  LPCWSTR pszProxyBypassW
			, "UInt", async * 0x10000000 ; [in] DWORD   dwFlags
			, "Ptr")) ; HINTERNET
		{
			LogToConsole("WinHttpOpen failed: " this._LastError())
			gosub,ConnectWebSocketWithRetry
			return
		}
		this.HINTERNETs.Push(hSession)
		
		; Connect the HTTP API to the remote host
		port := m.PORT ? (m.PORT + 0) : (m.SCHEME = "ws") ? 80 : 443
		if !(this.hConnect := DllCall("Winhttp\WinHttpConnect"
			, "Ptr", hSession ; [in] HINTERNET     hSession
			, "WStr", m.HOST  ; [in] LPCWSTR       pswzServerName
			, "UShort", port  ; [in] INTERNET_PORT nServerPort
			, "UInt", 0       ; [in] DWORD         dwReserved
			, "Ptr")) ; HINTERNET
		{
			LogToConsole("WinHttpConnect failed: " this._LastError())
			gosub,ConnectWebSocketWithRetry
			return
		}
		this.HINTERNETs.Push(this.hConnect)
		
		; Translate headers from array to string
		if IsObject(headers)
		{
			s := ""
			for k, v in headers
				s .= "`r`n" k ": " v
			headers := LTrim(s, "`r`n")
		}
		this.headers := headers
		
		; Set any event handlers from events parameter
		for k, v in IsObject(events) ? events : []
			if (k ~= "i)^(data|message|close|error|open)$")
				this["on" k] := v
		
		; Set up a handler for messages from the StatusSyncCallback mcode
		this.wm_ahkmsg := DllCall("RegisterWindowMessage", "Str", "AHK_WEBSOCKET_STATUSCHANGE_" &this, "UInt")
		OnMessage(this.wm_ahkmsg, this.WEBSOCKET_STATUSCHANGE.Bind({})) ; TODO: Proper binding
		
		; Connect on start
		this.connect()
	}
	
	connect() {
		; Collect pointer to SendMessageW routine for the StatusSyncCallback mcode
		static pSendMessageW := DllCall("GetProcAddress", "Ptr", DllCall("GetModuleHandle", "Str", "User32", "Ptr"), "AStr", "SendMessageW", "Ptr")
		
		; If the HTTP connection is closed, we cannot request a websocket
		if !this.HINTERNETs.Length()
		{
			LogToConsole("The connection is closed")
			gosub,ConnectWebSocketWithRetry
			return
		}
		; Shutdown any existing websocket connection
		this.shutdown()
		
		; Free any HINTERNET handles from previous websocket connections
		while (this.HINTERNETs.Length() > 2)
			DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
		
		; Open an HTTP Request for the target path
		dwFlags := (this.m.SCHEME = "wss") ? 0x800000 : 0
		if !(hRequest := DllCall("Winhttp\WinHttpOpenRequest"
			, "Ptr", this.hConnect ; [in] HINTERNET hConnect,
			, "WStr", "GET"        ; [in] LPCWSTR   pwszVerb,
			, "WStr", this.m.PATH  ; [in] LPCWSTR   pwszObjectName,
			, "Ptr", 0             ; [in] LPCWSTR   pwszVersion,
			, "Ptr", 0             ; [in] LPCWSTR   pwszReferrer,
			, "Ptr", 0             ; [in] LPCWSTR   *ppwszAcceptTypes,
			, "UInt", dwFlags      ; [in] DWORD     dwFlags
			, "Ptr")) ; HINTERNET
		{
			LogToConsole("WinHttpOpenRequest failed: " this._LastError())
			gosub,ConnectWebSocketWithRetry
			return
		}
		this.HINTERNETs.Push(hRequest)
		
		if this.headers
		{
			if ! DllCall("Winhttp\WinHttpAddRequestHeaders"
				, "Ptr", hRequest      ; [in] HINTERNET hRequest,
				, "WStr", this.headers ; [in] LPCWSTR   lpszHeaders,
				, "UInt", -1           ; [in] DWORD     dwHeadersLength,
				, "UInt", 0x20000000   ; [in] DWORD     dwModifiers
				, "Int") ; BOOL
			{
				LogToConsole("WinHttpAddRequestHeaders failed: " this._LastError())
				gosub,ConnectWebSocketWithRetry
				return
			}
		}
		
		; Make the HTTP Request
		status := "00000"
		if (!DllCall("Winhttp\WinHttpSetOption", "Ptr", hRequest, "UInt", 114, "Ptr", 0, "UInt", 0, "Int")
			|| !DllCall("Winhttp\WinHttpSendRequest", "Ptr", hRequest, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0, "UPtr", 0, "Int")
			|| !DllCall("Winhttp\WinHttpReceiveResponse", "Ptr", hRequest, "Ptr", 0)
			|| !DllCall("Winhttp\WinHttpQueryHeaders", "Ptr", hRequest, "UInt", 19, "Ptr", 0, "WStr", status, "UInt*", 10, "Ptr", 0, "Int")
			|| status != "101")
		{
			LogToConsole("Invalid status: " status)
			gosub,ConnectWebSocketWithRetry
			return
		}
		
		; Upgrade the HTTP Request to a Websocket connection
		if !(this.Ptr := DllCall("Winhttp\WinHttpWebSocketCompleteUpgrade", "Ptr", hRequest, "Ptr", 0))
		{
			LogToConsole("WinHttpWebSocketCompleteUpgrade failed: " this._LastError())
			gosub,ConnectWebSocketWithRetry
			return
		}
		
		; Close the HTTP Request, save the Websocket connection
		DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
		this.HINTERNETs.Push(this.Ptr)
		this.readyState := 1
		
		; Configure asynchronous callbacks
		if (this.async)
		{
			; Populate context struct for the mcode to reference
			ObjSetCapacity(this, "__context", 4 * A_PtrSize)
			pCtx := ObjGetAddress(this, "__context")
			NumPut(&this         , pCtx + A_PtrSize * 0, "Ptr")
			NumPut(this.hWnd     , pCtx + A_PtrSize * 1, "Ptr")
			NumPut(pSendMessageW , pCtx + A_PtrSize * 2, "Ptr")
			NumPut(this.wm_ahkmsg, pCtx + A_PtrSize * 3, "UInt")
			
			if !DllCall("Winhttp\WinHttpSetOption"
				, "Ptr", this.Ptr   ; [in] HINTERNET hInternet
				, "UInt", 45        ; [in] DWORD     dwOption
				, "Ptr*", pCtx      ; [in] LPVOID    lpBuffer
				, "UInt", A_PtrSize ; [in] DWORD     dwBufferLength
				, "Int") ; BOOL
			{
				LogToConsole("WinHttpSetOption failed: " this._LastError())
				gosub,ConnectWebSocketWithRetry
				return
			}
			
			StatusCallback := this._StatusSyncCallback()
			if (-1 == DllCall("Winhttp\WinHttpSetStatusCallback"
				, "Ptr", this.Ptr       ; [in] HINTERNET               hInternet,
				, "Ptr", StatusCallback ; [in] WINHTTP_STATUS_CALLBACK lpfnInternetCallback,
				, "UInt", 0x80000       ; [in] DWORD                   dwNotificationFlags,
				, "UPtr", 0             ; [in] DWORD_PTR               dwReserved
				, "Ptr")) ; WINHTTP_STATUS_CALLBACK
			{
				LogToConsole("WinHttpSetStatusCallback failed: " this._LastError())
				gosub,ConnectWebSocketWithRetry
				return
			}
			
			; Make the initial request for data to receive an asynchronous response for
			if (ret := DllCall("Winhttp\WinHttpWebSocketReceive"
				, "Ptr", this.Ptr        ; [in]  HINTERNET                      hWebSocket,
				, "Ptr", this.pCache     ; [out] PVOID                          pvBuffer,
				, "UInt", this.cacheSize ; [in]  DWORD                          dwBufferLength,
				, "UInt*", 0             ; [out] DWORD                          *pdwBytesRead,
				, "UInt*", 0             ; [out] WINHTTP_WEB_SOCKET_BUFFER_TYPE *peBufferType
				, "UInt")) ; DWORD
			{
				LogToConsole("WinHttpWebSocketReceive failed: " ret)
				gosub,ConnectWebSocketWithRetry
				return
			}
		}
		
		; Fire the open event
		this._Event("Open", {timestamp:A_Now A_Msec, url: this.url})
	}
	
	WEBSOCKET_STATUSCHANGE(wp, lp, msg, hwnd) {
		if !lp {
			this.readyState := 3
			return
		}
		
		; Grab `this` from the provided context struct
		this := Object(NumGet(wp + A_PtrSize * 0, "Ptr"))
		
		; Don't process data when the websocket isn't ready
		if (this.readyState != 1)
			return
		
		; Grab the rest of the context data
		hInternet :=            NumGet(wp + A_PtrSize * 1, "Ptr")
		lpvStatusInformation := NumGet(wp + A_PtrSize * 2, "Ptr")
		dwBytesTransferred :=   NumGet(lpvStatusInformation + 0, "UInt")
		eBufferType :=          NumGet(lpvStatusInformation + 4, "UInt")
		
		; Mark the current size of the received data buffer for use as an offset
		; for the start of any newly provided data
		offset := this.recDataSize
		
		if (eBufferType > 3)
		{
			closeStatus := this.QueryCloseStatus()
			this.shutdown()
			this._Event("Close", {reason: closeStatus.reason, status: closeStatus.status})
			return
		}

		try {
			if (eBufferType == 0) ; BINARY
			{
				if offset ; Continued from a fragment
				{
					VarSetCapacity(data, offset + dwBytesTransferred)
					
					; Copy data from the fragment buffer
					DllCall("RtlMoveMemory"
					, "Ptr", &data
					, "Ptr", this.pRecData
					, "UInt", this.recDataSize)
					
					; Copy data from the new data cache
					DllCall("RtlMoveMemory"
					, "Ptr", &data + offset
					, "Ptr", this.pCache
					, "UInt", dwBytesTransferred)
					
					; Clear fragment buffer
					this.recDataSize := 0
					
					this._Event("Data", {data: &data, size: offset + dwBytesTransferred})
				}
				else ; No prior fragment
				{
					; Copy data from the new data cache
					VarSetCapacity(data, dwBytesTransferred)
					DllCall("RtlMoveMemory"
					, "Ptr", &data
					, "Ptr", this.pCache
					, "UInt", dwBytesTransferred)
					
					this._Event("Data", {data: &data, size: dwBytesTransferred})
				}
			}
			else if (eBufferType == 2) ; UTF8
			{
				if offset
				{
					; Continued from a fragment
					this.recDataSize += dwBytesTransferred
					ObjSetCapacity(this, "recData", this.recDataSize)
					
					DllCall("RtlMoveMemory"
					, "Ptr", this.pRecData + offset
					, "Ptr", this.pCache
					, "UInt", dwBytesTransferred)
					
					msg := StrGet(this.pRecData, "utf-8")
					this.recDataSize := 0
				}
				else ; No prior fragment
					msg := StrGet(this.pCache, dwBytesTransferred, "utf-8")
				
				this._Event("Message", {data: msg})
			}
			else if (eBufferType == 1 || eBufferType == 3) ; BINARY_FRAGMENT, UTF8_FRAGMENT
			{
				; Add the fragment to the received data buffer
				this.recDataSize += dwBytesTransferred
				ObjSetCapacity(this, "recData", this.recDataSize)
				DllCall("RtlMoveMemory"
				, "Ptr", this.pRecData + offset
				, "Ptr", this.pCache
				, "UInt", dwBytesTransferred)
			}
		}
		finally
		{
			askForMoreData := this.askForMoreData.Bind(this, hInternet)
			SetTimer, %askForMoreData%, -1
		}
	}
	
	askForMoreData(hInternet)
	{
		static ERROR_INVALID_OPERATION := 4317
		; Original implementation used a while loop here, but in my experience
		; that causes lost messages
		ret := DllCall("Winhttp\WinHttpWebSocketReceive"
		, "Ptr", hInternet       ; [in]  HINTERNET hWebSocket,
		, "Ptr", this.pCache     ; [out] PVOID     pvBuffer,
		, "UInt", this.cacheSize ; [in]  DWORD     dwBufferLength,
		, "UInt*", 0             ; [out] DWORD     *pdwBytesRead,
		, "UInt*", 0             ; [out]           *peBufferType
		, "UInt") ; DWORD
		if (ret && ret != ERROR_INVALID_OPERATION)
			this._Error({code: ret})
	}
	
	__Delete()
	{
		this.shutdown()
		; Free all active HINTERNETs
		while (this.HINTERNETs.Length())
			DllCall("Winhttp\WinHttpCloseHandle", "Ptr", this.HINTERNETs.Pop())
	}
	
	; Default error handler
	_Error(err)
	{
		if (err.code != 12030) {
			this._Event("Error", {code: ret})
			return
		}
		if (this.readyState == 3)
			return
		this.readyState := 3
		try this._Event("Close", this.EVENT_ABORTED)
	}
	
	queryCloseStatus() {
		usStatus := 0
		VarSetCapacity(vReason, 123, 0)
		if (!DllCall("Winhttp\WinHttpWebSocketQueryCloseStatus"
			, "Ptr", this.Ptr     ; [in]  HINTERNET hWebSocket,
			, "UShort*", usStatus ; [out] USHORT    *pusStatus,
			, "Ptr", &vReason     ; [out] PVOID     pvReason,
			, "UInt", 123         ; [in]  DWORD     dwReasonLength,
			, "UInt*", len        ; [out] DWORD     *pdwReasonLengthConsumed
			, "UInt")) ; DWORD
			return { status: usStatus, reason: StrGet(&vReason, len, "utf-8") }
		else if (this.readyState > 1)
			return this.EVENT_ABORTED
	}
	
	; eBufferType BINARY_MESSAGE = 0, BINARY_FRAGMENT = 1, UTF8_MESSAGE = 2, UTF8_FRAGMENT = 3
	sendRaw(eBufferType, pvBuffer, dwBufferLength) {
		if (this.readyState != 1)
		{
			LogToConsole("websocket is disconnected")
			gosub,ConnectWebSocketWithRetry
			return
		}
		if (ret := DllCall("Winhttp\WinHttpWebSocketSend"
			, "Ptr", this.Ptr        ; [in] HINTERNET                      hWebSocket
			, "UInt", eBufferType    ; [in] WINHTTP_WEB_SOCKET_BUFFER_TYPE eBufferType
			, "Ptr", pvBuffer        ; [in] PVOID                          pvBuffer
			, "UInt", dwBufferLength ; [in] DWORD                          dwBufferLength
			, "UInt")) ; DWORD
			this._Error({code: ret})
	}
	
	; sends a utf-8 string to the server
	send(str)
	{
		if (size := StrPut(str, "utf-8") - 1)
		{
			VarSetCapacity(buf, size, 0)
			StrPut(str, &buf, "utf-8")
			this.sendRaw(2, &buf, size)
		}
		else
			this.sendRaw(2, 0, 0)
	}
	
	receive()
	{
		if (this.async)
		{
			LogToConsole("Used only in synchronous mode")
			gosub,ConnectWebSocketWithRetry
			return
		}
		if (this.readyState != 1)
		{
			LogToConsole("websocket is disconnected")
			gosub,ConnectWebSocketWithRetry
			return
		}
		
		rec := {data: "", size: 0, ptr: 0}
		
		offset := 0
		while (!ret := DllCall("Winhttp\WinHttpWebSocketReceive"
			, "Ptr", this.Ptr           ; [in]  HINTERNET                      hWebSocket
			, "Ptr", this.pCache        ; [out] PVOID                          pvBuffer
			, "UInt", this.cacheSize    ; [in]  DWORD                          dwBufferLength
			, "UInt*", dwBytesRead := 0 ; [out] DWORD                          *pdwBytesRead
			, "UInt*", eBufferType := 0 ; [out] WINHTTP_WEB_SOCKET_BUFFER_TYPE *peBufferType
			, "UInt")) ; DWORD
		{
			switch eBufferType
			{
				case 0:
				if offset
				{
					rec.size += dwBytesRead
					ObjSetCapacity(rec, "data", rec.size)
					ptr := ObjGetAddress(rec, "data")
					DllCall("RtlMoveMemory", "Ptr", ptr + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
				}
				else
				{
					rec.size := dwBytesRead
					ObjSetCapacity(rec, "data", rec.size)
					ptr := ObjGetAddress(rec, "data")
					DllCall("RtlMoveMemory", "Ptr", ptr, "Ptr", this.pCache, "UInt", dwBytesRead)
				}
				return rec
				case 1, 3:
				rec.size += dwBytesRead
				ObjSetCapacity(rec, "data", rec.size)
				ptr := ObjGetAddress(rec, "data")
				DllCall("RtlMoveMemory", "Ptr", rec + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
				offset += dwBytesRead
				case 2:
				if (offset) {
					rec.size += dwBytesRead
					ObjSetCapacity(rec, "data", rec.size)
					ptr := ObjGetAddress(rec, "data")
					DllCall("RtlMoveMemory", "Ptr", ptr + offset, "Ptr", this.pCache, "UInt", dwBytesRead)
					return StrGet(ptr, "utf-8")
				}
				return StrGet(this.pCache, dwBytesRead, "utf-8")
				default:
				rea := this.queryCloseStatus()
				this.shutdown()
				try this._Event("Close", {status: rea.status, reason: rea.reason})
					return
			}
		}
		if (ret != 4317)
			this._Error({code: ret})
	}
	
	; sends a close frame to the server to close the send channel, but leaves the receive channel open.
	shutdown() {
		if (this.readyState != 1)
			return
		this.readyState := 2
		DllCall("Winhttp\WinHttpWebSocketShutdown", "Ptr", this.Ptr, "UShort", 1000, "Ptr", 0, "UInt", 0)
		this.readyState := 3
	}
}
