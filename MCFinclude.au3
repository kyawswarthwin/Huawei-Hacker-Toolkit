; =======================================================================================================================
; Title .........: MCFinclude.au3
; AutoIt Version : 3.3.12
; Description ...: CodeCrypter target's UDFs
; Author.........: A.R.T. Jonkers (RTFC)
; Release........: 1.1
; Latest revision: 23 Jun 2014
; License........: free for personal use; free distribution allowed provided
;							the original author is credited; all other rights reserved.
; Tested on......: W7Pro/64
; Forum Link.....: http://www.autoitscript.com/forum/topic/155537-mcf-metacode-file-udf/
;
; Related to......: CodeScanner, MCF, CodeCrypter, all by RTFC
; Dependencies...: AES.au3, by Ward; see http://www.autoitscript.com/forum/topic/121985-autoit-machine-code-algorithm-collection/
; Acknowledgements: Ward, for AES.au3, part of AutoIt Machine Code Algorithm Collection\Encode
; ===============================================================================================================================
; Remarks
;
; * Edit/Add keytype definitions in the last UDF of this script: _MCFCC_Init()
;
; * This UDF is called by CodeCrypter, and should be #included into any script
;		you wish to CodeCrypt. Any code prior to this #include will not be encrypted;
;		all code following it will be encrypted.
;
; * Please do NOT explicitly include any other MCF-related scripts into your target script!
;
; * If you make changes to this UDF, save it under a new name and change
;		global variable $MCFinclude in this script to reflect this.
;
; * The default encryption engine is Ward's excellent AES UDF. You have to
;		download that yourself.
;		You can replace this by whatever algorithm you desire, BUT be aware that
;		any code you replace it with has to be FAST ENOUGH not to slow down the
;		the script too much (as it may be called in almost every line).
;		Timing-dependent code (e.g., Adlib calls, user event loops in games) may
;		FAIL if decryption handling time >= loop interval (causing stack queueing
;		and/or stack overflow = crashing or hanging script).
;
; * A list of actions to take when replacing your encryption algorithm is given
;		in the Remarks of MCF.au3
;
; * If processing is too slow, reduce the proportion of encrypted lines <100%
;		by setting 	$MCF_ENCRYPT_SUBSET=true, and
;						$subset_proportion <1 (N*100 = percentage, randomly assigned), or
;						$subset_proportion >1 (cycled = 1 in N lines encrypted)
;
; * Encryption can be two-pass (nested):
;		- outer shell encrypted with key $CCkey[0], using a fixed string (supplied)
;		- inner shell encrypted with key $CCkey[#], containing whatever you want, defined at runtime
;			some simple examples are provided in _MCFCC_Init()
;	Note: you can switch to single-pass by setting $MCF_ENCRYPT_NESTED=False
;
; * Set your selected keytype by calling _MCFCC_Init(#) (# = number)
;		if instead # = <string>, this string is stored in $CCkey[1] for ENcryption.
;		The declaration of $CCkey[1] in the MCFinclude.au3 included in your script
;		remains an empty string, to be filled at target's runtime by either a parsed
;		commandline parameter or a user password query.
;
; * IMPORTANT: $CCkey[#] (#>0) should NOT contain a fixed definition.
;		Instead, use data retrieved at runtime, for example:
;		- from the user (password query)
;		- from the host machine (e.g, macros, keyfile, machine specs, environment var...)
;		- from a local server or web server
;		- from an external device
;		- use your inagination
;
; * IMPORTANT: you are not restricted to your own user environment;
;		variable $decryption_key can be preset with whatever is expected in the
;		target environment. See CodeCrypter's Remarks for more details.
;
; * if you use environment variables to define a key ($CCkey[#]=EnvGet("SOME_VAR"),
;		and that variable does not exist in the target environment, an empty string
;		would be returned by EnvGet(), triggering a (likely unwanted) password query
;		at startup if it was used as single key or the only empty key in a shuffled
;		range. Any other encryption combination would simply fail.
;		So ensure beforehand that your environment variable exists in the target
;		environment, or use something else instead.
;
; * You can combine multiple keytypes by:
;		1. grouping them consecutively in $CCkey[X] to $CCkey[Y]
;		- setting $MCF_ENCRYPT_SHUFFLEKEY=True
;		- defining the range by setting $CCkeyshuffle_start=X and $CCkeyshuffle_end=Y
;		This way the encryption keytype will be assigned at random per encrypted line.
;
; ===============================================================================================================================

#include-once
; see www.autoitscript.com/forum/topic/121985-autoit-machine-code-algorithm-collection/
#include ".\AES.au3"	; by Ward
; NB in AES.au3 replace line 16	: Global Const Enum $AES_CBC_MODE, $AES_CFB_MODE, $AES_OFB_MODE
; 										by	: Global Const $AES_CBC_MODE=0, $AES_CFB_MODE=1, $AES_OFB_MODE=2

#region Indirection (to be obfuscated only)
; do not edit this region

; if enabled, these functions replace (unencrypted) direct assignments by
; (encryptable) function calls

; this func def should be the first one of this region,
;	as it is used as its start marker
Func _VarIsVar(ByRef $a, ByRef $b)
	$a=$b			; e.g., for copying arrays
EndFunc


Func _ArrayVarIsVar(ByRef $a, $b, ByRef $c)
	$a[$b]=$c
EndFunc


Func _VarIsArrayVar(ByRef $a, ByRef $b, $c)
	$a=$b[$c]
EndFunc


Func _ArrayVarIsArrayVar(ByRef $a, $b, ByRef $c, $d)
	$a[$b]=$c[$d]
EndFunc


Func _VarIsNumber(ByRef $a, $number)
	$a=Number($number)
EndFunc


Func _ArrayVarIsNumber(ByRef $a, $b, $number)
	$a[$b]=Number($number)
EndFunc

#endregion Indirection (to be obfuscated only)

#region Encryption1 (to be obfuscated only)

; IMPORTANT: if this calls fails, it is likely that AES.au3 was not found in the local directory (so move it there, or edit the path in the #include directive above)
_AES_Startup()

; do NOT edit this part!
Global $MCFinclude="MCFinclude.au3"		; this script
Global $CCkeytype=0
Global $CCkey[2]								; absolute minimum size
$CCkey[0]="0x3CA86772DB0B25CBD8AC911792C2217A9DD04C218DAE0F4261BD76EF512838FBDE2BDA417829E56D62EDE396B376E2CC"	; do not edit

; you can change the CONTENTS of this call with whatever decryption algorithm you like
; as long as you also change the decryption call in MCF:_EncryptEntry()
Func _MCFCC(Const $hexstring,$index=0)
	Return BinaryToString(_AesDecrypt($CCKey[$index],$hexstring))
EndFunc
; this func def should be the last one of this region,
;	as it is used as its end marker

#endregion Encryption1 (to be obfuscated only)

#region Encryption2 (to be fixed-key encrypted)

_dummyCalls()			; do not remove!

Func _dummyCalls()	; DO NOT EDIT!
; prevents MCF:_CreateSingleBuild() from removing the defs as redundant
; this UDF will be fixed-key encrypted

	; nested keytype for _MCFCCXB calls
	_MCFCC_Init(0,False)		; DO NOT REMOVE! To be edited by CodeCrypter with your selected keytype!
	_MCFCC("")					; DO NOT REMOVE! Otherwise decryptor UDF is considered redundant!

	Local $a=0,$b=1
	Local $c[1]
	_VarIsVar($a,$b)					; copy var
	_ArrayVarIsVar($c,0,$a)			; copy single value into indexed array location
	_VarIsArrayVar($a,$c,0)			; copy single value from indexed array location
	_ArrayVarIsArrayVar($c,0,$c,0); copy indexed array location to indexed array location
	_VarIsNumber($a,1)				; assign number to var
	_ArrayVarIsNumber($c,0,1)		; assign number to indexed array location

EndFunc


Func _MCFCC_Init($type=0,$query=True)
; NOTE: edit/add your keytype definitions here
; this UDF itself will be fixed-key encrypted

	ReDim $CCkey[8]
	If $cmdline[0]>0 Then
		$CCkey[1]=$cmdline[1]	; option to parse decryption key at commandline
	Else
		$CCkey[1]=""	; an empty string triggers decryption key (password) query at startup
	EndIf
	$CCkey[2]="C"	; some simple examples...
	$CCkey[3]="r"		; case-sensitive!
	$CCkey[4]="a"
	$CCkey[5]="c"
	$CCkey[6]="k"	; ensure this is fixed (no DHCP) on the machine that will run your target
	$CCkey[7]="Me"	; should be permanent, so if using your own, do not set with EnvSet()
	; add your own definitions here...

	If $type="" Then $type=1
	If $type<=0 Or $type>UBound($CCkey)-1 Then	; store parsed string or string(out-of-bounds keytype) at index 1
		$CCkeytype=1
		$CCkey[$CCkeytype]=String($type)	; redefines entry 1 as string(parsed param); does not need to be a number
		Return
	EndIf

	If $CCkey[$type]="" And $query=True Then $CCkey[$type]=InputBox("Protected Application","Please Enter your Password: ","","*",250,140)
	$CCkeytype=$type

EndFunc
; this func def should be the last one of this region,
;	as it is used as its end marker (do NOT rename it)

#endregion Encryption2 (to be fixed-key encrypted)

; Anything below this region will be encrypted twice (when nested encryption is set):
;	1) runtime-encryption using your selected keytype, itself nested inside:
;  2) a fixed-key encryption (using the contents of $CCkey[0] as key)
; If nested encryption is disabled, anything below this region will be encrypted with
;		runtime-encryption using your selected keytype.
;
; Theoretically, it is possible for an attacker to discover HOW you *define* your key,
; but NOT its contents, unless they have full access to your target user environment.
; For example, by decrypting MCFCC_Init and the outer layer of an encrypted call,
; they could discover that you chose to use the serial number of the host's C: drive,
; but unless they have access to that machine to obtain that serial number,
; the contents of your script would remain secure.

