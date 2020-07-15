;==========================================
;_____.___.             .__      .____     
;\__  |   |____    ____ |__|__  _|    |    
; /   |   \__  \  /    \|  \  \/ /    |    
; \____   |/ __ \|   |  \  |\   /|    |___ 
; / ______(____  /___|  /__| \_/ |_______ \
; \/           \/     \/                 \/
;==========================================
IDEAL
MODEL small
STACK 100h
;================================
DATASEG
;================================
	BmpLeftPlayer dw ? ;To save the x of the Player
    BmpTopPlayer dw ? ;To save the y of the Player (you dont really need to)
	
	BmpLeftRocket dw ? ;To save the x of the Rocket needs to be random 
    BmpTopRocket dw ? ;To save the y of the Rocket need to sub in 1 every frame 

	BmpLeft dw ? 
	BmpTop dw ? 
	BmpColSize dw ? ;The Y of the Player
	BmpRowSize dw ? ;The X of the Player
	
	Black db "Black.bmp", 0 ;To delete the player
	Brock db "BRock.bmp",0 ;To delete the rocket
	Rocket db "Rocket.bmp", 0 ;The rocket 
	Player db "Player.bmp", 0 ;The player
	FileName db 'wall.bmp',0 ;The background 
	EndScreen db 'End.bmp',0 ;The end screen
	StartScreen db 'Start.bmp',0 ;The start screen
	Rules db 'Rules.bmp',0 ;The rules screen
	FileHandle dw ? 
	Header db 54 dup (0)
	Palette db 256*4 dup (0)
	ScrLine db 320 dup (0)
	ErrorMsg db 'Error', 13, 10,'$'
	RndSeed dw ?
	divisorTable db 10, 1, 0 ;For the number printing
	
	counter db 0 
	StartSec db ? ;Later for printing the seconds
	StartMin db ? ;Later for printing the Minutes
	
	
	
	
	OneBmpLine 	db 200 dup (0)  ; One Color line read buffer
    ScreenLineMax db 320 dup (0)  ; One Color line read buffer
	A_Key equ 1Eh ;A key in Ascii
	D_Key equ 20h ;D key in Ascii
	EKey equ 12h ;E key in Ascii
	Clock equ es:6Ch
	Q_Key equ 113 ;Q key in Ascii
	S_key equ 115 ;S key in Ascii
	
	Screen_Y equ 200 ;The size of the screen in Y
	Screen_X equ 320 ;The size of the screen in X
	Rocket_Y equ 28 ;The size of the Rocket in Y
	Rocket_X equ 16 ;The size of the Rocket in X
	Rocket_Speed equ 10 ;The speed of the rocket
	Player_Y equ 32 ;The size of the Player in Y
	Player_X equ 32 ;The size of the Player in X
;================================
CODESEG
;================================



;=======================================================
; input :
;	1.BmpLeft offset from left (where to start draw the picture) 
;	2. BmpTop offset from top
;	3. BmpColSize picture width , 
;	4. BmpRowSize bmp height 
;	5. dx offset to file name with zero at the end
;=======================================================
proc OpenShowBmp
	push cx	;|ip||BmpLeftPlayer|BmpTopPlayer|
	push bx
	call OpenBmpFile
	cmp ax, 0
	je @@ExitProc
	
	call ReadBmpHeader
	; from  here assume bx is global param with file handle. 
	call ReadBmpPalette
	
	call CopyBmpPalette
	
	call ShowBMP
	
	call CloseBmpFile

@@ExitProc:
	pop bx
	pop cx
	ret
endp OpenShowBmp	
; input dx FileName to open
proc OpenBmpFile	near						 
	mov ah, 3Dh
	xor al, al
	int 21h
	jc @@ErrorAtOpen
	mov [FileHandle], ax
	jmp @@ExitProc
	
@@ErrorAtOpen:
	mov ax, 0
@@ExitProc:	
	ret
endp OpenBmpFile

proc CloseBmpFile near
	mov ah,3Eh
	mov bx, [FileHandle]
	int 21h
	ret
endp CloseBmpFile

; Read 54 bytes the Header
proc ReadBmpHeader					
	push cx
	push dx
	
	mov ah,3fh
	mov bx, [FileHandle]
	mov cx,54
	mov dx,offset Header
	int 21h
	
	pop dx
	pop cx
	ret
endp ReadBmpHeader

proc ReadBmpPalette ; Read BMP file color palette, 256 colors * 4 bytes (400h)
	; 4 bytes for each color BGR + null
	push cx
	push dx
	
	mov ah,3fh
	mov cx,400h
	mov dx,offset Palette
	int 21h
	
	pop dx
	pop cx
	
	ret
endp ReadBmpPalette

;=======================================================
; Will move out to screen memory the colors
; video ports are 3C8h for number of first color
; and 3C9h for all rest
;=======================================================
proc CopyBmpPalette					
										
	push cx
	push dx
	
	mov si,offset Palette
	mov cx,256
	mov dx,3C8h
	mov al,0  ; Black first							
	out dx,al ;3C8h
	inc dx	  ;3C9h
CopyNextColor:
	mov al,[si+2] 		; Red				
	shr al,2 			; divide by 4 Max (cos max is 63 and we have here max 255 ) (loosing color resolution).				
	out dx,al 						
	mov al,[si+1] 		; Green.				
	shr al,2            
	out dx,al 							
	mov al,[si] 		; Blue.				
	shr al,2            
	out dx,al 							
	add si,4 			; Point to next color.  (4 bytes for each color BGR + null)				
								
	loop CopyNextColor
	
	pop dx
	pop cx
	
	ret
endp CopyBmpPalette

proc ShowBMP 
;=======================================================
; BMP graphics are saved upside-down.
; Read the graphic line by line (BmpRowSize lines in VGA format),
; displaying the lines from bottom to top.
;=======================================================
	push cx
	
	mov ax, 0A000h
	mov es, ax
	
	mov cx,[BmpRowSize]
	
	mov ax,[BmpColSize] ; row size must dived by 4 so if it less we must calculate the extra padding bytes
	xor dx,dx
	mov si,4
	div si
	mov bp,dx
	
	mov dx,[BmpLeft]
	
	
@@NextLine:
	push cx
	push dx
	
	mov di,cx  ; Current Row at the small bmp (each time -1)
	add di,[BmpTop] ; add the Y on entire screen
	
	; next 5 lines  di will be  = cx*320 + dx , point to the correct screen line
	mov cx,di
	shl cx,6
	shl di,8
	add di,cx
	add di,dx
	
	; small Read one line
	mov ah,3fh
	mov cx,[BmpColSize]  
	add cx,bp  ; extra  bytes to each row must be divided by 4
	mov dx,offset ScreenLineMax
	int 21h
	; Copy one line into video memory
	cld ; Clear direction flag, for movsb
	mov cx,[BmpColSize]  
	mov si,offset ScreenLineMax
	rep movsb ; Copy line to the screen
	pop dx
	pop cx
	loop @@NextLine
	pop cx
	ret
endp ShowBMP

proc InitRandom
;=======================================================
; InitRandom Proc
; Initialize the random seed with the clock.
;
; Return:
; None
;=======================================================
	push ax es

	mov ax, 40h
	mov es, ax
	mov ax, [CLOCK]
	mov [RndSeed], ax

	pop es ax
	ret
endp InitRandom

proc GenerateRandNum
;=======================================================
; GenerateRandNum Proc
; Generates a pseudo-random 15-bit number.
;
; NOTE:
; the algorithm describe http://stackoverflow.com/a/43978947/5380472
;
; Return Value -&gt; AX:
; AX contains the random number.
;=======================================================
push bx cx dx si di

; 32-bit multiplication in 16-bit mode (DX:AX * CX:BX == SI:DI)
	mov ax, [RndSeed]
	xor dx, dx
	mov cx, 041C6h
	mov bx, 04E6Dh
	xor di, di
	push ax

	mul bx
	mov si, dx
	xchg di, ax
	mul bx
	add si, ax
	pop ax
	mul cx
	add si, ax

	; Do addition
	add di, 3039h
	adc si, 0

	; Save seed
	mov [RndSeed], di

	; Get result and mask bits
	mov ax, si
	and ah, 07Fh

	pop di si dx cx bx
	ret
endp GenerateRandNum

proc RandomWithRange
	LOW_LIMIT equ [bp + 6]
	HIGH_LIMIT equ [bp + 4]

	push bp
	mov bp, sp
	push dx

	mov dx, HIGH_LIMIT
	sub dx, LOW_LIMIT

	call GenerateRandNum
	and ax, dx

	add ax, LOW_LIMIT

	pop dx bp
	ret 4
endp RandomWithRange



;=======================================================
;proc for moving the Rocket 
;=======================================================
proc MoveRocket
	push dx cx 
	mov [BmpLeft], 20
    mov [BmpColSize], Rocket_X ;the x of the picture 
    mov [BmpRowSize], Rocket_Y ;the y of the picture 
    mov dx, offset Rocket
	
	cmp [BmpTopRocket],176 ;the ground
	jne DoNothing
	call NewRocket
	
DoNothing:

	inc [BmpTopRocket]	
    
	mov cx,[BmpLeftRocket] 
	mov [BmpLeft],cx

	mov cx,[BmpTopRocket] 
	mov [BmpTop],cx		
	call OpenShowBmp
	;delete Rocket and print new Rocket from the top
	
	pop cx dx
	ret
endp MoveRocket


;=======================================================
;proc for cheking if you press A or D ;you need to keep AX for later
;=======================================================
proc CheckKeyboard
WaitForData:

	call MoveRocket
	call CheckRocketCollision
	cmp ax, 1
	je @@ExitLose
	mov ah, 1
	int 16h 
	jz WaitForData
	; there is a key pressed
	mov ah, 0
	int 16h
	; ah = scan code of the key that was pressed
    cmp ah, D_Key
	je PressedD
	cmp ah, A_Key
	je PressedA
	jmp WaitForData ; wait for key until it is one of the keys above (D, E or A)
PressedD:
	; first delete the Player then draw new one
	push [BmpTopPlayer]
	push [BmpLeftPlayer]
	call DeletePlayer
	add [BmpLeftPlayer], 10
	ret
PressedA:
	push [BmpTopPlayer]
	push [BmpLeftPlayer]
	call DeletePlayer
	sub [BmpLeftPlayer], 10
	ret
@@ExitLose:

	ret ; ax is equal to 1.
endp CheckKeyboard

;=======================================================
; proc to delete the Player before moving him. 
; params ==> 1. BmpLeft (position x where to put the image). 2. BmpTop (position Y where to put the image)
;=======================================================
proc DeletePlayer
	push bp
	mov bp, sp

	mov [BmpColSize], Player_X
	mov [BmpRowSize], Player_Y
	mov ax, [bp + 4]
	mov [BmpLeft], ax
	mov ax, [bp + 6]
	mov [BmpTop], ax
	mov dx, offset Black
	call OpenShowBmp

	pop bp
	ret 4
endp DeletePlayer

;===============================
;Proc that move the player 
;==============================
proc MovePlayer
	push cx dx
	
    mov [BmpColSize], Player_X ;the x of the Player 
    mov [BmpRowSize], Player_Y ;the y of the Player 
    mov dx, offset Player 
    
	mov cx,[BmpLeftPlayer] 
	mov [BmpLeft],cx

	mov cx,[BmpTopPlayer] 
	mov [BmpTop],cx	

	call OpenShowBmp
	
	pop dx cx 
	ret 
endp MovePlayer

proc NewRocket
    push ax cx dx
	
	mov cx,[BmpLeftRocket] 
	mov [BmpLeft],cx

	mov cx,[BmpTopRocket] 
	mov [BmpTop],cx	
	mov dx , offset BRock
	call OpenShowBmp

	
	push 10 ;the min random range
	push 310 ;the max random range
	call RandomWithRange
	mov [BmpLeftRocket],ax 
	mov [BmpTopRocket],0
	mov ax, [BmpLeftRocket]
	mov [BmpLeft], ax
	mov ax, [BmpTopRocket]
	mov [BmpTop], ax
	
	pop dx cx ax
	ret
endp NewRocket





proc printNumber
        push ax bx dx
		
		call ChackTime
		sub cl, [StartMin]
		mov al,cl
		mov dh,20
		mov dl,32
		mov ah,2
		int 10h
		
        lea bx, [divisorTable]
    nextDigit:
        xor ah, ah
        div [byte ptr bx]
        add al, '0'
		mov dh,20
        call printCharacter
        mov al, ah
        add bx, 1
        cmp [byte ptr bx], 0
        jne nextDigit
        pop dx bx ax
        ret
    endp printNumber
   
   proc printCharacter
        push ax dx
        mov ah, 2
        mov dl, al
        int 21h
        pop dx ax
        ret
    endp printCharacter

;==============================	
;	Proc to chack the time  dh = seconds cl = Minutes
;==============================
	proc ChackTime
	
	mov ah, 2Ch ;call for timer
	int 21h
	
	ret
	endp ChackTime

	
;===============================
;check if there's collision between the player and rocket 
;==============================
proc CheckRocketCollision
	push cx bx 
	
	mov ax, [BmpTopRocket]
	add ax, Rocket_Y
	cmp [BmpTopPlayer], ax
	jne @@NoCollision
	
	; checking X collision
	
	mov cx, [BmpLeftRocket]
	add cx, 8 ; rocket_x / 2
	mov bx, [BmpLeftPlayer]
	
	mov [counter], Player_X
@@loopa: ;check every pixel in the player top if the rocket there
	cmp cx, bx
	je @@Collision
	inc bx
	dec [counter]
	cmp [counter], 0
	jne @@loopa
	jmp @@NoCollision


@@Collision: ; if there's collision ax = 1
	mov ax, 1
	jmp @@ExitProc

@@NoCollision: ;if there's no collision ax = 0
	mov ax, 0
@@ExitProc:
	
	pop bx cx ; you need to keep ax 
	ret
endp CheckRocketCollision



;================================
;START 
;================================
start:
	mov ax, @data
	mov ds, ax

	call InitRandom
    ; Open Graphic mode
    mov ax, 13h
    int 10h
	
	
PrintStart: ;the printing of the start screen
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], Screen_X
	mov [BmpRowSize], Screen_Y
	lea dx, [StartScreen] ; (mov dx, offset FileName)
	call OpenShowBmp
	
