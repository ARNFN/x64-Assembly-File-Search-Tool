.code

main PROC
    ; --- 数据传送 ---
    mov     rax, 100
    mov     rbx, rax
    lea     rcx, [rax + rbx + 10]

    ; --- 算术 ---
    add     rax, 50
    sub     rbx, 20
    imul    rax, rbx
    inc     rcx
    dec     rbx

    ; --- 逻辑与移位 ---
    xor     rdx, rdx
    or      rdx, 0FFh
    and     rdx, 0F0h
    shl     rax, 2
    shr     rbx, 1

    ; --- 比较与条件跳转 ---
    cmp     rax, rbx
    jg      skip_swap
    xchg    rax, rbx
skip_swap:

    ; --- 栈操作 ---
    push    rax
    pop     rcx

    ; --- 标志位测试 ---
    test    rax, rax
    setnz   dl
    movzx   rdx, dl

    xor     rax, rax
    ret
main ENDP

END