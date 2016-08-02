#NoTrayIcon
#region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_Icon=Resource\Icon.ico
#AutoIt3Wrapper_Outfile=Output\Huawei Hacker Toolkit.exe
#AutoIt3Wrapper_Res_Description=Huawei Hacker Toolkit
#AutoIt3Wrapper_Res_Fileversion=1.0.0.0
#AutoIt3Wrapper_Res_LegalCopyright=Copyright © 2013 Kyaw Swar Thwin
#AutoIt3Wrapper_Res_Language=1033
#endregion ;**** Directives created by AutoIt3Wrapper_GUI ****
#include <ButtonConstants.au3>
#include <EditConstants.au3>
#include <GUIConstantsEx.au3>
#include <StaticConstants.au3>
#include <TabConstants.au3>
#include <WindowsConstants.au3>
#include <Constants.au3>
#include <File.au3>
#include "Include\Android.au3"
#include "Include\Busy.au3"

Global Const $sAppName = "Huawei Hacker Toolkit"
Global Const $sAppVersion = "1.0"
Global Const $sAppPublisher = "Kyaw Swar Thwin"

Global Const $sTitle = $sAppName

FileChangeDir(@MyDocumentsDir)

$frmMain = GUICreate($sTitle, 400, 330, -1, -1)
$tabOptions = GUICtrlCreateTab(10, 10, 380, 280)
$tabOptionsUPDATEAPP = GUICtrlCreateTabItem("UPDATE.APP")
$fraUnpackUPDATEAPP = GUICtrlCreateGroup("Unpack UPDATE.APP", 24, 45, 350, 110)
$lblFilePath = GUICtrlCreateLabel("UPDATE.APP File:", 34, 65, 94, 17)
$txtFilePath = GUICtrlCreateInput("", 34, 83, 245, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
$cmdBrowse = GUICtrlCreateButton("Browse...", 289, 80, 75, 25)
$cmdUnpack = GUICtrlCreateButton("Unpack", 289, 115, 75, 25)
GUICtrlSetState(-1, $GUI_DISABLE)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$fraRepackUPDATEAPP = GUICtrlCreateGroup("Repack UPDATE.APP", 24, 165, 350, 110)
$lblFilePath2 = GUICtrlCreateLabel("UPDATE Path:", 34, 185, 76, 17)
$txtFilePath2 = GUICtrlCreateInput("", 34, 203, 245, 21, BitOR($GUI_SS_DEFAULT_INPUT, $ES_READONLY))
$cmdBrowse2 = GUICtrlCreateButton("Browse...", 289, 200, 75, 25)
$cmdRepack = GUICtrlCreateButton("Repack", 289, 235, 75, 25)
GUICtrlSetState(-1, $GUI_DISABLE)
GUICtrlCreateGroup("", -99, -99, 1, 1)
$tabOptionsBootloaderNetworkLock = GUICtrlCreateTabItem("Bootloader/Network Lock")
$cmdBackupOEM_INFO = GUICtrlCreateButton("Backup OEM_INFO", 24, 45, 350, 110)
$cmdRestoreOEM_INFO = GUICtrlCreateButton("Restore OEM_INFO", 24, 165, 350, 110)
GUICtrlCreateTabItem("")
$lblVersion = GUICtrlCreateLabel("Version: " & $sAppVersion, 10, 303, 60, 17)
$lblDeveloper = GUICtrlCreateLabel("Developed By: " & $sAppPublisher, 228, 303, 162, 17)
GUISetState()

While 1
	$iMsg = GUIGetMsg()
	Switch $iMsg
		Case $GUI_EVENT_CLOSE
			Exit
		Case $cmdBrowse
			$sFilePath = FileOpenDialog("Open", @WorkingDir, "UPDATE.APP Files (*.app)|All Files (*.*)", 1, "UPDATE.APP", $frmMain)
			If @error Then
				GUICtrlSetData($txtFilePath, "")
				GUICtrlSetState($cmdUnpack, $GUI_DISABLE)
			Else
				GUICtrlSetData($txtFilePath, $sFilePath)
				GUICtrlSetState($cmdUnpack, $GUI_ENABLE)
			EndIf
		Case $cmdUnpack
			_Busy_Create("Unpacking...", -1, -1, $frmMain)
			DirCreate(@WorkingDir & "\UPDATE")
			__Run('php unpack.php -u "' & $sFilePath & '" "' & @WorkingDir & "\UPDATE" & '"')
			_Busy_Close()
		Case $cmdBrowse2
			$sFilePath = FileSelectFolder("Open", "")
			If @error Then
				GUICtrlSetData($txtFilePath2, "")
				GUICtrlSetState($cmdRepack, $GUI_DISABLE)
			Else
				GUICtrlSetData($txtFilePath2, $sFilePath)
				GUICtrlSetState($cmdRepack, $GUI_ENABLE)
			EndIf
		Case $cmdRepack
			_Busy_Create("Repacking...", -1, -1, $frmMain)
			__Run('php unpack.php -r "' & $sFilePath & '" "' & @WorkingDir & "\UPDATE.APP.NEW" & '"')
			_Busy_Close()
		Case $cmdBackupOEM_INFO
			If _Android_GetDeviceState() <> "Online" Then
				MsgBox(16, $sTitle, "Error: Device Not Found!")
			Else
				If Not _Android_IsDeviceRooted() Then
					MsgBox(16, $sTitle, "Error: Root Access Required!")
				Else
					$sFilePath = FileSaveDialog("Save", @WorkingDir, "Image Files (*.img)|All Files (*.*)", 2 + 16, "OEM_INFO.img", $frmMain)
					If Not @error Then
						_Busy_Create("Backing Up...", -1, -1, $frmMain)
						_Android_Shell("mkdir /data/local/tmp")
						_Android_ShellAsRoot("rm -R /data/local/tmp/*")
						_Android_ShellAsRoot("cat /dev/block/mmcblk0p5 > /data/local/tmp/mmcblk0p5.img")
						_Android_Pull("/data/local/tmp/mmcblk0p5.img", $sFilePath)
						_Android_ShellAsRoot("rm -R /data/local/tmp/*")
						_Busy_Close()
					EndIf
				EndIf
			EndIf
		Case $cmdRestoreOEM_INFO
			If _Android_GetDeviceState() <> "Online" Then
				MsgBox(16, $sTitle, "Error: Device Not Found!")
			Else
				If Not _Android_IsDeviceRooted() Then
					MsgBox(16, $sTitle, "Error: Root Access Required!")
				Else
					$sFilePath = FileOpenDialog("Open", @WorkingDir, "Image Files (*.img)|All Files (*.*)", 1, "OEM_INFO.img", $frmMain)
					If Not @error Then
						_Busy_Create("Restoring...", -1, -1, $frmMain)
						_Android_Shell("mkdir /data/local/tmp")
						_Android_ShellAsRoot("rm -R /data/local/tmp/*")
						_Android_Push($sFilePath, "/data/local/tmp/mmcblk0p5.img")
						_Android_ShellAsRoot("cat /data/local/tmp/mmcblk0p5.img > /dev/block/mmcblk0p5")
						_Android_ShellAsRoot("rm -R /data/local/tmp/*")
						_Android_Reboot()
						_Busy_Close()
					EndIf
				EndIf
			EndIf
	EndSwitch
WEnd
