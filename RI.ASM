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

                dosseg
                .model tiny
                .code
                locals  @@
                org     100h

Start:          jmp     Main
                org     103h

  True          equ     1
  False         equ     0
  MaxHandles    equ     100h

        INT3    macro
                out     0ffh,al
                endm
  ;
  ;             HotKey Status                             Test Var
  ;            ---------------                         ---------------
  ;
  ;  7 6 5 4 3 2 1 0                                    417  418  496
  ;  . . x . x . . .    Left Alt is pressed              8    2
  ;  x . . . x . . .    Right Alt is pressed             8         8
  ;  . . . x . x . .    Left Ctrl is pressed             4    1
  ;  . x . . . x . .    Right Ctrl is pressed            4         4
  ;  . . . . . . x .    Left Shift is pressed            2
  ;  . . . . . . . x    Right Shift is pressed           1
  ;
  LeftAlt       equ     00101000b
  RightAlt      equ     10001000b
  LeftCtrl      equ     00010100b
  RightCtrl     equ     01000100b
  LeftShift     equ     00000010b
  RightShift    equ     00000001b
  HotKey        db      LeftCtrl or RightCtrl

  DataBegin     dw      0
  NextDataSeg   dw      0ffffh
  oldInt2F_addr dw      0, 0
  XMS_control   dw      0, 0
  Handle_begin  dw      0
  cvtOfs        dw      0       ; DOS 3.0 equ 0 and above DOS 4.0 is 1
                org     104h
                db      0dh
                db      Revision
                db      ??date
                db      26
                org     114h
  tsrLength     dw      0
  MachineID     db      0FCh    ; IBM PC/AT

  AuxHotKey     db      0       ; 2Dh     ; 'X' Scan Code
  AuxHotKeyName db      'X$      '
  Power         db      True
  Flag          db      '!'
  Kbd102        db      0
  NoFlag        db      0
  StopFlag      db      1
  DosEnv        dw      0
  WorkSeg       dw      0
  PrevDataSeg   dw      0
  Copies        db      '1'
  old_8259      db      0       ; 21h port
                db      0       ; a1h port

  Status        dw      0
  XMSbit        equ     00000001b
  EMSbit        equ     00000010b
  SKbit         equ     10000000b

GoINT1C:        db      0eah
  oldInt1C_addr dw      0, 0
newINT1C:
                test    cs:Status, SKbit
                jnz     GoINT1C
                cmp     cs:StopFlag, 0
                jz      @@0
;
; Mr. Lei  2/8/1993
; Problem: if WPS quit and reenter, old RI cann't control keyboard.
;
                push    ds
                push    ax
                xor     ax, ax
                mov     ds, ax
                mov     ax, ds:[9*4]
                cmp     ax, offset NewInt9
                pop     ax
                pop     ds
                jnz     GoINT1C
                mov     cs:StopFlag, 0

        @@0:    push    ax
                push    ds
                push    es
                xor     ax, ax
                mov     ds, ax
                mov     es, ds:[9*4+2]
                cmp     word ptr es:[101h], 'IE'        ; 'LEI'
                jz      @@1
                cli
                mov     cs:StopFlag, 1
                mov     ax, ds:[9*4]
                mov     cs:oldINT9_addr2, ax
                mov     ax, ds:[9*4+2]
                mov     cs:oldINT9_addr2[2], ax
                mov     ds:[9*4], offset newINT9_2
                mov     ds:[9*4+2], cs
                sti
        @@1:    pop     es
                pop     ds
                pop     ax
                jmp     GoINT1C

; ----------------------------------------------------------------------
;  INT2F Func
;
;     AX = C0D7h   Return RI segment in AX
;     AX = C0D8h   Removes all TSR programs after RI
;     AX = C0D9h   Removes all TSR programs include RI
;     AX = C0DAh   Removes all RI copies
; ----------------------------------------------------------------------

newINT2F:
                cmp     ax, 0c0d7h      ; LEI Hanzi GB Code
                jnz     @@1
                push    cs
                pop     ax
                iret
        @@1:    cmp     ax, 0c0d7h+1
                jnz     @@2
                jmp     KeepSelf
        @@2:    cmp     ax, 0c0d7h+2
                jnz     @@3
                jmp     NoKeepSelf
        @@3:    cmp     ax, 0c0d7h+3
                jnz     @@9
                mov     cs:NextDataSeg, -1
                mov     cs:Copies, '1'
                jmp     NoKeepSelf
        @@9:    jmp     dword ptr cs:oldInt2F_addr


CallInt9:
                ret


newINT9_2:
                mov     cs:NoFlag, 1
                pushf
                db      9ah             ; call far ptr oldint9_addr
  oldInt9_Addr2 dw      0, 0
                jmp     newINT9_proc

newINT9:
                pushf
                db      9ah             ; call far ptr oldint9_addr
  oldInt9_Addr  dw      0, 0
                cmp     cs:NoFlag, 0
                jz      newINT9_proc
                mov     cs:NoFlag, 0
                iret
newINT9_proc:
                cmp     cs:Flag, '!'    ; busy ?
                jnz     @@0
                iret
        @@0:
                mov     cs:Flag, '!'    ; set busy flag
                push    ax              ; cmp hot key
                push    bx
                push    es
                mov     ax,40h
                mov     es,ax

                cmp     cs:AuxHotKey, 0
                jz      @@_1
                mov     bx, es:[1ah]
                cmp     bx, es:[1ch]
                jz      @@10
                push    bx
                mov     bl, es:[bx+1]
                cmp     bl, cs:AuxHotKey
                pop     bx
                jnz     @@10
        @@_1:
                mov     ah,es:[17h]     ; test CTRL SHIFT ALT
                mov     al,cs:HotKey
                push    ax
                and     ax,0f0fh
                cmp     al,ah
                pop     ax
                jnz     @@10
                cmp     cs:Kbd102, True
                jnz     @@1
                shr     al, 1
                shr     al, 1
                shr     al, 1
                shr     al, 1
                push    ax
                mov     ah, es:[18h]
                and     ax, 303h
                cmp     al, ah
                pop     ax
                jnz     @@10
                mov     ah, es:[96h]
                shr     ax, 1
                shr     ax, 1
                and     ax, 303h
                cmp     al, ah
                jnz     @@10

                cmp     cs:AuxHotKey, 0
                jz      @@_3
                inc     bx
                inc     bx
                cmp     bx, 3eh
                jb      @@_2
                mov     bx, 1eh
        @@_2:
                mov     es:[1ah], bx
        @@_3:
                call    IsWinDos
                or      ax, ax
                jz      @@1
                call    Beep
        @@10:
                sti
                pop     es
                pop     bx
                pop     ax
                mov     cs:Flag, ' '    ; no busy
                iret
        @@1:                                            ; OK
                pop     es
                pop     bx
                pop     ax