WaitForStart: ;waiting for the start 
	mov ah,0Ch
	mov al,07h
	int 21h
	cmp al,S_key
	je RulesPrint
	jmp WaitForStart
	
	;print the game;
	
RulesPrint: ;print the rules
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], Screen_X
	mov [BmpRowSize], Screen_Y
	lea dx, [Rules] ; (mov dx, offset FileName)
	call OpenShowBmp
	mov ah,0Ch
	mov al,07h
	int 21h
	jmp GamePrint
	
GamePrint: ; print and start the game
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], Screen_X
	mov [BmpRowSize], Screen_Y
	lea dx, [FileName] ; (mov dx, offset FileName)
	call OpenShowBmp

	
	; Printing the Player
	mov [BmpLeftPlayer], 150
    mov [BmpTopPlayer], 165

	mov ax, [BmpLeftPlayer]
	mov [BmpLeft], ax
	mov ax, [BmpTopPlayer]
	mov [BmpTop], ax
	mov [BmpColSize], Player_X
	mov [BmpRowSize], Player_Y
	mov dx, offset Player
	call OpenShowBmp
	
	
	; printing the Rocket
	mov [BmpLeftRocket], 160
    mov [BmpTopRocket], 0

	mov ax, [BmpLeftRocket]
	mov [BmpLeft], ax
	mov ax, [BmpTopRocket]
	mov [BmpTop], ax	
	
	; THIS PROCEDURE WORKS WITH THE VARIABLES [BMPLEFT] AND [BMPTOP]. NOT WITH BMPTOPRocket ETC..
    mov [BmpColSize], Rocket_X ;the x of the picture 
    mov [BmpRowSize], Rocket_Y ;the y of the picture 
    mov dx, offset Rocket
    call OpenShowBmp
	
SaveTime:
	call ChackTime
	mov [StartSec] , dh
	mov [StartMin] , cl
	
	
	
loopa: ;the loop is for reptying the process
	call CheckKeyboard
	call CheckRocketCollision
	cmp ax, 1 
	je ExitScreen
	call MovePlayer
	jmp loopa
   
ExitScreen: ;the printing of the end screen 
	mov [BmpLeft], 0
	mov [BmpTop], 0
	mov [BmpColSize], Screen_X
	mov [BmpRowSize], Screen_Y
	lea dx,[EndScreen]  ; (mov dx, offset FileName)
	call OpenShowBmp
	
	call printNumber
	
	mov ah,0Ch
	mov al,07h
	int 21h
    cmp al,Q_Key ; if q is pressed
	je exit
	jmp GamePrint
	
exit:
	; Back to text mode
    mov ah, 0
    mov al, 2
    int 10h
   
   mov ax, 4c00h
    int 21h
    END start

