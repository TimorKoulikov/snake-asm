;;Simple snake game in 8086
;; to run :	qemu-system-i386 -drive format=raw,file=invaders.bin

;; NOTE: Assuming direction flag is clear, SP initialized to 6EF0h, BP = 0
use16
org 07C00h		

;;DEFIEND MEMORY LAYOUT=========================================
;;Momery start at FA00h-after the framebuffer.(A000h+320*220=Fa00h)
AppleX          equ 0FA00h
AppleY          equ 0FA01h    
DrawApple       equ 0Fa02h
Direcntion      equ 0FA03h
SnakeLen        equ 0FA04h 
SnakeArr        equ 0FA05h  ;each word is  a cord(X/Y)           

;;CONSTANT=================================
VIDEO_MEMORY_ADR    equ 0A000h
TIMER               equ 046Ch     
SCREEN_WIDTH        equ 320
SCREEN_HEIGHT       equ 200   
SnakeSizeInit       equ 5

UP                  equ 1
DOWN                equ 2  
LEFT                equ 3  
RIGHT               equ 4

;;Colors
Snake_Color         equ 02h ;Green
Apple_Color         equ 27h ;RED
;;SETUP==========================================




;; Set up video mode - VGA mode 13h, 320x200, 256 colors, 8bpp, linear framebuffer at address A000h
mov ax, 0013h
int 10h

;; Set up video memory
push VIDEO_MEMORY_ADR
pop es          ; ES -> A0000h

;;Placing Snake in memory
push SnakeLen
pop di          ;ES:DI ->  Head of Snake
mov ax,SnakeSizeInit
mov cx,ax 
stosb
mov ax,(SCREEN_WIDTH*SCREEN_HEIGHT/2)+(SCREEN_WIDTH/2)      ;Head is in the middle of the screen
place_snake:
    stosw
    add ax,1
    loop place_snake


push es 
pop ds          ;ES=DS

;;GAMELOOP==============================
game_loop:
    xor ax, ax      ; Clear screen to black first
    xor di, di
    mov cx, SCREEN_WIDTH*SCREEN_HEIGHT
    rep stosb       ; mov [ES:DI], al cx # of times

    ;;DRAW SNAKE
    mov cl,byte [SnakeLen]
    mov si,SnakeArr             ;si->snake
    
    draw_shot:
        mov bl,Snake_Color
        mov bh,bl                   ;bx=store 2 colors 
        xor di,di  
        lodsw                       ;get X/Y Of snake
        add di,ax                   ;di->pixel

        xchg ax,bx                  ;ax stores the color
        mov [di+SCREEN_WIDTH],ax 
        stosw 
        loop draw_shot
        
    
    ;;DRAW APPLE-using the tick timer for "random" effect

    draw_apple:
        ;;check if drawn
        mov si,AppleX 
        push si
        lodsw               ;AL=X Ah=Y
        mov dx,ax           ;DX not store CORDS
        lodsb               ;AL=APPLEDRAW
        cmp al,0            ;did we drew an apple
        
        jne .draw           ;yes we did
        .random_position:   ;no we didnt
            mov ax, [CS:TIMER]
            xor dx,dx
            mov cx,SCREEN_WIDTH*SCREEN_HEIGHT
            idiv bx                             ;dx:ax/ bx= ax |dx        
        .draw:
            mov al,Apple_Color
            mov ah,al
            xor di,di
            add di,dx
            mov[di+SCREEN_WIDTH],ax
            stosw
        .change_stat:
        mov ax,dx       ;AX=NEW CORDS
        pop di          ;di points to APPLE X 
        stosw
        mov ax,1        ;ax=apple drawn
        stosb 
        
        


    ;;CHECK SNAKE HEAD
;        mov ax,[AppleX]         ;AX=the head of snake
        ;;IF HIT HIMSELF

        ;;IF HIT WALL

        ;;IF EAT APPLE

    ;;GET PLAYER INPUT    
		mov ah, 1
		int 16h	        ;get key board status
        jz  update_snake 

        xor ah,ah
        int 16h         ;al=ascii

        cmp al,'w'      ;if 'w' pressed
            je w_pressed
        cmp al,'d'
            je d_pressed    ;if 'd' pressed
        cmp al,'a'
            je a_pressed    ;if 'a' pressed
        cmp al,'s'
            je s_pressed    ;if 's' pressed

        w_pressed:
            mov byte ptr [Direcntion], UP
            jmp update_snake
d_pressed:
            mov byte ptr [Direcntion], RIGHT
            jmp update_snake
a_pressed:
            mov byte ptr [Direcntion], LEFT
            jmp update_snake
s_pressed:
            mov byte ptr [Direcntion], DOWN
            jmp update_snake




    ;;Update Snake
    update_snake:
    ;bl =current move direnction
    mov cl,[SnakeLen]
    

     ;; Delay timer - 1 tick delay (1 tick = 18.2/second)
    delay_timer:
        mov ax, [CS:TIMER] 
        inc ax
        .wait:
            cmp [CS:TIMER], ax
            jl .wait
    jmp game_loop





;;END GAME REST=================================
end game:
    cli
    hlt 

;;HELPER_FUNCTIONS===================================



;; Get X/Y screen position in DI
;; Input parameters:
;;   AL = Y value
;;   AH = X value
;; Clobbers: 
;;   DX
;;   DI
get_screen_position:
    mov dx, ax      ; Save Y/X values
    cbw             ; Convert byte to word - sign extend AL into AH, AH = 0 if AL < 128
    imul di, ax, SCREEN_WIDTH*2  ; DI = Y value
    mov al, dh      ; AX = X value
    shl ax, 1       ; X value * 2
    add di, ax      ; DI = Y value + X value or X/Y position

    ret



;; Boot signature ===================================
times 510-($-$$) db 0
dw 0AA55h