KeepSelf:
                call    RemoveTSR
                push    es
                mov     es,cs:WorkSeg
                mov     dx,es:tsrLength
                mov     di,dx
                mov     al,0h           ; Aug 24, 1993
                mov     cx,100h
                rep     stosb
                pop     es
                int     27h

NoKeepSelf:
                mov     ax,0e07h
                int     10h
                mov     cs:clsStr, 47h  ; Color (White in Red)
                call    RemoveTSR
                dec     cs:Copies
                call    RestoreSelfIntVec
                push    es
                cmp     cs:PrevDataSeg, 0
                jz      @@1
                mov     es, cs:PrevDataSeg
                mov     es:NextDataSeg, -1
        @@1:    pop     es
                mov     ax, 4c00h
                int     21h

; ---------------------------------------------------------------------------

IsWinDOS:
                mov     ax, 1600h
                int     2fh
                cmp     al, 01h
                jz      @@9
                cmp     al, 0ffh
                jz      @@9                     ; Windows/386 Version 2.X
                cmp     al, 00h
                jz      @@1
                cmp     al, 80h
                jnz     @@9                     ; Windows 3 in enhanced mode
                                                ; Version number in AL/AH
        @@1:
                mov     ax, 4680h
                int     2fh
                cmp     al, 80h
                jnz     @@9
                xor     ax, ax
                jmp     @@10
        @@9:    mov     ax, 1
        @@10:   ret

; -----------------------------------------------------------------------
RestoreSelfIntVec:
                cmp     Copies, '0'
                jz      @@0
                ret
        @@0:
                cli
                push    cs
                pop     ds
                xor     ax, ax
                mov     es, ax
                mov     si, offset oldInt9_Addr
                mov     di, 9*4
                movsw
                movsw
                mov     si, offset oldInt2F_Addr
                mov     di, 2Fh*4
                movsw
                movsw
                mov     si, offset oldInt1C_Addr
                mov     di, 1Ch*4
                movsw
                movsw
                sti
                ret

; ------------- KERNEL PROGRAM ----------------------------------------------
RemoveTSR:
                pop     ax
                cli                     ; Set stack
                mov     sp, cs
                mov     ss, sp
                mov     sp, 100h
                sti
                push    ax

                cmp     cs:Power, True
                jnz     @@1
                call    Init8259
        @@1:
                push    cs
                pop     ds
        @@_0:
                mov     ax,ds:NextDataSeg
                cmp     ax, -1
                jz      @@_1
                mov     cs:PrevDataSeg, ds
                mov     ds, ax
                jmp     @@_0
        @@_1:   mov     si,ds:DataBegin
                mov     cs:WorkSeg, ds
                lodsw
                cmp     ax, 'XX'
                jz      @@_2
                call    Beep
                ret
        @@_2:
                call    RestoreEnvStr
                call    RestoreMCB         ; restore current mcb
                call    CloseFiles
                call    RestorePort
                call    RestoreLEDs
                call    RestoreVecList     ; Restore vectors list
                call    RestoreFloppyParam
                cmp     cs:Power, True
                jnz     @@2
                call    RestoreCVTchain    ; Restore cvt chain
                call    RestoreMemoryManager
        @@2:
                call    RestoreBiosData
                call    Enable8259
                mov     ah, 1
                int     16h

                call    RestoreClockSpeed
                call    CloseSpeaker
                call    ResetDisk
                call    UpdateTime

                call    ClosePRN
                mov     bx,cs:WorkSeg
                mov     ah,50h
                int     21h                ; Set PSP segment
                mov     ax,3
                int     10h                ; Set display mode

                call    InitPRN
                call    InitMouse
                mov     al, cs:Copies
                cmp     al, '1'
                ja      @@_sh1
                mov     cs:ShowCopies, '*'
                jmp     @@_sh2
        @@_sh1: mov     cs:ShowCopies, al
        @@_sh2:
                mov     si, offset clsStr
                call    ColorPrintStr
                mov     cs:Flag, ' '       ; no busy
                cmp     Copies, '1'
                jnz     @@_end
                mov     cs:StopFlag, 0
        @@_end:
                call    ClearKB_buffer
                ret

Beep:
                mov     ax,0e07h
                int     10h
                ret

; #########################################################################

ClearKB_Buffer:
                push    es
                push    bx
                mov     bx, 0040h
                mov     es, bx
                cli
                mov     bx, es:[1ah]
                mov     es:[1ch], bx
                sti
                pop     bx
                pop     es
                ret


Init8259:
        ;       cmp     cs:Copies, '1'
        ;       jz      @@1
        ;       ret
        @@1:
                cmp     cs:MachineID, 0fch
                ja      @@pc_xt
        @@AT:
                mov     bx,870h         ;
                mov     al,0            ;
                out     0F1h,al         ;
                jcxz    $+2
                jcxz    $+2
                mov     al,11h          ; ICW1
                out     0A0h,al
                jcxz    $+2
                jcxz    $+2
                out     20h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,bl           ; ICW2
                out     0A1h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,bh
                out     21h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,2            ; ICW3
                out     0A1h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,4
                out     21h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,1            ; ICW4
                out     0A1h,al
                jcxz    $+2
                jcxz    $+2
                out     21h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,0FFh         ; OCW1
                out     0A1h,al
                jcxz    $+2
                jcxz    $+2
                out     21h,al
                ret
        @@PC_XT:
                mov     al,13h          ; ICW1
                out     20h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,8            ; ICW2
                out     21h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,9            ; ICW4
                out     21h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,0FFh         ; OCW1
                out     21h,al
                ret

Enable8259:
                mov     ax, word ptr cs:old_8259
                out     021h,al
                jcxz    $+2
                jcxz    $+2
                mov     al,ah
                out     0a1h,al         ; DEC PC Bus Mouse
                ret                     ; July 1994 by Mr. Lei

; -------------------------------------------------------------------------

RestoreBiosData:
                lodsw
                cmp     ax, '--'
                jz      @@1
                call    Beep
                ret
        @@1:    push    es
                push    di
                mov     di, 40h
                mov     es, di

                mov     di, 10h
                movsw
                mov     di, 0a8h         ; [40h:a8h]
                movsw
                movsw
                mov     di, 49h
                mov     cx, 1dh
                rep     movsb

                mov     di, 0f0h         ; User data
                mov     cx, 8
                rep     movsw

                pop     di
                pop     es
                ret

; -------------------------------------------------------------------------

