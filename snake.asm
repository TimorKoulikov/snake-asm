;;Simple snake game in 8086
;; to run :	qemu-system-i386 -drive format=raw,file=invaders.bin

;; NOTE: Assuming direction flag is clear, SP initialized to 6EF0h, BP = 0
use16
org 07C00h		

;;DEFIEND MEMORY LAYOUT=========================================
;;Momery start at FA00h-after the framebuffer.(320*200=Fa00h)
AppleXY         equ 0FA00h      ;MSB=Y LSB=X
DrawApple       equ 0Fa02h      ;bool-if draw new apple
Direction       equ 0FA03h      ;current move of snake
SnakeLen        equ 0FA04h      ;sizeof array
SnakeArr        equ 0FA05h      ;each byte is cords(y/x)           

;;CONSTANT=================================
VIDEO_MEMORY_ADR    equ 0A000h  
TIMER               equ 046Ch     
SCREEN_WIDTH        equ 320
SCREEN_HEIGHT       equ 200   
SnakeSizeInit       equ 10

UP                  equ 1
DOWN                equ 2  
LEFT                equ 3  
RIGHT               equ 4

;;Colors
Snake_Color         equ 02h ;Green
Apple_Color         equ 27h ;RED

;;SETUP Game==========================================


;; Set up video mode - VGA mode 13h, 320x200, 256 colors, 8bpp, linear framebuffer at address A000h
mov ax, 0013h
int 10h

;; Set up video memory
push VIDEO_MEMORY_ADR
pop es          ; ES -> A0000h

;;Placing Snake in memory
push Direction
pop di          ;ES:DI ->  Direction

mov  ax,UP
stosb           ;set Direction=Up

mov ax,SnakeSizeInit
mov cx,SnakeSizeInit
stosb               ;set SnakeSize=SnakeSizeInit
mov al,SCREEN_WIDTH/4     ;AL=x
mov ah,SCREEN_HEIGHT/4   ;AH=y
;mov ax,(SCREEN_WIDTH*SCREEN_HEIGHT/2)+(SCREEN_WIDTH/2)      ;Head is in the middle of the screen
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
        mov cl,byte es:[SnakeLen]
        mov si,SnakeArr             ;si->snake
        
        draw_snake:
            mov bl,Snake_Color
            mov bh,bl                   ;bx=2 bytes of snake color 
            lodsw                       ;get X/Y Of snake
            call get_screen_position


            xchg ax,bx                  ;ax stores the color
            mov [di+SCREEN_WIDTH],ax    ;set a row below 2 pixel in snake color
            stosw                       ;set 2 pixel in current row in snake color
        loop draw_snake
            
        
        ;;DRAW APPLE-using the tick timer for "random" effect

        draw_apple:
            ;;check if drawn
            mov si,AppleXY 
            push si
            lodsw               ;AL=X Ah=Y
            mov dx,ax           ; save AX value          
            lodsb               ;AL=APPLEDRAW
            cmp al,0            ;did we drew an apple
            xchg ax,dx             
            jne .draw           ;yes we did
            .random_position:   ;no we didnt
                mov ax, [CS:TIMER]          ;random value
                mov bl,SCREEN_WIDTH/2      ;the reaminder is X value
                div bl          ;ah=X          
                mov dl,ah       ;save X value
                mov ax, [CS:TIMER]          ;random value
                mov bl, SCREEN_HEIGHT/2      ;the reaminder is X value
                div bl              ;ah=Y 
                mov al,dl            ;ah=Y al =X
                mov dx,ax           ;save Ax value
            .draw:
                call get_screen_position        ;ax=cords of apple dx=APPLECOLOR
                mov al,Apple_Color         
                mov ah,al
                mov[di+SCREEN_WIDTH],ax
                stosw
            .change_stat:
            pop di          ;di points to APPLE X 
            xchg ax,dx      
            stosw
            mov ax,1        ;ax=apple drawn
            stosb

            
;;IF HIT WALL=============
        mov ax,es:[SnakeArr]        ;ax holds Y/X of head
       
        cmp al,0
        jb end_game
        cmp al,SCREEN_WIDTH/2
        ja end_game 
        cmp ah,0
        jb end_game
        cmp ah,SCREEN_HEIGHT/2
        ja end_game

