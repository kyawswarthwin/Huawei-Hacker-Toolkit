#NoTrayIcon
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Outfile_type=a3x
#AutoIt3Wrapper_Outfile=Release\Huawei Hacker Toolkit.a3x
#AutoIt3Wrapper_Run_After=move "%out%" "Release\Data.dat"
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
;~ #AutoIt3Wrapper_Icon=Icon.ico
;~ #AutoIt3Wrapper_Res_Description=Huawei Hacker Toolkit
;~ #AutoIt3Wrapper_Res_Fileversion=1.2.0.0
;~ #AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2014 Kyaw Swar Thwin
;~ #AutoIt3Wrapper_Res_Language=1033
#include "Include\Android.au3"
#include "Include\Busy.au3"
#include "Include\CRC.au3"
#include "Include\Hex.au3"
#include "Include\UPDATEAPP.au3"
#include <Array.au3>
#include <Crypt.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <Misc.au3>
#include <MsgBoxConstants.au3>
#include <StaticConstants.au3>
#include <WinAPI.au3>
#include <WindowsConstants.au3>
#include "MCFinclude.au3"
#include "Include\Registration.au3"

Global Const $sAppName = "Huawei Hacker Toolkit"
Global Const $sAppVersion = "1.2"
Global Const $sAppPublisher = "Kyaw Swar Thwin"
Global Const $sAppURL = "http://huaweihackertoolkit.nazuka.net"

Global Const $vPrivateKey = __GetUniqueKey("{496DA150-1F60-4B1C-9A04-5F0D91098F9F}")

Global Const $DBT_DEVNODES_CHANGED = 0x0007

Global Const $dSignature1 = Binary("0x0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000")
Global Const $tagHEADER = _
		"byte Signature[4];" & _
		"dword HeadSize;" & _
		"dword Version;" & _
		"char Device[8];" & _
		"dword Sequence;" & _
		"dword BodySize;" & _
		"char Date[16];" & _
		"char Time[16];" & _
		"char Type[16];" & _
		"byte Reserved1[16];" & _
		"align 2;word CRC;" & _
		"align 2;word Unknown;" & _
		"byte Reserved2[2]"
Global Const $dSignature2 = Binary("0x55AA5AA5")

Global $sTitle = $sAppName
Global $sDeviceState, $sManufacturer, $sModelNumber, $sDeviceID, $bRootAccess

If Not @Compiled Then Exit

_Singleton($sAppName & " v" & $sAppVersion)

_Registration_Check($sAppName, $sAppURL, $vPrivateKey)

OnAutoItExitRegister("_OnExit")