RestoreMCB:
                push    ds
                push    es
                lodsw                           ; 'MZ'
        @@0:    lodsw
                cmp     ax, 'MM'
                jz      @@1
                mov     es,ax
                xor     di,di
                movsb
                movsw
                movsw
                inc     ax
                mov     bx, ds
                cmp     ax, bx
                jz      @@10
                mov     byte ptr es:[8], 0      ; Aug 24, 1993
        @@10:   cmp     byte ptr es:[0], 'Z'
                jnz     @@0
                mov     byte ptr es:[10h], 0
                jmp     @@0
        @@1:
                pop     es
                pop     ds
                ret

; -------------------------------------------------------------------------
CloseFiles:
                mov     ax, 5           ; Begin handle
                push    ds
                push    si
                mov     cx, 15          ; Max handle
                sub     cx, ax
                inc     cx
                mov     bx, ax
        @@1:    push    bx
                push    cx
                mov     ah, 3eh
                int     21h
                pop     cx
                pop     bx
                inc     bx
                loop    @@1
                pop     si
                pop     ds
                ret

; -------------------------------------------------------------------------
RestorePort:
                mov     di, 40h            ; restore port
                mov     es, di
                xor     di, di
                mov     cx, 8
                rep     movsw
                ret

; -------------------------------------------------------------------------
RestoreLEDs:
                lodsb
                and     al, 11110000b      ; LED status
                mov     ah, es:[17h]
                and     ah, 00001111b
                or      ah, al
                and     ah, 0f0h           ; Clear CTRL ALT SHIFT
                mov     es:[17h], ah
                ret

; -------------------------------------------------------------------------
RestoreEnvStr:
                lodsw
                push    si
                push    di
                push    ds
                push    es
                mov     es, cs:DosEnv
                mov     ds, ax
                xor     si, si
                mov     di, si
        @@0:    lodsb
                or      al, al
                jnz     @@1
                cmp     byte ptr ds:[si], 0
                jz      @@2
        @@1:    stosb
                jmp     @@0
        @@2:    stosb
                stosb
                pop     es
                pop     ds
                pop     di
                pop     si
                ret

; -----------------------------------------------------------------------
RestoreVecList:
                xor     ax,ax
                mov     di,ax
                mov     es,ax
                mov     cx,100h
        @@0:    lodsw
                xchg    dx, ax
                lodsw
                cmp     dx, 'EL'
                jnz     @@1
                cmp     al, 'I'
                jnz     @@1
                sub     cl, ah
                push    cx
                mov     cl, ah
                mov     ax, es:[di-4]
                mov     dx, es:[di-2]
         @@a:   stosw
                xchg    ax, dx
                stosw
                xchg    ax, dx
                loop    @@a
                pop     cx
                or      cx, cx
                jz      @@9
                jmp     @@0
        @@1:
                xchg    ax, dx
                stosw
                xchg    ax, dx
                stosw
                loop    @@0
        @@9:
                ret

;----------------------------------------------------------------------------
RestoreFloppyParam:                                     ; Mr. Lei   2/10/1992
                push    es
                push    ax
                xor     ax, ax
                mov     es, ax
                mov     byte ptr es:[525h], 2
                pop     ax
                pop     es
                ret

;---------------------------------------------------------------------------
RestoreCVTchain:
                lodsw
                cmp     ax, 'VC'
                jz      @@_0
                call    Beep
                ret
        @@_0:
                push    ax
                push    cx
                push    es

        ; -----------------------------------------------------------------
                lodsw                   ; DPB
                mov     di, ax
                lodsw
                mov     es, ax
        @@1:    lodsb
                inc     di
                stosb
                add     di, cs:cvtOfs
                add     di, 10h
                movsw
                movsw
                les     di, es:[di+2]
                cmp     di, -1
                jnz     @@1

        ; -----------------------------------------------------------------
                lodsw                   ; DCB
                mov     di, ax
                lodsw
                mov     es, ax
                xor     ax, ax
                dec     ax
                stosw

        ; -----------------------------------------------------------------
                lodsw                   ; Device Driver Chain
                mov     di, ax
                lodsw
                mov     es, ax
                xor     cx, cx
        @@9:    push    di
                mov     cl, 5
                rep     movsw
                pop     di
                les     di, es:[di]
                mov     ax, di
                inc     ax
                jnz     @@9
                pop     es
                pop     cx
                pop     ax
                ret

; ----------------------------------------------------------------------------
RestoreMemoryManager:
                test    cs:Status, XMSbit
                jz      @@1
                call    LoadXMSstatus
        @@1:
                test    cs:Status, EMSbit
                jz      @@2
                call    LoadEMSstatus
        @@2:
                ret


LoadEMSstatus:
                lodsw
                cmp     ax, 'ME'
                jz      @@_0
                call    Beep
                ret
        @@_0:
                lodsw
                mov     cx, ax
                xor     dx, dx
        @@_1:   push    ds
                push    si
                push    dx
                push    cx

        @@0:    cmp     dx, ds:[si]
                jz      @@1
                add     si, 4
                loop    @@0

                push    cx
                mov     cx, 5
        @@__0:  mov     ah, 45h         ; Deallocate Handle and Memory
                int     67h
                or      ah, ah
                jz      @@__1
                loop    @@__0
        @@__1:  pop     cx

        @@1:
                pop     cx
                pop     dx
                pop     si
                pop     ds
                inc     dx
                cmp     dx, 100h
                jb      @@_1
                shl     cx, 1
                shl     cx, 1
                add     si, cx
                ret


LoadXMSstatus:
                lodsw
                cmp     ax, 'MX'
                jz      @@_0
                call    Beep
                ret
        @@_0:
                lodsw
                mov     cx, ax
                jcxz    @@5
        @@1:
                lodsw
                mov     dx, ax
        @@2:    push    dx
                mov     ah, 0ah                 ; free
                call    dword ptr cs:xms_control
                or      ax, ax
                pop     dx
                jnz     @@4
                cmp     bl, 0abh
                jnz     @@4
                push    dx
                mov     ah, 0dh                 ; unlock
                call    dword ptr cs:xms_control
                or      ax, ax
                pop     dx
                jmp     @@2
        @@4:    loop    @@1
        @@5:    ret
                endp

; -----------------------------------------------------------------------
CloseSpeaker:
                in      al, 61h
                and     al, 0fch
                out     61h, al
                ret

; -----------------------------------------------------------------------
RestoreClockSpeed:
                mov     al, 00110110b
                out     43h, al
                xor     ax, ax
                out     40h, al
                out     40h, al
                ret

; -----------------------------------------------------------------------
ResetDisk:
                xor     ax, ax
                xor     dx, dx
                int     13h             ; Restore A
                inc     dx
                int     13h             ; Restore B
                mov     dl, 80h
                int     13h             ; Restore C
                ret



