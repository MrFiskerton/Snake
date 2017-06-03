SECTION .data
;message db "Hello", 0              ;db stands for 'define bytes'.
SECTION .bss
SECTION .text

;---------------------------------------------------------------------------------;
%define SIZE 512                    ;MBR sector size (512 bytes).
%define BASE 0x7C00                 ;Address at which BIOS will load game.
;---------------------------------------------------------------------------------;
[BITS 16]                           ;Enable 16-bit real mode.
[ORG  BASE]                         ;This code start at this BASE memory address.
;---------------------------------------------------------------------------------; 
 
;-------------------Initialization------------------------------------------------;
Initialize:
    xor     ax, ax                  ;Set AX = 0. Need for set DS.
    mov     ds, ax                  ;Set DS to the point where code is loaded.
    mov     ah, 0x01
    mov     cx, 0x2000
    int     0x10                    ;Clear cursor blinking.
    mov     ax, 0x0305
    mov     bx, 0x031F
    int     0x16                    ;Increase delay before keybort repeat.

    ;cli                            ;Clear any interrupts (BIOS INT CALLS)
    ;hlt                            ;Halts the system
;---------------------------------------------------------------------------------;    

;------------------------Main-----------------------------------------------------;
Game_loop:
    call    Clear_screen            ;Clear the screen
    push    word [snake_pos]        ;Save snake head position for later
;---------------------------------------------------------------------------------; 

;------------------------Handle input---------------------------------------------;  
handle_input:                       ;---------------------------------------------;
    mov     ah, 0x01                ;Check if key available
    int     0x16
    jz      .no_input               ;if not, move on
    xor     ah, ah                  ;if the was a key, remove it from buffer
    int     0x16
    jmp     .switch_direction
.no_input:                          ;---------------------------------------------;
    mov     al, [last_move]         ;No keys, so we use the last one        
.switch_direction:                  ;---------------------------------------------;
    cmp     al, 'a'
    je      .left
    cmp     al, 's'
    je      .down
    cmp     al, 'd'
    je      .right
    cmp     al, 'w'
    jne     .no_input
.up:                                ;---------------------------------------------;
    dec    byte [snake_y_pos]
    jmp    .move_done               ;jump away
.left:                              ;---------------------------------------------;
    dec    byte [snake_x_pos]
    jmp    .move_done               ;jump away
.right:                             ;---------------------------------------------;
    inc    byte [snake_x_pos]
    jmp    .move_done               ;jump away
.down:                              ;---------------------------------------------;
    inc    byte [snake_y_pos]
.move_done:                         ;---------------------------------------------;
    mov    [last_move], al          ; save the direction
    mov    si, snake_body_pos       ; prepare body shift
    pop    ax                       ; restore read position into ax for body shift
;---------------------------------------------------------------------------------;    
    
;----------------------Update body------------------------------------------------;
update_body:
    mov    bx, [si]                 ; get element of body into bx
    test   bx, bx                   ; check if zero (not a part of the body)
    jz     .done_update             ; if zero, done. Otherwise
    mov    [si], ax                 ; move the data from ax, into current position
    add    si, 2                    ; increment pointer by two bytes
    mov    ax, bx                   ; save bx into ax for next loop
    jmp    update_body              ; loop
.done_update:                       ;---------------------------------------------;
    cmp    byte [grow_snake_flag], 1; snake should grow?
    jne    .add_snake_body_end      ; if not: jump to .add_snake_body_end
    mov    word [si], ax            ; save the last element at the next position
    mov    byte [grow_snake_flag], 0; disable grow_snake_flag
    add    si, 2                    ; increment si by 2
.add_snake_body_end:                ;---------------------------------------------;
    mov    word [si], 0x0000
