; Grzegorz B. Zaleski (418494)

; Stałe do czytelnego wykonywania operacji W.
DONE equ 1
NOT_DONE equ 2
NO_PARTNER equ -1

global notec
extern debug
default rel

section .rodata
; Tablica mapująca zhashowane chary na index operacji lub cyfrę.
map db 4, 0, 0, 0, 2, 1, 0, 3, 0, 0, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 
    db 0, 0, 0, 0, 0, 0, 0, 23, 24, 25, 26, 27, 28, 10, 9, 11, 0, 0, 0, 6, 0, 
    db 0, 23, 24, 25, 26, 27, 28, 12, 5, 0, 7
    
; Jumptable z operacjami
function dq exit_input, addition, multiply, neg_arithm, and_bit, or_bit, xor_bit, 
         dq neg_bit, delete, duplicate, swap_top, push_index, call_debug, conc_swap

section .bss
; Tablice do współbieżnej wymiany przy operacji W
status resb N ; Stan Notecia (0 = nieodpalony / 1 = bezczynny /  2 = w trakcie wymiany)
values resq N ; Platforma do wymian miedzynoteciowych.
partner resd N ; Z którym Noteciem dany Noteć wykonuje wymiane.

section .text
; Hashuje bajt z r15 żeby można było go tablicować mniejszą tablicą.
hash:
    sub r15, 38
    cmp r15, 32
    jbe hash_finished
    sub r15, 17
    cmp r15, 48
    jbe hash_finished
    sub r15, 20
hash_finished:
    jmp post_hash

; Dane:
; rdi = id Notecia.
; rsi = pointer na tablice.
; W programie będziemy używać:
; r12 - id Notecia,
; r13 - flaga wpisywania,
; r8, r9, r14, r15 - zmienne do zapisywania i obróbki wczytywanych wartości.
notec:
    ; Zabezpieczenie danych.
    push rbp
    push r12
    push r13
    push r14
    push r15

    ; Zapamiętanie zmiennych i stosu (zgodność z ABI)
    mov rbp, rsp;

    ; Ustawienie braku aktualnej wymiany.
    lea r8, [rel partner]
    mov dword[r8 + rdi * 4], NO_PARTNER

    ; Ustawienie inicjalizacji Notecia.
    lea r8, [rel status]
    mov byte[r8 + rdi], DONE

    xor r13, r13 ; Flaga wpisywania ustawiona na fałsz.
    mov r12, rdi ; Zapamietany numer notecia.
begin:
    xor r15, r15
    mov r15b, byte[rsi] ; Pobrania kolejnego chara (bajtu).

    ; Jeśli to koniec inputu to kończymy program.
    test r15, r15
    jz finished

    inc rsi; Inkrementacja licznik.

    ; Corner case - N (ASCII = 78).
    cmp r15, 78
    jne not_n_case

    push N
    jmp exit_input

not_n_case:
    ; Drugi corner case - W (ASCII = 87).
    cmp r15, 87
    je conc_swap

    ; Cała reszta przechodzi przez hashowanie a potem wykonanie odpowiedniej operacji.
    jmp hash
post_hash:
    lea r8, [rel map]
    movzx r14, byte[r8 + r15]

    cmp r14, 12
    ja digit_input ; Operacja z cyfrą.

    ; Inna operacja
    lea r8, [rel function]
    jmp [r8 + 8 * r14]
    
finished:
    ; Zwracamy wierzchołek stosu.
    pop rax

    ; Przwrócenie stanu sprzed Notecia.
    mov rsp, rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbp

    ret

; -- OPERACJE -- 
; Operacja cyfry
digit_input:
    sub r14, 13 ; Wyrownanie liczby o kontrolną flage +13 wartości.

    test r13, r13
    jnz flag_on 
    ; Tryb wpisywania wyłaczony.
    push r14
    mov r13, 1 ; Włączenie flagi trybu wypisywania.
    jmp begin
    
flag_on:
    ; Tryb wpisywania włączony.
    ; top = top * 16 + r14 = top << 4 + r14
    shl qword[rsp], 4
    add [rsp], r14

    jmp begin