; --------------------------------------------------------------------------
ClosePRN:
                mov     ah, 51h         ; Get PSP seg
                int     21h
                mov     es, bx
                mov     ax, es:[16h]    ; Prev PSP seg
                cmp     ax, bx
                jnz     @@9
                mov     ax, 3e00h       ; COMMAND
                mov     bx, 4
                int     21h
        @@9:
                ret

InitPRN:
                mov     ax, 3e00h
                mov     bx, 4           ; PRN
                int     21h
                mov     ax, 3d01h
                mov     dx, offset PRNname
                push    cs
                pop     ds
                int     21h
                ret
PRNname         db      'PRN',0

InitMouse:                              ; 2/16/1993 by Mr. Lei
                push    es
                xor     ax, ax
                mov     es, ax
                cmp     word ptr es:[33h*4+2], 0
                jz      @@0
                cmp     word ptr es:[33h*4], 0
                jz      @@0
                mov     ax, 21h
                int     33h             ; Hook Mouse Interrupt
        @@0:    pop     es
                ret

; ------------- CMOS CLOCK set to System -----------------------------------
UpdateTime:
                call    GetRealTime
                mov     ah, 2dh
                int     21h
                ret

GetRealTime:
                mov     ah,2
                int     1Ah
                mov     al,ch
                call    bcdxchg
                mov     ch,al
                mov     al,cl
                call    bcdxchg
                mov     cl,al
                mov     al,dh
                call    bcdxchg
                mov     dh,al
                mov     dl,0
                ret

BCDxchg:
                push    ax
                push    cx
                mov     cl,4
                shr     al,cl
                pop     cx
                mov     bl,0Ah
                mul     bl
                pop     bx
                and     bl,0Fh
                add     al,bl
                ret

; -----------------------------------------------------------------------
; Display string
ColorPrintStr:
                lodsb
                mov     bh, al          ; color
                xor     cx, cx
                mov     dx, 014fh
                mov     ax, 0600h
                int     10h

                mov     ah, 02          ; GotoXY (0, 0)
                xor     dx, dx
                mov     bh, 0
                int     10h
PrintStr:
                push    cs
                pop     ds
                xor     bx, bx
        @@1:    lodsb
                cmp     al, '$'
                jz      @@2
                or      al, al
                jz      @@2
                mov     ah, 0eh
                int     10h
                jmp     short @@1
        @@2:    mov     al, cs:clsStrcolor
                mov     cs:clsStr, al
                ret

; -----------------------------------------------------------------------
  Self          dw      0
  clsStrcolor   db      17h
  clsStr        db      17h             ; Color (White in Blue)
    db ' RAMinit  Version 2.12  (c) 1989-1994 by KingSoft Ltd.  Mr. Leijun'
    db 0dh,0ah
    db ' ['
  ShowCopies    db      '*'
    db '] Activate...',0ah,0dh,'$'

endTSR  equ     $
mcbList equ     offset endTSR + 2 + 2
vecList equ     mcbList + 7*10 + 2 + 10h + 1 + 400h
devLink equ     vecList + 4 + 5 * 26 + 4 + 10 * 30h + 4
xmsList equ     devLink + 2 + MaxHandles * 2
emsList equ     xmsList + 4 + 1024
crtMode equ     emsList + 2 + 1Dh + 4 + 10h
tsrLen  equ     crtMode + 1
;
; DOS Environment Reserved by RI
; --------------------------------------------------
;   Flag                        'XX'       2 bytes
;   Environment Segment                    1 word
;   Free MCBs                         <=7*10 bytes
;     MCB segment               1 word
;     MCB                       5 bytes
;   End flag                    'MM'       1 word
;   COM LPT ports                        10h bytes
;   LEDs status                            1 bytes
;   Packed vectors list               <=400h bytes
;   Flag                        'CV'       2 bytes
;   CVT First DPB pointer                  4 bytes
;       DPBs data                     <=5*26 bytes
;       First DCB pointer                  4 bytes
;       Pointer to NUL                     4 bytes
;       All device driver datas     <=30h*10 bytes
;   Flag                        'XM'       2 bytes
;   XMS free handle counter                2 bytes
;   EMS free handle list            <=100h*4 bytes
;   Flag                        'EM'       2 bytes
;   EMS free handle counter                2 bytes
;   EMS free handle list              <=1024 bytes
;       EMS handle              1 word
;       Number of pages         1 word
;   Flag                        '--'       1 word
;   Equipment List                         1 word
;   CRT 40:49h-66h                       1dh bytes
;       40:A8h                             1 dword
;   BIOS User Data Area  40:F0--FF       10h bytes
; ***************************************************************************
;
main:           jmp     main0

Print           Macro   Str
                Lea     dx, Str
                call    DisplayStr
                endm

InstMsg db  'RAMinit  Version 2.12 '
        db  'Copyright (c) 1989-1994  by KingSoft Ltd. ',0dh,0ah,'$'
Msg0    db  'Already installed !',0dh,0ah,0ah
        db  'For Help, type "RI /?". ',0dh,0ah,'$'
Msg_0   db  0ah,'Residents a new RAMinit copy [y/n] ? $'
Msg_2   db  'OK, RI No.'
Msg_RI  db  '2'
        db  ' residents successful !', 0dh,0ah,'$'
Msg1    db  'Activate with:  $'
KeyMsg  db  'Right_Shift$'
        db  'Left_Shift$ '
  KMsg1 db  'Left_Ctrl$  '
        db  'Left_Alt$   '
        db  'Right_Ctrl$ '
        db  'Right_Alt$  '
  KMsg2 db  'Ctrl$       '
        db  'Alt$        '
        db  'Ctrl$       '
        db  'Alt$        '
PlusMsg db  ' + $'
crlf    db  0dh,0ah,'$'

HelpMsg db  'Programmed by Mr. Leijun    Dec 1992', 0dh,0ah,0ah
        db  'Usage:   RI [options]',0dh,0ah,0ah
        db  '/H,/?    Display this screen',0dh,0ah
        db  '/CLS     Removes all TSR programs after current RI',0dh,0ah
        db  '/RET     Removes TSR programs include current RI',0dh,0ah
        db  '/NEW     Residents a new data copy of current environment',0dh,0ah
        db  '/ALL     Removes all RI copies and all other tsr programs',0dh,0ah
        db  '/Sxyy..  Define Hotkey   x=AuxHotkey   yy..=shift status',0dh,0ah
        db  '         x=auxiliary hotkey (default is "X") ',0dh,0ah
        db  '           x equ "1" means need AuxHotkey',0dh,0ah
        db  '         yy..=shift status  [CAScas]',0dh,0ah
        db  '           C: Left Ctrl    A: Left Alt    S: Left Shift',0dh,0ah
        db  '           c: Right Ctrl   a: Right Alt   s: Right Shift',0dh,0ah,0ah
        db  'Example: "RI /S1c"  means Hotkey is Right_Ctrl+X',0dh,0ah
        db  '         "RI /S0Cc" means HotKey is Left_Ctrl+Right_Ctrl',0dh,0ah
        db  '         "RI /CLS"  equals simply press hotkey',0dh,0ah
        db  '         "RI /RET"  Removes all TSRs after current RI and this RI',0dh,0ah
        db  0ah
        db  'Contact me for RAMinit problems: (01)2561155 Call 1997',0dh,0ah
        db  '$'