DirRemove(@TempDir & "\" & $sAppName, 1)
DirCreate(@TempDir & "\" & $sAppName)

$hGUI = GUICreate($sTitle, 400, 340, -1, -1)
$idFileMenu = GUICtrlCreateMenu("&File")
$idFileExitMenu = GUICtrlCreateMenuItem("E&xit", $idFileMenu)
$idToolsMenu = GUICtrlCreateMenu("&Tools")
$idToolsUnpackMenu = GUICtrlCreateMenu("Unpack", $idToolsMenu)
$idToolsUnpackUPDATEAPPMenu = GUICtrlCreateMenuItem("UPDATE.APP", $idToolsUnpackMenu)
$idToolsRepackMenu = GUICtrlCreateMenu("Repack", $idToolsMenu)
$idToolsRepackUPDATEAPPMenu = GUICtrlCreateMenuItem("UPDATE.APP", $idToolsRepackMenu)
GUICtrlCreateMenuItem("", $idToolsMenu)
$idToolsMiscellaneousMenu = GUICtrlCreateMenu("Miscellaneous", $idToolsMenu)
$idToolsMiscellaneousRemoveImmutableMenu = GUICtrlCreateMenuItem("Remove Immutable", $idToolsMiscellaneousMenu)
$idToolsMiscellaneousRemoveBloatwareMenu = GUICtrlCreateMenuItem("Remove Bloatware", $idToolsMiscellaneousMenu)
$idToolsMiscellaneousDownloadFirmwareMenu = GUICtrlCreateMenuItem("Download Firmware", $idToolsMiscellaneousMenu)
$idToolsNetworkMenu = GUICtrlCreateMenu("Network", $idToolsMenu)
$idToolsNetworkUnlockMenu = GUICtrlCreateMenuItem("Unlock", $idToolsNetworkMenu)
$idToolsNetworkRelockMenu = GUICtrlCreateMenuItem("Relock", $idToolsNetworkMenu)
$idToolsBootloaderMenu = GUICtrlCreateMenu("Bootloader", $idToolsMenu)
$idToolsBootloaderRequestKeyMenu = GUICtrlCreateMenuItem("Request Key", $idToolsBootloaderMenu)
GUICtrlCreateMenuItem("", $idToolsBootloaderMenu)
$idToolsBootloaderUnlockMenu = GUICtrlCreateMenuItem("Unlock", $idToolsBootloaderMenu)
$idToolsBootloaderRelockMenu = GUICtrlCreateMenuItem("Relock", $idToolsBootloaderMenu)
$idToolsFlashMenu = GUICtrlCreateMenu("Flash", $idToolsMenu)
$idToolsFlashUPDATEAPPMenu = GUICtrlCreateMenuItem("UPDATE.APP", $idToolsFlashMenu)
GUICtrlCreateMenuItem("", $idToolsFlashMenu)
$idToolsFlashBootMenu = GUICtrlCreateMenuItem("Boot", $idToolsFlashMenu)
$idToolsFlashRecoveryMenu = GUICtrlCreateMenuItem("Recovery", $idToolsFlashMenu)
$idToolsFlashSystemMenu = GUICtrlCreateMenuItem("System", $idToolsFlashMenu)
$idToolsRebootMenu = GUICtrlCreateMenu("Reboot", $idToolsMenu)
$idToolsRebootRebootMenu = GUICtrlCreateMenuItem("Reboot", $idToolsRebootMenu)
$idToolsRebootRecoveryMenu = GUICtrlCreateMenuItem("Recovery", $idToolsRebootMenu)
$idToolsRebootBootloaderMenu = GUICtrlCreateMenuItem("Bootloader", $idToolsRebootMenu)
$idHelpMenu = GUICtrlCreateMenu("&Help")
$idHelpAboutMenu = GUICtrlCreateMenuItem("&About " & $sAppName & "...", $idHelpMenu)
$idBannerPic = GUICtrlCreatePic(@ScriptDir & "\res\banner.bmp", 0, 0, 400, 160)
$idProductModelLabel = GUICtrlCreateLabel("Product Model:", 10, 180, 76, 17)
$idProductModelInput = GUICtrlCreateInput("", 10, 195, 380, 21)
$idProductIMEIMEIDLabel = GUICtrlCreateLabel("Product IMEI/MEID:", 10, 220, 101, 17)
$idProductIMEIMEIDInput = GUICtrlCreateInput("", 10, 235, 380, 21)
$idProductIDLabel = GUICtrlCreateLabel("Product ID:", 10, 260, 58, 17)
$idProductIDInput = GUICtrlCreateInput("", 10, 275, 380, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
GUIRegisterMsg($WM_DEVICECHANGE, "_WM_DEVICECHANGE")
GUIRegisterMsg($WM_COMMAND, "_WM_COMMAND")
GUISetState()
_GetDeviceInfo()

While 1
	$iMsg = GUIGetMsg()
	Switch $iMsg
		Case $GUI_EVENT_CLOSE, $idFileExitMenu
			Exit
		Case $idToolsUnpackUPDATEAPPMenu
			$sFilePath = FileOpenDialog("Open", @WorkingDir, "Huawei Firmware Files (*.app)|All Files (*.*)", $FD_FILEMUSTEXIST, "UPDATE.APP", $hGUI)
			If Not @error Then
				_Busy_Create("Unpacking...", $BUSY_SCREEN, 200, $hGUI)
				DirCreate(@WorkingDir & "\UPDATE")
				_UPDATEAPP_Unpack($sFilePath, @WorkingDir & "\UPDATE")
				_Busy_Close()
			EndIf
		Case $idToolsRepackUPDATEAPPMenu
			$sFilePath = FileOpenDialog("Open", @WorkingDir & "\UPDATE", "Sequence Files (*.ini)|All Files (*.*)", $FD_FILEMUSTEXIST, "Sequence.ini", $hGUI)
			If Not @error Then
				_Busy_Create("Repacking...", $BUSY_SCREEN, 200, $hGUI)
				_UPDATEAPP_Repack($sFilePath, StringLeft(@WorkingDir, StringInStr(@WorkingDir, "\", Default, -1) - 1) & "\UPDATE.APP.NEW")
				_Busy_Close()
			EndIf
		Case $idToolsMiscellaneousRemoveImmutableMenu
			If $sDeviceState <> "Online" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				If Not $bRootAccess Then
					MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Root Access Is Required.", Default, $hGUI)
				Else
					_Busy_Create("Removing Immutable...", $BUSY_SCREEN, 200, $hGUI)
					_Android_Shell("mkdir /data/local/tmp", True)
					_Android_Shell("rm -r /data/local/tmp/*", True)
					_Android_Push("busybox", "/data/local/tmp")
					_Android_Shell("chmod 755 /data/local/tmp/busybox")
					_Android_Push("set_immutable", "/data/local/tmp")
					_Android_Shell("chmod 755 /data/local/tmp/set_immutable")
					_Android_Push(@ScriptDir & "\shells\remove_immutable.sh", "/data/local/tmp")
					_Android_Shell("chmod 755 /data/local/tmp/remove_immutable.sh")
					_Android_Shell("sh /data/local/tmp/remove_immutable.sh", True)
					_Android_Shell("rm -r /data/local/tmp/*", True)
					_Busy_Update("Rebooting...")
					_Android_Reboot()
					_Busy_Close()
				EndIf
			EndIf
		Case $idToolsMiscellaneousRemoveBloatwareMenu
			If $sDeviceState <> "Online" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				If Not FileExists(@ScriptDir & "\bloatware\" & $sManufacturer & ".lst") Then
					MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
				Else
					If Not $bRootAccess Then
						MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Root Access Is Required.", Default, $hGUI)
					Else
						_Busy_Create("Removing Bloatware...", $BUSY_SCREEN, 200, $hGUI)
						_Android_Shell("mkdir /data/local/tmp", True)
						_Android_Shell("rm -r /data/local/tmp/*", True)
						_Android_Push("busybox", "/data/local/tmp")
						_Android_Shell("chmod 755 /data/local/tmp/busybox")
						_Android_Push(@ScriptDir & "\bloatware\" & $sManufacturer & ".lst", "/data/local/tmp/bloatware.lst")
						_Android_Push(@ScriptDir & "\shells\remove_bloatware.sh", "/data/local/tmp")
						_Android_Shell("chmod 755 /data/local/tmp/remove_bloatware.sh")
						_Android_Shell("sh /data/local/tmp/remove_bloatware.sh", True)
						_Android_Shell("rm -r /data/local/tmp/*", True)
						_Busy_Update("Rebooting...")
						_Android_Reboot()
						_Busy_Close()
					EndIf
				EndIf
			EndIf
		Case $idToolsMiscellaneousDownloadFirmwareMenu
			ShellExecute("http://consumer.huawei.com/cn/support/downloads/index.htm?keyword=" & _Android_GetProperty("ro.product.name"))
		Case $idToolsNetworkUnlockMenu
			If $sDeviceState <> "Online" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				Switch $sManufacturer
					Case "Huawei"
						If Not $bRootAccess Then
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Root Access Is Required.", Default, $hGUI)
						Else
							_Busy_Create("Checking...", $BUSY_SCREEN, 200, $hGUI)
							_Android_Shell("mkdir /data/local/tmp", True)
							_Android_Shell("rm -r /data/local/tmp/*", True)
							$sOEMInfo = "mmcblk0p5"
							_Android_Shell("cat /dev/block/" & $sOEMInfo & " > /data/local/tmp/oeminfo.mbn", True)
							_Android_Shell("chmod 666 /data/local/tmp/oeminfo.mbn", True)
							_Android_Pull("/data/local/tmp/oeminfo.mbn", @TempDir & "\" & $sAppName & "\oeminfo.mbn")
							If _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 8) <> Binary("0x4F454D5F494E464F") Then
								$sOEMInfo = "mmcblk0p8"
								_Android_Shell("cat /dev/block/" & $sOEMInfo & " > /data/local/tmp/oeminfo.mbn", True)
								_Android_Shell("chmod 666 /data/local/tmp/oeminfo.mbn", True)
								_Android_Pull("/data/local/tmp/oeminfo.mbn", @TempDir & "\" & $sAppName & "\oeminfo.mbn")
							EndIf
							$iOffset = _Hex_Search(@TempDir & "\" & $sAppName & "\oeminfo.mbn", Binary("0x010010"))
							If $iOffset = -1 Then
								FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
								_Android_Shell("rm -r /data/local/tmp/*", True)
								_Busy_Close()
								MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
							Else
								$dData1 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3)
								$dData2 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3 + 16 + 3)
								$dData3 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3 + 16 + 3 + 16 + 3)
								If $dData2 <> $dData3 Then
									FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
									_Android_Shell("rm -r /data/local/tmp/*", True)
									_Busy_Close()
									MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
								Else
									If $dData1 = $dData2 Then
										FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
										_Android_Shell("rm -r /data/local/tmp/*", True)
										_Busy_Close()
										MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Network Is Already Unlocked.", Default, $hGUI)
									Else
										_Busy_Update("Unlocking...")
										_Hex_Write(@TempDir & "\" & $sAppName & "\oeminfo.mbn", $dData2, $iOffset + 3)
										_Android_Push(@TempDir & "\" & $sAppName & "\oeminfo.mbn", "/data/local/tmp")
										_Android_Shell("cat /data/local/tmp/oeminfo.mbn > /dev/block/" & $sOEMInfo, True)
										FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
										_Android_Shell("rm -r /data/local/tmp/*", True)
										_Busy_Update("Rebooting...")
										_Android_Reboot()
										_Busy_Close()
									EndIf
								EndIf
							EndIf
						EndIf
					Case Else
						MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
				EndSwitch
			EndIf
		Case $idToolsNetworkRelockMenu
			If $sDeviceState <> "Online" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				Switch $sManufacturer
					Case "Huawei"
						If Not $bRootAccess Then
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Root Access Is Required.", Default, $hGUI)
						Else
							_Busy_Create("Checking...", $BUSY_SCREEN, 200, $hGUI)
							_Android_Shell("mkdir /data/local/tmp", True)
							_Android_Shell("rm -r /data/local/tmp/*", True)
							$sOEMInfo = "mmcblk0p5"
							_Android_Shell("cat /dev/block/" & $sOEMInfo & " > /data/local/tmp/oeminfo.mbn", True)
							_Android_Shell("chmod 666 /data/local/tmp/oeminfo.mbn", True)
							_Android_Pull("/data/local/tmp/oeminfo.mbn", @TempDir & "\" & $sAppName & "\oeminfo.mbn")
							If _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 8) <> Binary("0x4F454D5F494E464F") Then
								$sOEMInfo = "mmcblk0p8"
								_Android_Shell("cat /dev/block/" & $sOEMInfo & " > /data/local/tmp/oeminfo.mbn", True)
								_Android_Shell("chmod 666 /data/local/tmp/oeminfo.mbn", True)
								_Android_Pull("/data/local/tmp/oeminfo.mbn", @TempDir & "\" & $sAppName & "\oeminfo.mbn")
							EndIf
							$iOffset = _Hex_Search(@TempDir & "\" & $sAppName & "\oeminfo.mbn", Binary("0x010010"))
							If $iOffset = -1 Then
								FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
								_Android_Shell("rm -r /data/local/tmp/*", True)
								_Busy_Close()
								MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
							Else
								$dData1 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3)
								$dData2 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3 + 16 + 3)
								$dData3 = _Hex_Read(@TempDir & "\" & $sAppName & "\oeminfo.mbn", 16, $iOffset + 3 + 16 + 3 + 16 + 3)
								If $dData2 <> $dData3 Then
									FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
									_Android_Shell("rm -r /data/local/tmp/*", True)
									_Busy_Close()
									MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
								Else
									If $dData1 = Binary("0x00000000000000000000000000000000") Then
										FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
										_Android_Shell("rm -r /data/local/tmp/*", True)
										_Busy_Close()
										MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Network Is Already Relocked.", Default, $hGUI)
									Else
										_Busy_Update("Relocking...")
										_Hex_Write(@TempDir & "\" & $sAppName & "\oeminfo.mbn", Binary("0x00000000000000000000000000000000"), $iOffset + 3)
										_Android_Push(@TempDir & "\" & $sAppName & "\oeminfo.mbn", "/data/local/tmp")
										_Android_Shell("cat /data/local/tmp/oeminfo.mbn > /dev/block/" & $sOEMInfo, True)
										FileDelete(@TempDir & "\" & $sAppName & "\*.mbn")
										_Android_Shell("rm -r /data/local/tmp/*", True)
										_Busy_Update("Rebooting...")
										_Android_Reboot()
										_Busy_Close()
									EndIf
								EndIf
							EndIf
						EndIf
					Case Else
						MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
				EndSwitch
			EndIf
		Case $idToolsBootloaderRequestKeyMenu
			ShellExecute("http://www.emui.com/plugin.php?id=unlock&mod=detail")
		Case $idToolsBootloaderUnlockMenu
			If $sDeviceState <> "Online" And $sDeviceState <> "Bootloader" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				If $sDeviceState <> "Bootloader" Then
					MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "This Function Only Works In Bootloader Mode.", Default, $hGUI)
				Else
					While 1
						$sKey = InputBox($sTitle, "Key:", Default, Default, 305, 130, Default, Default, Default, $hGUI)
						If @error = 1 Or $sKey <> "" Then
							ExitLoop
						Else
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Key Should Not Be Empty.", Default, $hGUI)
						EndIf
					WEnd
					If Not @error Then
						_Busy_Create("Unlocking...", $BUSY_SCREEN, 200, $hGUI)
						__Run("fastboot oem unlock " & $sKey)
						_Busy_Close()
					EndIf
				EndIf
			EndIf
		Case $idToolsBootloaderRelockMenu
			If $sDeviceState <> "Online" And $sDeviceState <> "Bootloader" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				If $sDeviceState <> "Bootloader" Then
					MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "This Function Only Works In Bootloader Mode.", Default, $hGUI)
				Else
					While 1
						$sKey = InputBox($sTitle, "Key:", Default, Default, 305, 130, Default, Default, Default, $hGUI)
						If @error = 1 Or $sKey <> "" Then
							ExitLoop
						Else
							MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "Key Should Not Be Empty.", Default, $hGUI)
						EndIf
					WEnd
					If Not @error Then
						_Busy_Create("Relocking...", $BUSY_SCREEN, 200, $hGUI)
						__Run("fastboot oem relock " & $sKey)
						_Busy_Close()
					EndIf
				EndIf
			EndIf
		Case $idToolsFlashUPDATEAPPMenu
			If $sDeviceState <> "Online" Then
				MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
			Else
				If $sManufacturer <> "Huawei" Then
					MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
				Else
					_Android_Shell("echo > /storage/sdcard1/sd_card_checker")
					If Not _Android_FileExists("/storage/sdcard1/sd_card_checker") Then
						MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "SD Card Is Required.", Default, $hGUI)
					Else
						_Android_Shell("rm /storage/sdcard1/sd_card_checker")
						$sFilePath = FileOpenDialog("Open", @WorkingDir, "Huawei Firmware Files (*.app)|All Files (*.*)", $FD_FILEMUSTEXIST, "UPDATE.APP", $hGUI)
						If Not @error Then
							_Busy_Create("Pushing...", $BUSY_SCREEN, 200, $hGUI)
							_Android_Shell("mkdir /storage/sdcard1/dload")
							_Android_Shell("rm -r /storage/sdcard1/dload/*")
							_Android_Push($sFilePath, "/storage/sdcard1/dload/UPDATE.APP")
							_Android_Shell("echo > /storage/sdcard1/dload/au_temp.cfg")
							_Busy_Update("Rebooting...")
							_Android_Reboot()
							_Busy_Close()
						EndIf
					EndIf
				EndIf
			EndIf
		Case $idToolsFlashBootMenu
			_Flash("boot")
		Case $idToolsFlashRecoveryMenu
			_Flash("recovery")
		Case $idToolsFlashSystemMenu
			_Flash("system")
		Case $idToolsRebootRebootMenu
			_Reboot()
		Case $idToolsRebootRecoveryMenu
			_Reboot("recovery")
		Case $idToolsRebootBootloaderMenu
			_Reboot("bootloader")
		Case $idHelpAboutMenu
			MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), "About", $sAppName & @CRLF & @CRLF & "Version: " & $sAppVersion & @CRLF & "Developed By: " & $sAppPublisher, Default, $hGUI)
	EndSwitch
WEnd

Func _WM_DEVICECHANGE($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $ilParam
	Switch $iwParam
		Case $DBT_DEVNODES_CHANGED
			_GetDeviceInfo()
	EndSwitch
	Return $GUI_RUNDEFMSG
EndFunc   ;==>_WM_DEVICECHANGE

Func _WM_COMMAND($hWnd, $iMsg, $iwParam, $ilParam)
	#forceref $hWnd, $iMsg, $ilParam
	Switch _WinAPI_LoWord($iwParam)
		Case $idProductModelInput, $idProductIMEIMEIDInput
			Switch _WinAPI_HiWord($iwParam)
				Case $EN_CHANGE
					GUICtrlSetData($idProductIDInput, _GenerateProductID(GUICtrlRead($idProductModelInput), GUICtrlRead($idProductIMEIMEIDInput)))
			EndSwitch
	EndSwitch
EndFunc   ;==>_WM_COMMAND

Func _GetDeviceInfo()
	Local $sNewDeviceState, $sOldDeviceState
	$sNewDeviceState = _Android_GetState()
	If $sDeviceState <> $sNewDeviceState Then
		$sModelNumber = ""
		$sDeviceID = ""
		$sOldDeviceState = $sDeviceState
		$sDeviceState = $sNewDeviceState
		Switch $sDeviceState
			Case "Online"
				$sManufacturer = _Android_GetProperty("ro.product.manufacturer")
				$sModelNumber = _Android_GetProperty("ro.product.model")
				$sDeviceID = _Android_GetDeviceID()
				$bRootAccess = _Android_IsRooted()
			Case "Offline"
				_Connect()
			Case "Bootloader"

			Case Else
				If $sOldDeviceState = "" Then _Connect()
		EndSwitch
		GUICtrlSetData($idProductModelInput, $sModelNumber)
		GUICtrlSetData($idProductIMEIMEIDInput, $sDeviceID)
	EndIf
EndFunc   ;==>_GetDeviceInfo

Func _Connect()
	_Busy_Create("Connecting...", $BUSY_SCREEN, 200, $hGUI)
	_Android_Connect()
	_Busy_Close()
EndFunc   ;==>_Connect

Func _GenerateProductID($sModelNumber, $sDeviceID)
	_Crypt_Startup()
	Local $sMD5, $aChar, $aProductID[8] = [0, 0, 0, 0, 0, 0, 0, 0]
	$sMD5 = StringTrimLeft(_Crypt_HashData($sModelNumber & $sDeviceID, $CALG_MD5), 2)
	$aChar = StringSplit(__HexEx(BitXOR(Dec(StringLeft($sMD5, 8)), Dec(StringRight($sMD5, 8)))), "")
	For $i = 1 To $aChar[0]
		If StringInStr("ABCDEF", $aChar[$i]) Then
			$aProductID[$i - 1] = Chr(Asc($aChar[$i]) - 17)
		Else
			$aProductID[$i - 1] = $aChar[$i]
		EndIf
	Next
	_Crypt_Shutdown()
	Return _ArrayToString($aProductID, "")
EndFunc   ;==>_GenerateProductID

Func _Flash($sMode)
	If $sDeviceState <> "Online" And $sDeviceState <> "Bootloader" Then
		MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
	Else
		If $sDeviceState <> "Bootloader" Then
			MsgBox(BitOR($MB_ICONINFORMATION, $MB_APPLMODAL), $sTitle, "This Function Only Works In Bootloader Mode.", Default, $hGUI)
		Else
			$sFilePath = FileOpenDialog("Open", @WorkingDir, "Image Files (*.img)|All Files (*.*)", $FD_FILEMUSTEXIST, $sMode & ".img", $hGUI)
			If Not @error Then
				_Busy_Create("Flashing...", $BUSY_SCREEN, 200, $hGUI)
				_Android_Flash($sMode, $sFilePath)
				_Busy_Close()
			EndIf
		EndIf
	EndIf
EndFunc   ;==>_Flash

Func _Reboot($sMode = "")
	If ($sDeviceState <> "Online" And $sDeviceState <> "Bootloader") Or (($sMode = "recovery" Or $sMode = "download") And $sDeviceState <> "Online") Then
		MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Found.", Default, $hGUI)
	Else
		If $sMode = "download" And $sManufacturer <> "Samsung" Then
			MsgBox(BitOR($MB_ICONERROR, $MB_APPLMODAL), "Error", "Device Is Not Supported.", Default, $hGUI)
		Else
			_Busy_Create("Rebooting...", $BUSY_SCREEN, 200, $hGUI)
			_Android_Reboot($sMode)
			_Busy_Close()
		EndIf
	EndIf
EndFunc   ;==>_Reboot

Func _OnExit()
	DirRemove(@TempDir & "\" & $sAppName, 1)
EndFunc   ;==>_OnExit

Func __GetUniqueKey($vKey)
	_Crypt_Startup()
	Local $dUniqueKey = _Crypt_EncryptData(StringTrimLeft(_Crypt_HashFile(@ScriptFullPath, $CALG_MD5), 2), $vKey, $CALG_RC4)
	_Crypt_Shutdown()
	Return $dUniqueKey
EndFunc   ;==>__GetUniqueKey

Func __HexEx($iDec)
	Local $sHex = Hex($iDec)
	While StringLeft($sHex, 1) = "0"
		$sHex = StringMid($sHex, 2)
		If StringLeft($sHex, 1) <> "0" Then ExitLoop
	WEnd
	Return $sHex
EndFunc   ;==>__HexEx