;;IF HIT HIMSELF===========
        mov si,SnakeArr
        lodsw                       ;we dont want to start from the head
        mov bx,ax                   ;bx=snake head
        xor cx,cx
        mov cl,es:[SnakeLen]
        .check_if_hit:
            lodsw                       ;ax=snake part
            cmp ax,bx
            je end_game

            loop .check_if_hit
                    
;;IF EAT APPLE==================
    
        mov ax,es:[AppleXY]             ;ax =Cords of apple
        mov bx,es:[SnakeArr]            ;bx= cords of sanke head
        cmp ax,bx
        jne player_input                ;check if head hit apple
                                        ;yes, head hit apple
        mov byte es:[DrawApple],0       ;draw new apple
        mov bx, es:[SnakeLen]           ;bx=len
        add bx,bx                       ;each index is 1 word 
        mov di,SnakeArr                 ;di->head
        
        lea ax,[bx+di-2]       ;ax->prev tail
        lea bx,[bx+di]           ;bx->tail      
        lea di,[bx+2]          ;di->next tail

        sub ax,bx               ;calculate the diff 
        add [es:di],ax 
        add es:[SnakeLen],byte 1    ;inc length



        ;;GET PLAYER INPUT =========================
        player_input:   
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

       jmp update_snake     
        w_pressed:
            cmp byte es:[Direction],DOWN      ;cannot change direction to the opposite current direction
            je update_snake

            mov byte [Direction], UP
            jmp update_snake
        d_pressed:
            cmp byte es:[Direction],LEFT      ;cannot change direction to the opposite current direction
            je update_snake
        
            mov byte [Direction], RIGHT
            jmp update_snake
       a_pressed:
            cmp byte es:[Direction],RIGHT      ;cannot change direction to the opposite current direction
            je update_snake
        
            mov byte  [Direction], LEFT
            jmp update_snake
       s_pressed:
            cmp byte es:[Direction],UP      ;cannot change direction to the opposite current direction
            je update_snake

            mov byte  [Direction], DOWN
            jmp update_snake




        ;;Update Snake===========================
        update_snake:

        
        xor cx,cx;
        movsx bx,es:[Direction]
        mov cl,es:[SnakeLen]
        mov si,SnakeArr
        mov di,SnakeArr 
        lodsw           ;ax=snake head

        mov dx,.switch      ;calculate offest to jump based on Direction Value
        imul bx,2
        sub bx,2
        add dx,bx 
        jmp dx 

        .switch:                ;direction is range between 1-4 , so we can use it to improve our swtich case
        jmp .move_up
        jmp .move_down
        jmp .move_left
        jmp .move_right

        .move_up:
            sub ah,1
            jmp loop_snake  
        .move_down:
            add ah,1  
            jmp loop_snake
        .move_left:
            sub al,1
            jmp loop_snake
        .move_right:
            add al,1
            jmp loop_snake


        loop_snake:

        mov bx,es:[di]
        stosw
        .inner_loop:
            xchg ax,bx 
            mov bx,es:[di]         
            stosw        
       
        loop .inner_loop 


        ;; Delay timer - 1 tick delay (1 tick = 18.2/second)
        delay_timer:
            mov ax, [CS:TIMER] 
            inc ax
            .wait:
                cmp [CS:TIMER], ax
                jl .wait
    jmp game_loop





;;END GAME REST=================================
end_game:
        xor ax, ax      ; Get a keystroke
        int 16h

        int 19h         ; Reload bootsector
;;HELPER_FUNCTIONS===================================



;; Get Y/X screen position in DI
;; Input parameters:
;;   AL = X value       0<X<A0h
;;   AH = Y value       0<Y<64h
;; Clobbers: 
;;   DX
;;   DI
get_screen_position:
    mov dx, ax      ; Save Y/X values
    xor ah,ah
    shl ax,1        ;X value *2             
    mov di,ax       ;DI=X value
    xor ax,ax
    mov al,dh       ;al=Y value 
    imul ax,ax,SCREEN_WIDTH*2  ; AX = Y value
    add di, ax      ; DI = Y value + X value or X/Y position

    ret





;; Boot signature ===================================
times 510-($-$$) db 0
dw 0AA55h
