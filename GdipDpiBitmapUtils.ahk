#Requires AutoHotkey v2.0.0+
#Include "%A_ScriptDir%"
#Include ".\lib\DpiAwareCoord.ahk"
#Include ".\lib\DpiAwarenessContextUtils.ahk"
#Include ".\lib\MonitorExGetUtils.ahk"
#Include ".\vendor\Gdip_All.ahk" ;  Tested with https://github.com/buliasz/AHKv2-Gdip/blob/d3ddef1c11c58cac52c73caab8fcbf47a4dca30c/Gdip_All.ahk
;=============================================================
; GdipDpiBitmapUtils — DPI-aware GDI+ bitmap capture helpers
;
; GitHub: https://github.com/SevenKeyboard/gdip-dpi-bitmap-utils
; Author: SevenKeyboard Ltd. (2026)
; License: The Unlicense
;=============================================================
class VersionManager_GdipDpiBitmapUtils
{
    static _ := this._init()
    static _init()    {
        global
        GDIPDPIBITMAPUTILS_VERSION := "2.0.1"
    }
}
;#####################################################################################

; Function				Gdip_DpiBitmapFromScreen
; Base Function			Gdip_BitmapFromScreen
;						https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk#L283
;
; notes					Currently, DPI correction is applied only to directly specified coordinates

Gdip_DpiBitmapFromScreen(Screen:=0, Raster:="")
{
	hhdc := 0
	if (Screen = 0) {
		_x := DllCall( "GetSystemMetrics", "Int", 76 )
		_y := DllCall( "GetSystemMetrics", "Int", 77 )
		_w := DllCall( "GetSystemMetrics", "Int", 78 )
		_h := DllCall( "GetSystemMetrics", "Int", 79 )
	}
	else if (SubStr(Screen, 1, 5) = "hwnd:") {
		Screen := SubStr(Screen, 6)
		if !WinExist("ahk_id " Screen) {
			return -2
		}
		WinGetRect(Screen,,, &_w, &_h)
		_x := _y := 0
		hhdc := GetDCEx(Screen, 3)
	}
	else if IsInteger(Screen) {
		M := GetMonitorInfo(Screen)
		_x := M.Left, _y := M.Top, _w := M.Right-M.Left, _h := M.Bottom-M.Top
	}
	else {
		S := StrSplit(Screen, "|")
		_x1 := S[1], _y1 := S[2], _x2 := S[1]+S[3], _y2 := S[2]+S[4]
		i := S.Has(5) ? S[5] : 0
		switch GetThreadDpiAwarenessContextIgnoringInfoFlag()
		{
			case -1,-5:
				DpiAwareCoord.ConvertUnwToMon(&_x1, &_y1, i, false)
				DpiAwareCoord.ConvertUnwToMon(&_x2, &_y2, i, false)
			case -2:
				DpiAwareCoord.ConvertSysToMon(&_x1, &_y1, i, false)
				DpiAwareCoord.ConvertSysToMon(&_x2, &_y2, i, false)
		}
		_x := Floor(_x1)
		_y := Floor(_y1)
		_w := Ceil(_x2) - _x
		_h := Ceil(_y2) - _y
	}

	if (_x = "") || (_y = "") || (_w = "") || (_h = "") {
		return -1
	}

	chdc := CreateCompatibleDC()
	hbm := CreateDIBSection(_w, _h, chdc)
	obm := SelectObject(chdc, hbm)
	hhdc := hhdc ? hhdc : GetDC()
	BitBlt(chdc, 0, 0, _w, _h, hhdc, _x, _y, Raster)
	ReleaseDC(hhdc)

	pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)

	SelectObject(chdc, obm)
	DeleteObject(hbm)
	DeleteDC(hhdc)
	DeleteDC(chdc)
	return pBitmap
}

;#####################################################################################

; Function				Gdip_DpiBitmapFromHWND
; Base Function			Gdip_BitmapFromHWND
;						https://github.com/buliasz/AHKv2-Gdip/blob/master/Gdip_All.ahk#L345

Gdip_DpiBitmapFromHWND(hwnd, UseMatchedThreadDpiContext:=False)
{
	if (UseMatchedThreadDpiContext)    {
		prevCriticalState := Critical("On")
		PrevThreadDpiCtxRaw := 0
		try  {
			ThreadDpiCtxRaw := GetThreadDpiAwarenessContext()
			WindowDpiCtxRaw := GetWindowDpiAwarenessContext(hWnd)
			try  {
				if !AreDpiAwarenessContextsEqual(ThreadDpiCtxRaw, WindowDpiCtxRaw)
					PrevThreadDpiCtxRaw := SetThreadDpiAwarenessContext(WindowDpiCtxRaw)
			}
			WinGetRect(hwnd,,, &Width, &Height)
		}  finally  {
			if (PrevThreadDpiCtxRaw)
				try SetThreadDpiAwarenessContext(PrevThreadDpiCtxRaw)
			Critical(prevCriticalState)
		}
	}  else  {
		ThreadDpiCtx := GetThreadDpiAwarenessContextIgnoringInfoFlag()
		WindowDpiCtx := GetWindowDpiAwarenessContextIgnoringInfoFlag(hWnd)
		WinGetRect(hwnd,,, &Width, &Height)
		switch ThreadDpiCtx
		{
			case -1, -5:
				switch WindowDpiCtx
				{
					case -2:
						PrimaryScale := MonitorExGetScaleFactor()
						Width := Ceil(Width*PrimaryScale/100)
						Height := Ceil(Height*PrimaryScale/100)
					case -3, -4:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Ceil(Width*CurrentScale/100)
						Height := Ceil(Height*CurrentScale/100)
				}
			default:
				switch WindowDpiCtx
				{
					case -1, -5:
						PrimaryScale := MonitorExGetScaleFactor()
						Width := Ceil(Width*100/PrimaryScale)
						Height := Ceil(Height*100/PrimaryScale)
					case -3, -4:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Ceil(Width*CurrentScale/PrimaryScale)
						Height := Ceil(Height*CurrentScale/PrimaryScale)
				}
			case -3, -4:
				switch WindowDpiCtx
				{
					case -1, -5:
						MonitorIndex := winGetWhichMonitor(hWnd)
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Ceil(Width*100/CurrentScale)
						Height := Ceil(Height*100/CurrentScale)
					case -2:
						MonitorIndex := winGetWhichMonitor(hWnd)
						PrimaryScale := MonitorExGetScaleFactor()
						CurrentScale := MonitorExGetScaleFactor(MonitorIndex)
						Width := Ceil(Width*PrimaryScale/CurrentScale)
						Height := Ceil(Height*PrimaryScale/CurrentScale)
				}
		}
	}
	hbm := CreateDIBSection(Width, Height), hdc := CreateCompatibleDC(), obm := SelectObject(hdc, hbm)
	PrintWindow(hwnd, hdc)
	pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
	SelectObject(hdc, obm), DeleteObject(hbm), DeleteDC(hdc)
	return pBitmap
}