;---------------------------------------------------------------------------------;    
print_stuff:
    xor     dx, dx                  ; set pos to 0x0000
    call    Move_cursor             ; move cursor
    mov     si, score_msg           ; prepare to print score string
    call    Print_string            ; print it
    mov     ax, [score]             ; move the score into ax
    call    Print_int               ; print it
    
    mov dx, 0x0100
    call    Move_cursor
    mov     si, rec_msg             ; prepare to print record string
    call    Print_string  
    mov     ax, [record]            ; move the record into ax
    call    Print_int 
        
    mov     dx, [food_pos]          ; set dx to the food position
    call    Move_cursor             ; move cursor there
    
    
    mov     ax, 0600h               ;color food in red
    mov     bh, 0x04
    mov     cx, dx
    int     0x10
    
    mov     al, '*'                 ; use '*' as food symbol
    call    Print_char              ; print food
    mov     dx, [snake_pos]         ; set dx to the snake head position
    call    Move_cursor             ; move there    
    mov     al, '@'                 ; use '@' as snake head symbol
    call    Print_char              ; print it
    mov     si, snake_body_pos      ; prepare to print snake body
    
snake_body_print_loop:
    lodsw                           ; load position from the body, and increment si
    test    ax, ax                  ; check if position is zero
    jz      check_collisions        ; if it was zero, move out of here
    mov     dx, ax                  ; if not, move the position into dx
    call    Move_cursor             ; move the cursor there
    mov     al, 'o'                 ; use 'o' as the snake body symbol
    call    Print_char              ; print it
    jmp     snake_body_print_loop   ; loop

check_collisions:
    mov    bx, [snake_pos]          ; move the snake head position into bx
    cmp    bh, 25                   ; check if we are too far .down
    jge    Game_over_hit_wall       ; if yes, jump
    cmp    bh, 0                    ; check if we are too far .up
    jl     Game_over_hit_wall       ; if yes, jump
    cmp    bl, 80                   ; check if we are too far to the .right
    jge    Game_over_hit_wall       ; if yes, jump
    cmp    bl, 0                    ; check if we are too far to the .left
    jl     Game_over_hit_wall       ; if yes, jump
    mov    si, snake_body_pos       ; prepare to check for self-collision
check_collisions_self:
    lodsw                           ; load position of snake body, and increment si
    cmp    ax, bx                   ; check if head position = body position
    je     Game_over_hit_self       ; if it is, jump
    or     ax, ax                   ; check if position is 0x0000 (we are done searching)
    jne    check_collisions_self    ; if not, loop

no_collision:
    mov    ax, [snake_pos]          ; load snake head position into ax
    cmp    ax, [food_pos]           ; check if we are on the food
    jne    game_loop_continued      ; jump if snake didn't hit food
    inc    word [score]             ; if we were on food, increment score
    mov    bx, 24                   ; set max value for random call (y-val - 1)
    call   Random                     ; generate random value
    push   dx                       ; save it on the stack
    mov    bx, 78                   ; set max value for random call
    call   Random                     ; generate random value
    pop    cx                       ; restore old random into cx
    mov    dh, cl                   ; move old value into high bits of new
    mov    [food_pos], dx           ; save the position of the new random food
    mov    byte [grow_snake_flag], 1; make sure snake grows
    mov    ax, [score] 
    cmp    ax, [record]
    jng    game_loop_continued
    inc    word [record]  
;---------------------------------------------------------------------------------;    
game_loop_continued:
    mov    cx, 0x0002               ; Sleep for 0,15 seconds (cx:dx)
    mov    dx, 0x49F0               ; 0x000249F0 = 150000
    mov    ah, 0x86
    int    0x15                     ; Sleep
    jmp    Game_loop                ; loop
;---------------------------------------------------------------------------------;

;-----------------Game over-------------------------------------------------------;
Game_over_hit_self:
    push   self_msg
    jmp    game_over

Game_over_hit_wall:
    push   wall_msg

game_over:                          ;---------------------------------------------;
    call   Clear_screen             ; clear field
    mov    dx, 0x0B17               ; display text in the center (12, 23)
    call   Move_cursor              ; move cursor to start of string
    mov    si, hit_msg              
    call   Print_string
    pop    si
    call   Print_string
    mov    si, retry_msg
    call   Print_string
.wait_for_restart:                  ;---------------------------------------------;
    xor    ah, ah                   ; get pressed symbol
    int    0x16
    cmp    al, 'r'                  ; if r - start new game, otherwise wait
    jne    .wait_for_restart        ;
    mov    word [snake_pos], 0x0B28 ; restore default values
    and    word [snake_body_pos], 0
    and    word [score], 0
    jmp    Game_loop                ; continue game
