global _start

section .data
    rows        equ 12
    cols        equ 30
    stride      equ 31
    bufsize     equ rows * stride

    paddle_size equ 3
    paddle_col  equ 2
    
    ball_char   equ 'O'

    ; Secuencias ANSI
    esc_home    db 27, '[', 'H'
    esc_home_len equ $ - esc_home

    esc_clear   db 27, '[', '2', 'J'
    esc_clear_len equ $ - esc_clear

    esc_hide_cursor db 27, '[', '?', '2', '5', 'l'
    esc_hide_len equ $ - esc_hide_cursor

    esc_show_cursor db 27, '[', '?', '2', '5', 'h'
    esc_show_len equ $ - esc_show_cursor

    ; Delay entre frames
    timespec:
        tv_sec  dd 0
        tv_nsec dd 50000000  ; 50ms

    ; Mensajes
    msg_score   db 'Score: '
    msg_score_len equ $ - msg_score

    msg_gameover db 13, 10, 'GAME OVER! Score: '
    msg_gameover_len equ $ - msg_gameover

    msg_title   db 27, '[', '2', 'J', 27, '[', 'H'
                db 13, 10
                db '   ╔═══════════════════════════╗', 13, 10
                db '   ║      PONG GAME ASM        ║', 13, 10
                db '   ╠═══════════════════════════╣', 13, 10
                db '   ║  W - Move Up              ║', 13, 10
                db '   ║  S - Move Down            ║', 13, 10
                db '   ║  Q - Quit                 ║', 13, 10
                db '   ║                           ║', 13, 10
                db '   ║  Press SPACE to start...  ║', 13, 10
                db '   ╚═══════════════════════════╝', 13, 10
    msg_title_len equ $ - msg_title

    ; Termios
    STDIN   equ 0
    TCGETS  equ 0x5401
    TCSETS  equ 0x5402
    ICANON  equ 2
    ECHO    equ 8

section .bss
    buffer      resb bufsize
    keybuf      resb 1
    paddle_row  resd 1
    ball_row    resd 1
    ball_col    resd 1
    dir_y       resd 1
    dir_x       resd 1
    score       resd 1
    ball_speed  resd 1
    frame_count resd 1
    game_state  resd 1
    
    termios_orig resb 60
    termios_new  resb 60
    score_buf    resb 12

section .text

; --------------------------------------
; CONFIGURAR TERMINAL
; --------------------------------------
setup_terminal:
    mov eax, 54
    mov ebx, STDIN
    mov ecx, TCGETS
    lea edx, [termios_orig]
    int 0x80

    lea esi, [termios_orig]
    lea edi, [termios_new]
    mov ecx, 60
    rep movsb

    lea eax, [termios_new]
    mov ebx, [eax + 12]
    mov ecx, ICANON
    or ecx, ECHO
    not ecx
    and ebx, ecx
    mov [eax + 12], ebx

    ; Configurar lectura no bloqueante (VTIME=0, VMIN=0)
    mov byte [eax + 22], 0
    mov byte [eax + 23], 0

    mov eax, 54
    mov ebx, STDIN
    mov ecx, TCSETS
    lea edx, [termios_new]
    int 0x80

    mov eax, 4
    mov ebx, 1
    lea ecx, [esc_hide_cursor]
    mov edx, esc_hide_len
    int 0x80

    ret

; --------------------------------------
; RESTAURAR TERMINAL
; --------------------------------------
restore_terminal:
    mov eax, 4
    mov ebx, 1
    lea ecx, [esc_show_cursor]
    mov edx, esc_show_len
    int 0x80

    mov eax, 54
    mov ebx, STDIN
    mov ecx, TCSETS
    lea edx, [termios_orig]
    int 0x80
    ret

; --------------------------------------
; REINICIAR JUEGO
; --------------------------------------
reset_game:
    mov dword [paddle_row], 4
    mov dword [ball_row], 6
    mov dword [ball_col], 15
    mov dword [dir_y], 1
    mov dword [dir_x], -1
    mov dword [ball_speed], 4
    mov dword [frame_count], 0
    ret

