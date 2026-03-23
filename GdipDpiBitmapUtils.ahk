#Requires AutoHotkey v1.1.36+
#Include %A_ScriptDir%
#Include .\lib\DpiAwareCoord.ahk
#Include .\lib\DpiAwarenessContextUtils.ahk
#Include .\lib\MonitorExGetUtils.ahk
#Include .\vendor\Gdip_All.ahk ;  Tested with https://github.com/mmikeww/AHKv2-Gdip/blob/cab5ae291023c790ce4081630b190b5b88409f48/Gdip_All.ahk
;=============================================================
; GdipDpiBitmapUtils — DPI-aware GDI+ bitmap capture helpers
;
; GitHub: https://github.com/SevenKeyboard/gdip-dpi-bitmap-utils
; Author: SevenKeyboard Ltd. (2026)
; License: The Unlicense
;=============================================================
class VersionManager_GdipDpiBitmapUtils
{
    static _ := VersionManager_GdipDpiBitmapUtils._init()
    _init()    {
        global
        GDIPDPIBITMAPUTILS_VERSION := "2.0.0"
    }
}
;#####################################################################################

; Function				Gdip_DpiBitmapFromScreen
; Base Function			Gdip_BitmapFromScreen
;						https://github.com/mmikeww/AHKv2-Gdip/blob/master/Gdip_All.ahk#L306
;
; notes					Currently, DPI correction is applied only to directly specified coordinates

Gdip_DpiBitmapFromScreen(Screen:=0, Raster:="")
{
	hhdc := 0
	Ptr := A_PtrSize ? "UPtr" : "UInt"
	if (Screen = 0)
	{
		_x := DllCall( "GetSystemMetrics", "Int", 76 )
		_y := DllCall( "GetSystemMetrics", "Int", 77 )
		_w := DllCall( "GetSystemMetrics", "Int", 78 )
		_h := DllCall( "GetSystemMetrics", "Int", 79 )
	}
	else if (SubStr(Screen, 1, 5) = "hwnd:")
	{
		Screen := SubStr(Screen, 6)
		if !WinExist("ahk_id " Screen)
			return -2
		WinGetRect(Screen,,, _w, _h)
		_x := _y := 0
		hhdc := GetDCEx(Screen, 3)
	}
	else if IsInteger(Screen)
	{
		M := GetMonitorInfo(Screen)
		_x := M.Left, _y := M.Top, _w := M.Right-M.Left, _h := M.Bottom-M.Top
	}
	else
	{
		S := StrSplit(Screen, "|")
		_x1 := S[1], _y1 := S[2], _x2 := S[1]+S[3], _y2 := S[2]+S[4]
		i := S.HasKey(5) ? S[5] : 0
		switch GetThreadDpiAwarenessContextIgnoringInfoFlag()
		{
			case -1,-5:
				DpiAwareCoord.convertUnwToMon(_x1, _y1, i, false)
				DpiAwareCoord.convertUnwToMon(_x2, _y2, i, false)
			case -2:
				DpiAwareCoord.convertSysToMon(_x1, _y1, i, false)
				DpiAwareCoord.convertSysToMon(_x2, _y2, i, false)
		}
		_x := Round(_x1), _y := Round(_y1), _w := Round(_x2-_x1), _h := Round(_y2-_y1)
	}

	if (_x = "") || (_y = "") || (_w = "") || (_h = "")
		return -1

	chdc := CreateCompatibleDC(), hbm := CreateDIBSection(_w, _h, chdc), obm := SelectObject(chdc, hbm), hhdc := hhdc ? hhdc : GetDC()
	BitBlt(chdc, 0, 0, _w, _h, hhdc, _x, _y, Raster)
	ReleaseDC(hhdc)

	pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
	SelectObject(chdc, obm), DeleteObject(hbm), DeleteDC(hhdc), DeleteDC(chdc)
	return pBitmap
}

;#####################################################################################

; Function				Gdip_DpiBitmapFromHWND
; Base Function			Gdip_BitmapFromHWND
;						https://github.com/mmikeww/AHKv2-Gdip/blob/master/Gdip_All.ahk#L364

Gdip_DpiBitmapFromHWND(hwnd, UseMatchedThreadDpiContext:=False)
{
	if (UseMatchedThreadDpiContext)    {
		prevCriticalState := A_IsCritical
		Critical On
		PrevThreadDpiCtxRaw := 0
		try  {
			ThreadDpiCtxRaw := GetThreadDpiAwarenessContext()
			WindowDpiCtxRaw := GetWindowDpiAwarenessContext(hWnd)
			try  {
				if !AreDpiAwarenessContextsEqual(ThreadDpiCtxRaw, WindowDpiCtxRaw)
					PrevThreadDpiCtxRaw := SetThreadDpiAwarenessContext(WindowDpiCtxRaw)
			}
			WinGetRect(hwnd,,, Width, Height)
		}  finally  {
			if (PrevThreadDpiCtxRaw)
				try SetThreadDpiAwarenessContext(PrevThreadDpiCtxRaw)
			Critical %prevCriticalState%
		}
	}  else  {
		ThreadDpiCtx := GetThreadDpiAwarenessContextIgnoringInfoFlag()
		WindowDpiCtx := GetWindowDpiAwarenessContextIgnoringInfoFlag(hWnd)
		WinGetRect(hwnd,,, Width, Height)
		switch ThreadDpiCtx
		{
			case -1, -5:
				switch WindowDpiCtx
				{
					case -2:
						PrimaryScale := MonitorExGetScaleFactor()
						Width := Round(Width*PrimaryScale/100)
						Height := Round(Height*PrimaryScale/100)
					case -3, -4:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Round(Width*CurrentScale/100)
						Height := Round(Height*CurrentScale/100)
				}
			default:
				switch WindowDpiCtx
				{
					case -1, -5:
						PrimaryScale := MonitorExGetScaleFactor()
						Width := Round(Width*100/PrimaryScale)
						Height := Round(Height*100/PrimaryScale)
					case -3, -4:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Round(Width*CurrentScale/PrimaryScale)
						Height := Round(Height*CurrentScale/PrimaryScale)
				}
			case -3, -4:
				switch WindowDpiCtx
				{
					case -1, -5:
						MonitorIndex := winGetWhichMonitor(hWnd)
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Round(Width*100/CurrentScale)
						Height := Round(Height*100/CurrentScale)
					case -2:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Round(Width*PrimaryScale/CurrentScale)
						Height := Round(Height*PrimaryScale/CurrentScale)
				}
		}
	}
	hbm := CreateDIBSection(Width, Height), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
	PrintWindow(hwnd, hdc)
	pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
	SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
	return pBitmap
}