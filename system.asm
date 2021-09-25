CODE_SEL equ 0x0008
DATA_SEL equ 0x0010
SCRN_SEL equ 0x0018
TSS0_SEL equ 0x0020
LDT0_SEL equ 0x0028
TASK0_CODE_SEL equ 0x000f
TASK0_DATA_SEL equ 0x0017

[bits 32]

;##############################################################################
;################################### INIT #####################################
;##############################################################################

init:
    mov ax, DATA_SEL
    mov ds, ax
    mov ss, ax
    mov esp, init_stack 
    call load_gdt
    call load_idt
    call flush_sreg
    call clear_screen
    call switch_to_task0

load_gdt:
    lgdt ds:[gdt_48]
    ret

load_idt:
    mov eax, CODE_SEL                       ;; prepare descriptor
    shl eax, 16
    mov ax, interrupt_ignore                 
    mov ebx, 0x8e00
    mov ecx, 256                            ;; copy to idt  
    mov esi, idt
f_li:
    mov dword ds:[esi], eax
    mov dword ds:[esi+4], ebx
    add esi, 8
    dec ecx
    jnz f_li
    mov eax, CODE_SEL                       ;; prepare syscall_gate descriptor
    shl eax, 16
    mov ax, sys_call
    mov edx, 0x0000ef00 
    mov ecx, 0x80
    lea esi, [idt+ecx*8]
    mov dword ds:[esi], eax                 ;; move to 0x80
    mov dword ds:[esi+4], edx  
    lidt ds:[idt_48]         
    ret

flush_sreg:
    mov ax, DATA_SEL
    mov ds, ax
    mov ss, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    ret

switch_to_task0:
    mov ax, TSS0_SEL
    ltr ax
    mov ax, LDT0_SEL
    lldt ax
    pushfd 
    and dword [esp], 0xffffbfff
    popfd 
    push dword TASK0_DATA_SEL
    push dword init_stack
    pushfd
    or dword ds:[esp], 0x00000200
    push dword TASK0_CODE_SEL
    push dword task0
    iret

;##############################################################################
;################################## TASK0 #####################################
;##############################################################################

task0:
    pushfd 
    pop eax
    int 0x80
    jmp $
    pushfd
    pop eax
    int 0x80
    jmp $

;##############################################################################
;################################ INTERRUPT ###################################
;##############################################################################

interrupt_ignore:
    push eax
    pushfd
    pop eax
    call print_reg
    call println
    pop eax
    iret

sys_call:
    push eax
    call print_reg
    call println
    pushfd
    pop eax
    call print_reg
    call println
    pop eax
    iret

time_interrupt:
    push ds
    push eax
    mov ax, DATA_SEL
    mov al, 0x20
    out 0x20, al
    call clear_screen
    pop eax
    pop ds
    iret

;##############################################################################
;############################### INIT STACK ###################################
;##############################################################################

    times 1024 db 0
init_stack:

;##############################################################################
;############################### IDT & GDT ####################################
;##############################################################################

idt_48:
    dw 256*8-1
    dd idt

gdt_48:
    dw 256*8-1
    dd gdt

idt:
    times 256 dd 0, 0

gdt:
    dw 0, 0, 0, 0
    dw 0x07ff, 0x0000, 0x9a00, 0x00c0
    dw 0x07ff, 0x0000, 0x9200, 0x00c0
    dw 0x0002, 0x8000, 0x920b, 0x00c0
    dw 0x0068, tss0, 0xe900, 0x0000
    dw 0x0040, ldt0, 0xe200, 0x0000
    times 256*8-($-gdt) db 0


;##############################################################################
;############################### PAGE TABLE ###################################
;##############################################################################

;##############################################################################
;################################## TASK ######################################
;##############################################################################

tss0:
    dd 0
    dd task0_kernel_stack, DATA_SEL
    dd 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0
    dd 0, 0, 0, 0, 0, 0
    dd LDT0_SEL, 0x8000000
    
ldt0:
    dw 0, 0, 0, 0
    dw 0x03ff, 0x0000, 0xfa00, 0x00c0
    dw 0x03ff, 0x0000, 0xf200, 0x00c0

    times 4096-($-tss0) db 0
task0_kernel_stack:

    times 4096*63 db 0 

;##############################################################################
;################################# PRINT ######################################
;##############################################################################

tty_pos:
    dw 0

println:
    push gs
    push ds
    push ebx
    push eax
    mov ax, SCRN_SEL
    mov gs, ax
    mov ax, DATA_SEL
    mov ds, ax
    mov ax, ds:[tty_pos]
    mov bl, 0x50
    div bl
    add al, 1
    mul bl
    mov ds:[tty_pos], ax
    pop eax
    pop ebx
    pop ds
    pop gs
    ret

printtb:
    push gs
    push ds
    push eax
    mov ax, SCRN_SEL
    mov gs, ax
    mov ax, DATA_SEL
    mov ds, ax
    mov ax, ds:[tty_pos]
    add ax, 4
    mov ds:[tty_pos], ax
    pop eax
    pop ds
    pop gs
    ret

print_char:
    push gs
    push ds
    push esi
    push ebp
    push eax 
    mov ax, SCRN_SEL
    mov gs, ax
    mov ax, DATA_SEL
    mov ds, ax
    mov ebp, esp
    mov si, ds:[tty_pos]
    shl si, 1
    mov al, ds:[ebp+3]
    mov gs:[si], al
    mov al, ds:[ebp+2]
    mov gs:[si+2], al
    mov al, ds:[ebp+1]
    mov gs:[si+4], al
    mov al, ds:[ebp]
    mov gs:[si+6], al
    shr si, 1
    add si, 4
    mov ds:[tty_pos], si
    pop eax
    pop ebp
    pop esi
    pop ds
    pop gs
    ret

clear_screen:
    push gs
    push ax
    push bx
    push cx
    push si
    mov ax, SCRN_SEL
    mov gs, ax
    mov bl, 32
    mov cx, 80 * 25
    mov si, 0
f_cs: 
    mov gs:[si], bl
    add si, 2
    dec cx
    jnz f_cs
    pop si
    pop cx
    pop bx
    pop ax
    pop gs
    ret

print_reg:
    push gs
    push ds
    push esi
    push ebp
    push eax
    mov ax, DATA_SEL
    mov ds, ax
    mov ax, SCRN_SEL
    mov gs, ax
    mov ebp, esp
    mov si, ds:[tty_pos]    
    shl si, 1    
    mov byte al, ds:[ebp+3] 
    call f_pr_1
    add si, 4
    mov byte al, ds:[ebp+2]
    call f_pr_1
    add si, 4
    mov byte al, ds:[ebp+1]
    call f_pr_1
    add si, 4
    mov byte al, ds:[ebp]
    call f_pr_1
    add si, 4
    shr si, 1
    mov ds:[tty_pos], si
    pop eax
    pop ebp
    pop esi
    pop ds
    pop gs
    ret
f_pr_1:
    push ax
    push bx
    push si
    mov bl, al
    and bl, 0x0f
    add si, 2
    call f_pr_2
    mov bl, al
    shr bl, 4
    sub si, 2
    call f_pr_2
    pop si
    pop bx
    pop ax
    ret
f_pr_2:
    push bx
    cmp bl, 0x09
    ja f_pr_3
    add bl, 48
    mov byte gs:[si], bl
    pop bx
    ret
f_pr_3:
    add bl, 55
    mov byte gs:[si], bl
    pop bx
    ret

;##############################################################################
;################################## END #######################################
;##############################################################################

    times 1024*512-($-$$) db 0