ErrMsg  db  'ERROR: Invalid options !',0dh,0ah,0ah,'$'
WinErr  db  7, 'Sorry, I cannot work in Windows DOS environment.',0dh,0ah,'$'
SetMsg  db  7, 'Defines new Hotkey successful !',0dh,0ah,0ah,'$'
tsrOK   db  False

Main0:
                cld
                Print   instMsg
                call    IsWinDos
                or      ax, ax
                jz      @@1
                Print   WinErr
                mov     ax, 4c00h
                int     21h
        @@1:
                call    HotKeyValid
                mov     cs:Status, 0
                call    EMS_test
                call    CmpDosVer
                call    CmpSideKick
                call    GetMachineID
                call    ModifyHotKeyPrompt

                mov     ax, 0c0d7h
                int     2fh
                mov     es, ax
                cmp     word ptr es:[101h], 'IE'        ; 'LEI'
                jnz     @@0
                mov     cs:Self, ax
        @@0:
                call    CmdLine
                call    PrintHotKeyPrompt

                cmp     cs:tsrOK, true
                jz      @@2
                call    tsrReplyOK
        @@2:    cmp     cs:tsrOK, true
                jnz     @@_2
                call    PrintCopies
        @@_2:
                mov     word ptr cs:[100h], 'EL'
                mov     byte ptr cs:[102h], 'I'

                push    cs
                pop     es
                push    cs
                pop     ds
                std
                mov     si, offset eof
                mov     cx, eof - offset Here
                mov     di, tsrLen
                add     di, cx
                inc     cx
                rep     movsb
                cld
                mov     bx, tsrLen
                jmp     bx

Here:
                mov     ax,cs
                mov     es,ax
                mov     di,offset endTSR
                mov     cs:DataBegin, di
                mov     cs:NextDataSeg, -1
                mov     ax, 'XX'
                stosw
                in      al, 0a1h
                mov     ah, al
                in      al, 21h
                push    ax
                mov     word ptr cs:old_8259, ax
                xor     ax, ax
                out     21h,al                  ; CLI
                call    SaveOthers
                call    SetSelfInt
                call    BackupVecList
                cmp     cs:Power, true
                jnz     @@20
                call    BackupCVTchain
                call    BackupMemoryManager
        @@20:
                call    BackupBiosData

                sti
                mov     cs:Flag, ' '    ; no busy
                mov     cs:StopFlag, 0  ;

                mov     cs:tsrLength, di
                call    SetDosEnvSeg
                cmp     cs:Self, 0
                jz      @@29
                push    cs
                pop     ds
                push    cs
                pop     es
                cld
                mov     cx, cs:tsrLength
                mov     si, cs:DataBegin
                sub     cx, si
                mov     di, 120h
                mov     cs:DataBegin, di
                rep     movsb
                mov     cs:tsrLength, di
        @@29:
                pop     ax
                out     21h, al                         ; STI
                mov     al, ah
                out     0a1h, al
                mov     dx, cs:tsrLength
                inc     dx
                int     27h

; ----------------------------------------------------------------------------
SetDosEnvSeg:
                push    ds
                push    es
                mov     ax, cs
        @@10:   mov     es, ax
                mov     ax, es:[16h]    ; Get father process psp segment
                or      ax, ax
                jz      @@11
                mov     bx, es
                cmp     ax, bx
                jnz     @@10
        @@11:
                mov     es, word ptr es:[2ch] ; Get father process env segment
                mov     cs:DosEnv, es
                pop     es
                pop     ds
                ret

; ----------------------------------------------------------------------------

SaveOthers:
                mov     ax, cs:[2ch]            ; Env Seg
                stosw
                call    backupMCB               ; Current MCB
                mov     ax, 40h                 ; COM LPT Port
                mov     ds, ax
                mov     si, 0h
                mov     cx, 8
                rep     movsw

                mov     si, 17h                 ; LED status
                lodsb
                stosb
        ;       call    OpenLEDs
                ret

; --------------------------------------------------------------------------
backupMCB:
                mov     ax, 'ZM'
                stosw
                push    ds
                push    es
                mov     ah, 52h
                int     21h                     ; Get MCB chain head
                mov     ax, es:[bx-2]
                pop     es
        @@0:    mov     ds, ax
                cmp     byte ptr ds:[0], 'Z'    ; End ?
                jz      @@20
                cmp     byte ptr ds:[0], 'M'    ; Memory control block
                jnz     @@30
                cmp     word ptr ds:[3], 0      ; Nul mcb
                jz      @@10
                cmp     word ptr ds:[1], 0      ; Free MCB
                jnz     @@10
                call    SaveFreeMCB
        @@10:   inc     ax
                add     ax, ds:[3]
                jmp     @@0
        @@20:
                call    SaveFreeMCB
                cmp     ax, 0a000h
                inc     ax
                jnb     @@30
                mov     ax, 9fffh               ; MS-DOS UMB
                jmp     @@0

        @@30:
                cmp     ax, 0c000h              ; 386MAX
                ja      @@90
                mov     ax, 0c020h
                jmp     @@0

        @@90:                                   ; Error ?
                pop     ds
                mov     ax, 'MM'                ; Set MCB flag
                stosw
                ret

SaveFreeMCB:
                stosw
                xor     si,si
                movsb
                movsw
                movsw
                ret
;
;               push    ax
;               stosw
;               xor     si,si
;               movsb
;               movsw
;               movsw
;               pop     ax
;               cmp     ax, 09fffh
;               jnb     @@3
;               push    ax
;               push    ds
;               mov     ds,ax
;               cmp     byte ptr ds:[0], 'M'
;               pop     ds
;               pop     ax
;               jnz     @@4
;               mov     ax, 09fffh              ; MS-DOS UMB
;               jmp     @@0
;       @@4:    cmp     ax, 0c000h
;               ja      @@3
;               mov     ax, 0c020h              ; 386MAX
;               jmp     @@0
;
; --------------------------------------------------------------------------

OpenLEDs:       push    ax                      ; Open all LEDs
                or      al, 070h
                mov     ds:[17h], al
                mov     ah, 1
                int     16h
                mov     cx, 4                   ; Delay
        @@20:   push    cx
                xor     cx, cx
        @@21:   loop    @@21
                pop     cx
                loop    @@20
                pop     ax
                mov     ds:[17h], al
                mov     ah, 1
                int     16h
                ret