;---------------------------------------------------------------------------------;
    
;-------------------Screen functions----------------------------------------------;
Clear_screen:
    mov    ax, 0x0700               ; clear entire window (ah 0x07, al 0x00)
    mov    bh, 0x02                 ; green on black
    xor    cx, cx                   ; top .left = (0,0)
    mov    dx, 0x1950               ; bottom .right = (25, 80)
    int    0x10                     ; interrupt 10h
    xor    dx, dx                   ; set dx to 0x0000
    call   Move_cursor              ; move cursor
    ret
;---------------------------------------------------------------------------------;
Move_cursor:
    mov    ah, 0x02                 ; move to (dl, dh)
    xor    bh, bh                   ; page 0    
    int    0x10                     ; interrupt 10h 
    ret
;---------------------------------------------------------------------------------;
    
;-------------------Print---------------------------------------------------------;
print_string_loop:                  ;---------------------------------------------;
    call   Print_char
Print_string:                       ; print the string pointed to in si    
    lodsb                           ; load next byte from si
    test   al, al                   ; check if high bit is set (end of string)
    jns    print_string_loop        ; loop if high bit was not set
;---------------------------------------------------------------------------------;
Print_char:                         ; print the char at al
    and    al, 0x7F                 ; unset the high bit
    mov    ah, 0x0E
    int    0x10                     ; interrupt 10h
    ret
;---------------------------------------------------------------------------------;
Print_int:                          ; print the int in ax
    push   bp                       ; save bp on the stack
    mov    bp, sp                   ; set bp = stack pointer
    .push_digits:                   ;---------------------------------------------;
    xor    dx, dx                   ; clear dx for division
    mov    bx, 10                   ; set bx to 10
    div    bx                       ; divide by 10
    push   dx                       ; store remainder on stack
    test   ax, ax                   ; check if quotient is 0
    jnz    .push_digits             ; if not, loop
    .pop_and_print_digits:          ;---------------------------------------------;
    pop    ax                       ; get first digit from stackw
    add    al, '0'                  ; turn it into ascii digits
    call   Print_char               ; print it
    cmp    sp, bp                   ; is the stack pointer is at where we began?
    jne    .pop_and_print_digits    ; if not, loop
    pop    bp                       ; if yes, restore bp
    ret
;---------------------------------------------------------------------------------;    
    
;-------------------Utility functions---------------------------------------------;
Random:                             ; random number between 1 and bx. result in dx
    mov    ah, 0x00
    int    0x1A                     ; get clock ticks since midnight
    mov    ax, dx                   ; move lower bits into ax for division
    xor    dx, dx                   ; clear dx
    div    bx                       ; divide ax by bx to get remainder in dx
    inc    dx                       ; not zero
    ret
;---------------------------------------------------------------------------------;
    
;--------------------Messages-----------------------------------------------------;    
;(Encoded as 7-bit strings.) Last byte is an ascii value with its high bit set. 
hit_msg     db 'You hit', 0xA0      ; space
self_msg    db 'yoursel', 0xE6      ; f
wall_msg    db 'the wal', 0xEC      ; l
retry_msg   db '! Press r', 0xA0    ; space
score_msg   db 'Score:',  0xA0      ; space
rec_msg     db 'Record:', 0xA0      ; space
;---------------------------------------------------------------------------------;

;--------------------Variables----------------------------------------------------;
grow_snake_flag db 0
score dw 0
record dw 0
last_move db 'd'
snake_pos:
    snake_x_pos db 0x0F
    snake_y_pos db 0x0F
food_pos dw 0x0D0D    
snake_body_pos dw 0x0000
;---------------------------------------------------------------------------------;

;--------------------Padding and boot singnature----------------------------------;
times 510 - ($ - $$) db 0     ;Fill the rest of the code with 0, this will fill untill the code is 510 bytes.
dw 0xAA55                     ;This is a boot signature (2 bytes).
;---------------------------------------------------------------------------------;