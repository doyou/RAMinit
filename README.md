;
; RI.ASM  Revision 2.12         [ July 12, 1994 ]
Revision        equ     'V2.12 '
;
; **************************************************************************
; *                                                                        *
; *  RAMinit  Release 2.0                                                  *
; *  Copyright (c) 1989-1994 by Yellow Rose Software Co.                   *
; *  Written by Mr. Leijun                                                 *
; *                                                                        *
; *  Function:                                                             *
; *    Press HotKey to remove all TSR program after this program           *
; *                                                                        *
; **************************************************************************

; ..........................................................................
; Removed Softwares by RI:
;   SPDOS v6.0F, WPS v3.0F
;   Game Busters III, IV
;   NETX ( Novell 3.11 )
;   PC-CACHE
;   Norton Cache
;   Microsoft SmartDrv
;   SideKick 1.56A
;   MOUSE Driver
;   Crazy (Monochrome simulate CGA program)
;   RAMBIOS v2.0
;   386MAX Version 6.01
; ..........................................................................
; No cancel softwares:
;   Windows 3.1 MSD
;
; No removed TSR softwares:
;   MS-DOS fastopen
;   Buffers, Files ... (QEMM 6.0)
;   QCache (386MAX 6.01)
; ..........................................................................
;
COMMENT *

 V2.04  Use mouse driver software reset function to initiation mouse
        2/17/1993 by  Mr. Lei and Mr. Feng
 V2.05  RI cannot work in Windows DOS prompt
        3/9/1993  by Mr. Lei
 V2.06  1. When XMS cannot allocate 1K memory, RI halts.
        2. RI repeat deallocates EMS memory.
 V2.07  HotKey Setup Error
        4/25/1993 by Mr. Lei
 V2.08  KB Buffer
 V2.10  1. Release high memory blocks (EMM386 QEMM386 S-ICE 386MAX)
        2. RI copies flag
 V2.12  1. Exists a critical error in Init 8259 procedure
        2. Save [40:F0--FF] user data area

*