; --------------------------------------------------------------------------
SetSelfInt:
                push    es
                push    di

        cmp     cs:self, 0
        jnz     @@1
                push    cs
                pop     ds
                mov     ax,3509h
                int     21h
                mov     word ptr cs:oldInt9_addr,bx
                mov     word ptr cs:oldInt9_addr[2],es
                mov     dx,offset NewInt9
                mov     ax,2509h
                int     21h

                mov     ax,352Fh
                int     21h
                mov     word ptr cs:oldInt2F_addr,bx
                mov     word ptr cs:oldInt2F_addr[2],es
                mov     dx,offset newInt2F
                mov     ax,252Fh
                int     21h

                mov     ax,351Ch
                int     21h
                mov     word ptr cs:oldInt1C_addr,bx
                mov     word ptr cs:oldInt1C_addr[2],es
                mov     dx,offset newInt1C
                mov     ax,251ch
                int     21h
                cli
                jmp     @@2
        @@1:
                mov     es, cs:Self
                inc     es:Copies
        @@_0:   cmp     es:NextDataSeg, -1
                jz      @@_1
                mov     es, es:NextDataSeg
                jmp     @@_0
        @@_1:   mov     es:NextDataSeg, cs
        @@2:
                pop     di
                pop     es
                ret

; -----------------------------------------------------------------------
SaveCounter:
                mov     word ptr es:[di], 'EL'
                mov     byte ptr es:[di+2], 'I'
                mov     byte ptr es:[di+3], bl
                xor     bx, bx
                add     di, 4
                ret

; -----------------------------------------------------------------------
DisplayStr:     push    cs
                pop     ds
                mov     ah, 9
                int     21h
                ret

; -----------------------------------------------------------------------
CmdLine:
                push    cs
                pop     ds
                xor     ax, ax
                mov     si, 80h
                lodsb
                or      al, al
                jnz     @@1
                ret
        @@1:
                mov     cx, ax
                dec     ax
                push    ax
                push    si
        @@0:    lodsb
                cmp     al, ' '
                jz      @@0
                cmp     al, '/'
                jnz     @@2
                lodsb
                cmp     al, 'S'
                jz      @@_2
                cmp     al, 's'
                jnz     @@2
        @@_2:
                call    SetHotKey
                Print   SetMsg
                mov     ax, 4c00h
                int     21h
        @@2:
                pop     si
                pop     ax
                push    ax
                push    si
        @@_3:   lodsb
                cmp     al, 'A'
                jb      @@3
                cmp     al, 'Z'
                ja      @@3
                add     byte ptr ds:[si-1],20h  ; DownCase
        @@3:    loop    @@_3
                pop     si
                pop     cx

                add     si, cx
                lodsb
                cmp     al, 's'         ; CLS
                jnz     @@5
                cmp     word ptr ds:[si-3], 'lc'
                jnz     @@5
                cmp     cs:Self, 0
                jz      @Err
                mov     ax, 0c0d7h+1
                int     2fh

        @@5:    cmp     al, 'h'         ; HELP
                jz      @help
                cmp     al, '?'
                jz      @help
                cmp     al, 't'         ; RET
                jnz     @@6
                cmp     word ptr ds:[si-3], 'er'
                jnz     @@6
        @@7:
                cmp     cs:Self, 0
                jz      @Err
                mov     ax, 0c0d7h+2
                int     2fh
        @@6:    cmp     al, 'w'         ; NEW
                jnz     @@8
                cmp     word ptr ds:[si-3], 'en'
                jnz     @@8
                mov     cs:tsrOK, true
                ret
        @@8:
                cmp     al, 'l'         ; ALL
                jnz     @@9
                cmp     word ptr ds:[si-3], 'la'
                jnz     @@9
                mov     ax, 0c0d7h+3
                int     2fh
        @@9:
                cmp     al, ' '
                jnz     @Err
                ret

        @Err:
                Print   ErrMsg
        @help:
                Print   HelpMsg
                mov     ax, 4c00h
                int     21h

;---------------------------------------------------------------------------
tsrReplyOK:
                cmp     cs:Self, 0
                jz      @@1
                Print   Msg0

                push    es
                mov     ax, cs:Self
        @@_10:  mov     es, ax
                mov     ax, es:NextDataSeg
                cmp     ax, -1
                jnz     @@_10
                mov     ax, es

        @@_0:   push    ax
                dec     ax
                mov     es, ax
                mov     bx, es:[3]
                pop     ax

                add     ax, bx
                inc     ax
                mov     es, ax
                cmp     word ptr es:[0], 'OC'
                jz      @@_0

                mov     bx, cs
                cmp     ax, bx
                pop     es
                jz      @@2
                Print   Msg_0
                mov     ah, 1
                int     21h

                push    ax
                Print   crlf
                pop     ax

                cmp     al, 'y'
                jz      @@3
                cmp     al, 'Y'
                jz      @@3
        @@2:    ; Print Msg_1
                mov     ax, 4c01h
                int     21h
        @@3:
        @@1:    mov     cs:tsrOK, true
                ret

PrintCopies:
                cmp     cs:Self, 0
                jz      @@1
                push    es                      ; Added -by- Mr. Lei
                mov     es, cs:Self             ; Aug 24, 1993
                mov     al, es:Copies
                inc     al                      ; Total RI copies
                push    ax                      ; Set es = current mcb
                mov     ax, cs
                dec     ax
                mov     es, ax
                pop     ax
                mov     cx, 5                   ; Search end of file name
                mov     bx, 8
        @@10:   inc     bx
                cmp     byte ptr es:[bx], 20h
                jz      @@20
                cmp     byte ptr es:[bx], 0ffh
                jz      @@20
                cmp     byte ptr es:[bx], 00h
                jz      @@20
                loop    @@10
        @@20:                                   ; Set current RI no
                mov     byte ptr es:[bx], ':'   ; "RI:2"
                mov     byte ptr es:[bx+1], al
                cmp     bx, 8+7
                jnb     @@30
                mov     byte ptr es:[bx+2], 0
        @@30:
                pop     es

                mov     cs:Msg_RI, al
                Print   Msg_2
        @@1:    ret

;---------------------------------------------------------------------------
; Backup Interrupt Vector List
;
BackupVecList:
                push    ds
                push    cs
                pop     es
                xor     si,si                   ; Vectors
                mov     ds,si
                movsw
                movsw
                xor     bx, bx
                mov     cx,00ffh
        @@0:    lodsw
                xchg    dx, ax
                lodsw
                cmp     ax, es:[di-2]
                jnz     @@1
                cmp     dx, es:[di-4]
                jz      @@2
        @@1:    or      bx, bx
                jz      @@3
                call    SaveCounter
        @@3:    xchg    dx, ax
                stosw
                xchg    dx, ax
                stosw
                loop    @@0
                jmp     @@4
        @@2:    inc     bx
                loop    @@0
                call    SaveCounter
        @@4:
                pop     ds
                ret