; --------------------------------------
; DIBUJAR BOLA
; --------------------------------------
draw_ball:
    mov ecx, dword [ball_row]
    imul ebx, ecx, stride
    
    mov ecx, dword [ball_col]
    add ebx, ecx
    
    lea esi, [buffer]
    add esi, ebx
    
    mov byte [esi], ball_char
    ret

; --------------------------------------
; ACTUALIZAR BOLA
; --------------------------------------
update_ball:
    mov eax, dword [frame_count]
    xor edx, edx
    mov ebx, dword [ball_speed]
    div ebx
    cmp edx, 0
    jne .end_ball_update

    ; Mover bola
    mov eax, dword [ball_row]
    add eax, dword [dir_y]
    mov dword [ball_row], eax
    
    mov eax, dword [ball_col]
    add eax, dword [dir_x]
    mov dword [ball_col], eax

    ; --- Colisiones Verticales (Techo y Piso) ---
    mov eax, dword [ball_row]
    
    ; Techo (Row 1)
    cmp eax, 1
    jg .check_bottom
    
    mov dword [ball_row], 1
    mov dword [dir_y], 1    ; Rebotar abajo
    jmp .horizontal_checks

.check_bottom:
    ; Piso (Row rows-2)
    mov ecx, rows
    sub ecx, 2
    cmp eax, ecx
    jl .horizontal_checks
    
    mov dword [ball_row], ecx
    mov dword [dir_y], -1   ; Rebotar arriba

.horizontal_checks:
    ; --- Colisiones Horizontales ---
    
    ; Pared Derecha
    mov eax, dword [ball_col]
    mov ecx, cols
    sub ecx, 2
    cmp eax, ecx
    jl .check_paddle_miss
    
    mov dword [ball_col], ecx
    mov dword [dir_x], -1   ; Rebotar izquierda
    jmp .end_ball_update

.check_paddle_miss:
    ; Verificar si perdio (toca pared izquierda)
    cmp eax, 1
    jg .check_paddle_hit
    
    mov dword [game_state], 2 ; Game Over
    ret

.check_paddle_hit:
    ; Verificar colision con paleta
    cmp dword [dir_x], -1
    jne .end_ball_update

    cmp eax, paddle_col
    jne .end_ball_update

    ; Verificar Y
    mov eax, dword [ball_row]
    mov ebx, dword [paddle_row]
    
    cmp eax, ebx
    jl .end_ball_update
    
    add ebx, paddle_size
    cmp eax, ebx
    jge .end_ball_update

    ; --- HIT PALETA ---
    mov dword [dir_x], 1 ; Rebotar derecha
    
    ; Score++
    mov eax, dword [score]
    inc eax
    mov dword [score], eax

    ; Aumentar dificultad
    xor edx, edx
    mov ebx, 5
    div ebx
    cmp edx, 0
    jne .end_ball_update
    
    mov eax, dword [ball_speed]
    cmp eax, 1
    jle .end_ball_update
    dec eax
    mov dword [ball_speed], eax

.end_ball_update:
    ret

; --------------------------------------
; IMPRIMIR NÚMERO
; --------------------------------------
print_number:
    push ebp
    mov ebp, esp
    sub esp, 12
    
    lea edi, [ebp - 1]
    mov byte [edi], 10
    dec edi
    
    mov ebx, 10
    xor ecx, ecx
    
.divide_loop:
    xor edx, edx
    div ebx
    add dl, '0'
    mov [edi], dl
    dec edi
    inc ecx
    test eax, eax
    jnz .divide_loop
    
    inc edi
    inc ecx
    
    mov eax, 4
    mov ebx, 1
    mov edx, ecx    ; Longitud a EDX
    mov ecx, edi    ; Puntero a ECX
    int 0x80
    
    mov esp, ebp
    pop ebp
    ret

; --------------------------------------
; LEER INPUT
; --------------------------------------
read_input:
    mov eax, 3
    mov ebx, STDIN
    lea ecx, [keybuf]
    mov edx, 1
    int 0x80
    
    cmp eax, 0
    jle .no_input
    
    mov al, byte [keybuf]
    ret

.no_input:
    xor eax, eax
    ret

; --------------------------------------
; MAIN
; --------------------------------------
_start:
    call setup_terminal

    mov dword [game_state], 0
    mov dword [score], 0
    call reset_game