; Wyłączenie trybu wypisywania.
exit_input: 
    xor r13, r13 ; Flaga wypisywania ustawiona na 0.

    jmp begin

; Operacja dodania.
addition:
    pop r8
    add [rsp], r8

    jmp exit_input

; Operacja mnożenie.
multiply: 
    pop r8
    pop r9
    imul r8, r9
    push r8

    jmp exit_input

; Operacja odjęcia.
neg_arithm:
    neg qword[rsp]

    jmp exit_input

; Operacja koniukcji bitowej.
and_bit: 
    pop r8
    and [rsp], r8

    jmp exit_input

; Operacja alternatywy bitowej.
or_bit:
    pop r8
    or [rsp], r8

    jmp exit_input

; Operacja wykluczającej alternatywy bitowej.
xor_bit:
    pop r8
    xor [rsp], r8

    jmp exit_input

; Operacja negacji bitowej.
neg_bit:
    not qword[rsp]

    jmp exit_input

; Operacja usunięcia wierzchołka stosu.
delete:
    add rsp, 8

    jmp exit_input

; Operacja powielenia wierzchołka stosu.
duplicate:
    push qword[rsp]

    jmp exit_input

; Operacja zamiany wierzchołka stosu.
swap_top:
    pop r8
    pop r9
    push r8
    push r9

    jmp exit_input

; Operacja umieszczania indexu Notecia na stosie.
push_index:
    ; W tym miejscu należy sprawdzić kolizje hashy dla Z (ASCI = 90) i n.
    xor r15, r15
    mov r15b, byte[rsi - 1]
    cmp r15, 90
    je delete

    push r12

    jmp exit_input

; Operacja wywowała funkcji debug.
call_debug:
    mov r14, rsi ; Kopia wskaźnika na argumenty.
    mov r15, rsp ; Kopia wskaźnika stosu.

    ; Ustawienie argumentów.
    mov rdi, r12
    mov rsi, rsp
    and rsp, -16 ; Wyrównanie stosu.
    call debug ; Wywołanie funkcji.

    mov rsp, r15 ; Przywrócenie stosu.
    imul rax, 8 ; Każda pozycja to 8 bajtów.
    add rsp, rax ; Przesunięcie wierzchołka stosu.
    mov rsi, r14 ; Ustawienie wskaźnika spowrotem.

    jmp exit_input

; Operacja współbieżnej wymiany z innym Noteciem.
conc_swap:
    pop r9 ; Noteć z którym nastąpi wymiana.

    lea r8, [rel status]
    ; Czekanie aż parner będzie zainicjalizowany.
wait_for_partner_init:
    mov r10b, [r8 + r9]
    test r10b, r10b
    jz wait_for_partner_init

    ; Ustawienie flagi rozpoczęcia wymiany.
    lea r8, [rel status]
    mov byte[r8 + r12], NOT_DONE

    ; Wstawienie wartości do wymiany.
    pop r10
    lea r8, [rel values]
    mov [r8 + r12 * 8], r10 

    ; Ustawienie ID partnera.
    lea r8, [rel partner]
    mov [r8 + r12 * 4], r9d

    ; Czekanie aż partner ustawi czekanie na danego Notecia.
wait_for_partner:
    mov r10d, [r8 + r9 * 4]
    cmp r10d, r12d
    jne wait_for_partner

    ; Odebranie wartości z wymiany.
    lea r8, [rel values]
    mov r10, [r8 + r9 * 8]
    push r10

    ; Usunięcie ID partnera (koniec wymiany)
    lea r8, [rel partner]
    mov dword[r8 + r9 * 4], NO_PARTNER

    ; Zaznaczenie końca wymiany.
    lea r8, [rel status]
    mov byte[r8 + r9], DONE 

    ; Czekanie aż partner skończy.
wait_for_done:
    mov r10b, [r8 + r12]
    cmp r10b, NOT_DONE
    je wait_for_done

    jmp exit_input