;
;-----------------------------------------------------------------------------
BackupCVTchain:
                mov     ax, 'VC'
                stosw
                push    ax
                push    bx
                push    cx
                push    ds
                push    es
                mov     ah, 52h
                int     21h             ; ES:BX -- DOS table as described below

        ; --------------------------------------------------------------------
                push    es              ; DPB chains
                push    bx
                lds     si, es:[bx]
                push    cs
                pop     es
                mov     ax, si
                stosw
                mov     ax, ds
                stosw
                mov     bx, cs:cvtOfs
                xor     cx, cx
        @@1:    mov     al, ds:[si+1]
                stosb
                mov     ax, ds:[si+bx+12h]
                stosw
                mov     ax, ds:[si+bx+14h]
                stosw
                inc     cx
                lds     si, ds:[si+bx+18h]
                cmp     si, -1
                jnz     @@1
        ;       mov     ax, 5
        ;       mul     cl
        ;       add     ax, 4
        ;       add     cs:tsrLength, ax
                pop     bx
                pop     es

        ; --------------------------------------------------------------------
                push    es              ; DCB   file control blocks
                push    bx
                les     bx, es:[bx+4]
        @@11:   cmp     word ptr es:[bx], -1
                jz      @@10
                les     bx, es:[bx]
                jmp     @@11
        @@10:
                mov     ax, es
                xchg    ax, bx
                push    cs
                pop     es
                stosw
                xchg    ax, bx
                stosw
                pop     bx
                pop     es
        ;       add     cs:tsrLength, 4

        ; ---------------------------------------------------------------------
                push    es              ; Device Driver Chains
                pop     ds
                add     bx, 22h
                mov     si, bx          ; NUL

                pop     es
                mov     ax, si
                stosw
                mov     ax, ds
                stosw
                xor     cx, cx
                xor     bx, bx
        @@9:    push    si
                mov     cl, 5
                rep     movsw
                inc     bx
                pop     si
                lds     si, ds:[si]
                mov     ax, si
                inc     ax
                jnz     @@9

                pop     ds
                pop     cx
                pop     bx
                pop     ax
                ret

; ----------------------------------------------------------------------------

BackupBiosData:
                mov     ax, '--'
                stosw
                push    ds
                push    si
                mov     si, 40h
                mov     ds, si
                mov     si, 10h
                movsw
                mov     si, 0a8h
                movsw
                movsw
                mov     si, 49h
                mov     cx, 1dh
                rep     movsb

                mov     si, 0f0h
                mov     cx, 8
                rep     movsw
                pop     si
                pop     ds
                ret

; ---------------------------------------------------------------------------

BackupMemoryManager:
                push    cs
                pop     es
                push    ds
                push    es
                call    SaveXMSstatus
                call    SaveEMSstatus
                pop     es
                pop     ds
                ret

        ;---------------------------------------------------------------------

SaveEMSstatus:
                test    cs:status, EMSbit
                jnz     @@1
                ret
        @@1:
                mov     ax, 'ME'
                stosw
                inc     di
                inc     di
                push    di
                mov     ah, 4dh
                int     67h
                pop     di
                mov     es:[di-2], bx
                shl     bx, 1
                shl     bx, 1
                add     di, bx
                ret
        ; -------------------------------------------------------------------

SaveXMSstatus:
                call    XMS_test
                test    cs:status, XMSbit
                jnz     @@1
                ret
        @@1:
                mov     ax, 'MX'
                stosw

                mov     dx, 1
                call    XMS_alloc
                jnz     @@_1
                xor     cx, cx                  ; XMS alloc failure
                stosw
                ret
        @@_1:
                push    dx
                sub     dx, MaxHandles * 10
        @@2:
                push    dx
                call    XMS_Lock
                pop     dx
                jnz     @@3
                cmp     bl, 0a2h
                jnz     @@4
                add     dx, 10
                jmp     @@2
        @@3:    push    dx
                call    XMS_unlock
                pop     dx
        @@4:
                mov     cs:handle_begin, dx
                pop     dx
                push    dx
                call    XMS_bstat
                xor     cx, cx
                mov     cl, bl
                inc     cx
                pop     dx
                call    XMS_Free
                mov     dx, cs:Handle_begin

                push    cx
                push    cs
                pop     es
                mov     ax, cx
                stosw
        @@5:    push    dx
                call    XMS_Lock
                pop     dx
                jnz     @@6
                cmp     bl, 0a2h                ; Handle invalid
                jz      @@7
        @@6:    call    XMS_unlock
                add     dx, 10
                jmp     @@5
        @@7:    mov     ax, dx
                stosw
                add     dx, 10
                loop    @@5
                pop     cx
                ret
        ; ------------------------------------------------------------------

XMS_test:
                push    es
                mov     ax, 4300h
                int     2fh
                cmp     al, 80h
                jnz     @@9
                mov     ax, 4310h
                int     2fh
                mov     cs:XMS_control, bx
                mov     cs:XMS_control[2], es
                or      cs:Status, XMSbit
        @@9:
                pop     es
                ret

XMS_stat:
                mov     ah, 0
                call    dword ptr cs:xms_control
                mov     hma_exist, dl
                ret
hma_exist       db      0

XMS_alloc:
                mov     ah, 9
                call    dword ptr cs:xms_control
                or      ax, ax
                ret

XMS_lock:
                mov     ah, 0ch
                call    dword ptr cs:xms_control
                or      ax, ax
                ret

XMS_unlock:
                mov     ah, 0dh
                call    dword ptr cs:xms_control
                or      ax, ax
                ret
XMS_bstat:
                mov     ah, 0eh
                call    dword ptr cs:xms_control
                or      ax, ax
                ret

XMS_free:
                mov     ah, 0ah
                call    dword ptr cs:xms_control
                or      ax, ax
                ret

; ----------------------------------------------------------------------------
EMS_test:
                push    cs
                pop     ds
                mov     dx, offset EMMname
                mov     ax, 3d00h
                int     21h
                jc      @@2
                mov     bx, ax
                mov     ah, 3eh
                int     21h
                or      cs:Status, EMSbit
        @@2:
                ret
EMMname         db      'EMMXXXX0',0

; -----------------------------------------------------------------------------