.menu_loop:
    mov eax, 4
    mov ebx, 1
    lea ecx, [msg_title]
    mov edx, msg_title_len
    int 0x80
    
.wait_space:
    call read_input
    cmp al, ' '
    je .start_game
    cmp al, 'q'
    je .exit_game
    
    mov eax, 162
    lea ebx, [timespec]
    xor ecx, ecx
    int 0x80
    
    jmp .wait_space

.start_game:
    mov dword [game_state], 1
    mov dword [score], 0
    call reset_game

.frame_loop:
    inc dword [frame_count]

    ; Limpiar pantalla completa primero
    mov eax, 4
    mov ebx, 1
    lea ecx, [esc_clear]
    mov edx, esc_clear_len
    int 0x80

    mov eax, 4
    mov ebx, 1
    lea ecx, [esc_home]
    mov edx, esc_home_len
    int 0x80

    ; Limpiar buffer
    lea edi, [buffer]
    mov ecx, bufsize
    mov al, ' '
    rep stosb
    
    ; Agregar newlines
    lea edi, [buffer]
    mov ecx, rows
.add_newlines:
    add edi, cols
    mov byte [edi], 10
    inc edi
    loop .add_newlines

    ; --- DIBUJAR BORDES ---
    mov ecx, cols
    lea esi, [buffer]
    lea edi, [buffer + (rows-1)*stride]
.draw_horiz:
    mov byte [esi], '#'
    mov byte [edi], '#'
    inc esi
    inc edi
    loop .draw_horiz

    mov ecx, rows
    sub ecx, 2
    lea esi, [buffer + stride]
.draw_vert:
    mov byte [esi], '#'
    mov byte [esi + cols - 1], '#'
    add esi, stride
    loop .draw_vert

    ; Dibujar paleta
    mov ecx, dword [paddle_row]
    xor edx, edx

.paddle_loop:
    imul ebx, ecx, stride
    lea esi, [buffer]
    add esi, ebx
    add esi, paddle_col
    mov byte [esi], '|'

    inc ecx
    inc edx
    cmp edx, paddle_size
    jl .paddle_loop
    
    call update_ball
    call draw_ball

    cmp dword [game_state], 2
    je .show_gameover

    ; Mostrar score en la misma línea
    mov eax, 4
    mov ebx, 1
    lea ecx, [msg_score]
    mov edx, msg_score_len
    int 0x80

    mov eax, dword [score]
    call print_number

    ; Imprimir buffer del juego
    mov eax, 4
    mov ebx, 1
    lea ecx, [buffer]
    mov edx, bufsize
    int 0x80

    call read_input

    cmp al, 'q'
    je .exit_game
    
    cmp al, 'w'
    je .move_up
    cmp al, 's'
    je .move_down
    jmp .frame_delay

.move_up:
    mov eax, dword [paddle_row]
    cmp eax, 1
    je .frame_delay
    dec eax
    mov dword [paddle_row], eax
    jmp .frame_delay

.move_down:
    mov eax, dword [paddle_row]
    mov ecx, rows
    sub ecx, paddle_size
    dec ecx
    cmp eax, ecx
    je .frame_delay
    inc eax
    mov dword [paddle_row], eax

.frame_delay:
    mov eax, 162
    lea ebx, [timespec]
    xor ecx, ecx
    int 0x80
    
    jmp .frame_loop

.show_gameover:
    mov eax, 4
    mov ebx, 1
    lea ecx, [esc_clear]
    mov edx, esc_clear_len
    int 0x80

    mov eax, 4
    mov ebx, 1
    lea ecx, [msg_gameover]
    mov edx, msg_gameover_len
    int 0x80

    mov eax, dword [score]
    call print_number

    ; Esperar 2 segundos
    mov dword [tv_sec], 2
    mov dword [tv_nsec], 0
    mov eax, 162
    lea ebx, [timespec]
    xor ecx, ecx
    int 0x80
    mov dword [tv_sec], 0
    mov dword [tv_nsec], 50000000

    jmp .menu_loop

.exit_game:
    call restore_terminal
    
    mov eax, 1
    xor ebx, ebx
    int 0x80