SetHotKey:
                xor     bx, bx
                lodsb
                push    ax

        @@1:    lodsb
                cmp     al, 0dh
                jz      @@9
                cmp     al, 'C'
                jnz     @@2
                or      bl, LeftCtrl
                jmp     @@1
        @@2:
                cmp     al, 'c'
                jnz     @@3
                or      bl, RightCtrl
                jmp     @@1
        @@3:
                cmp     al, 'A'
                jnz     @@4
                or      bl, LeftAlt
                jmp     @@1
        @@4:
                cmp     al, 'a'
                jnz     @@5
                or      bl, RightAlt
                jmp     @@1
        @@5:
                cmp     al, 'S'
                jnz     @@6
                or      bl, LeftShift
                jmp     @@1
        @@6:
                cmp     al, 's'
                jnz     @@7
                or      bl, RightShift
                jmp     @@1
        @@7:    pop     ax
                jmp     @Err
        @@9:
                mov     cs:HotKey, bl
                pop     ax
                mov     cs:AuxHotKey, 2dh       ; 'X' scan key
                cmp     al, '1'
                jz      @@29
                mov     cs:AuxHotKey, 0
        @@29:
                cmp     cs:Self, 0
                jz      @@30
                push    es
                mov     es, cs:Self
                mov     es:HotKey, bl
                mov     bl, cs:AuxHotKey
                mov     es:AuxHotKey, bl
                pop     es
        @@30:
                call    GetRunFileName
                mov     ax, 3d02h
                int     21h
                jc      @@10
                push    cs
                pop     ds
                mov     bx, ax
                mov     cx, 4
                mov     dx, 100h
                mov     ah, 40h
                int     21h
                jc      @@10
                mov     ax, 4200h
                xor     cx, cx
                mov     dx, 17h
                int     21h
                jc      @@10
                mov     cx, 1
                mov     dx, offset AuxHotKey
                mov     ah, 40h
                int     21h
                jc      @@10
                mov     ah, 3eh
                int     21h
        @@10:
                ret


; -----------------------------------------------------------------------
GetRunFileName:
; Return:
;      DS:DX    Pointer of this run file name ASCIIZ string
                push    ax
                push    bx
                push    cx
                push    si
                push    di
                push    es

                push    cs
                pop     es
                mov     ax, es:[2ch]
                mov     es, ax
                xor     di, di
                mov     cx, 1000h
                xor     al, al
@@1:            repnz   scasb
                cmp     es:[di], al
                loopnz  @@1
                mov     dx, di
                add     dx, 3
                push    es
                pop     ds

                pop     es
                pop     di
                pop     si
                pop     cx
                pop     bx
                pop     ax
                ret

; ---------------------------------------------------------------------------
GetMachineID:
                push    es
                mov     KBD102,True
                mov     ax,40h
                mov     es,ax
                test    byte ptr es:[96h], 00010000b
                jnz     @@1
                mov     Kbd102,False
        @@1:
                xor     ax,ax
                dec     ax
                mov     es,ax
                mov     al,es:[0eh]
                mov     cs:MachineID, al
                pop     es
                ret

; ---------------------------------------------------------------------------
ModifyHotKeyPrompt:
                cmp     cs:Kbd102, True
                jz      @@9
                push    cs
                pop     es
                push    cs
                pop     ds
                mov     cx, 12*4
                mov     si, offset KMsg2
                mov     di, offset KMsg1
                rep     movsb
        @@9:    cmp     cs:MachineID, 0fch
                jna     @@10
                mov     cs:clsStrcolor, 70h     ; Mono
                mov     cs:clsStr, 70h
        @@10:
                ret

; ---------------------------------------------------------------------------
PrintHotKeyPrompt:
                Print   Msg1
                mov     al, cs:HotKey
                mov     ah, al
                shr     al, 1
                shr     al, 1
                and     ax, 33ch
                or      al, ah
                mov     dx, offset KeyMsg
        @@40:
                or      ax, ax                          ; Mr. Lei 4/25/1993
                jz      @@_42
                shr     al, 1
                push    ax
                jnc     @@41

                push    ax
                call    ColorDisplayStr
        ;       mov     ah, 9
        ;       int     21h
                pop     ax

                or      al, al
                jz      @@42

                push    dx
                mov     dx, offset PlusMsg
                call    ColorDisplayStr
        ;       Print   PlusMsg
                pop     dx

        @@41:   add     dx, 12
                pop     ax
                jmp     @@40
        @@42:   pop     ax
        @@_42:  cmp     cs:AuxHotKey, 0
                jz      @@43
                cmp     cs:HotKey, 0                    ; Mr. Lei
                jz      @@_43
                mov     dx, offset PlusMsg
                call    ColorDisplayStr
        ;       Print   PlusMsg
        @@_43:  mov     dx, offset AuxHotKeyName
                call    ColorDisplayStr
        ;       Print   AuxHotKeyName
        @@43:
                Print   crlf
                ret

ColorDisplayStr:
                push    bx
                push    cx
                push    dx
                push    si
                mov     bl, 0fh
                mov     si, dx
                xor     bh, bh
                mov     cx, 1
        @@1:    lodsb
                cmp     al, '$'
                jz      @@2
                or      al, al
                jz      @@2
                push    cx
                mov     ah, 09h
                int     10h
                mov     ah, 3
                int     10h
                inc     dl
                mov     ah, 2
                int     10h
                pop     cx
                jmp     short @@1
        @@2:
                pop     si
                pop     dx
                pop     cx
                pop     bx
                ret

; ---------------------------------------------------------------------------
CmpSideKick:
                xor     ax, ax
                mov     es, ax
                les     bx, es:[20h]
                cmp     word ptr es:[bx-4], 4b53h
                jnz     @@1
                cmp     word ptr es:[bx-2], 4942h
                jz      @@2
        @@1:    mov     es, ax
                les     bx, es:[94h]
                cmp     word ptr es:[bx-2], 4b53h
                jz      @@2
                ret
        @@2:    or      cs:Status, SKbit
                ret

; ---------------------------------------------------------------------------
CmpDosVer:      mov     ah, 30h
                int     21h
                cmp     al, 3
                jb      @@1
                cmp     al, 3
                jna     @@2
                mov     cs:cvtOfs, 1
                ret
        @@2:    mov     cs:cvtOfs, 0
                ret
        @@1:    Print   DosVerErr
                mov     ax, 4cffh
                int     21h

  DosVerErr db  'Sorry, DOS version too lower !',0dh,0ah,'$'

HotKeyValid:
                cmp     cs:HotKey, 0
                jnz     @@_1
                cmp     cs:AuxHotKey, 0
                jnz     @@_1
                Print   HotKeyErr
                mov     ax, 4cfeh
                int     21h
        @@_1:   ret

  HotKeyErr db  'Sorry, please setup hotkey again. ',0dh,0ah,'$'

eof:
                ends
                end     Start

; ------------- The End ! ---------------------------------------------------
