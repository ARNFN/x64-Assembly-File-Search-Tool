; x64 Windows file finder - Win64 API, kernel32.lib only
; Usage: Asm1.exe "<search_root>" "<name|pattern>"

GetStdHandle       PROTO
WriteFile          PROTO
WriteConsoleW      PROTO
GetFileType        PROTO
ExitProcess        PROTO
GetCommandLineW    PROTO
GetFileAttributesW PROTO
FindFirstFileW     PROTO
FindNextFileW      PROTO
FindClose          PROTO
lstrcmpW           PROTO

FILE_ATTRIBUTE_DIRECTORY equ 10h
INVALID_HANDLE_VALUE     equ -1
INVALID_FILE_ATTRIBUTES  equ 0FFFFFFFFh
STD_OUTPUT_HANDLE        equ -11
FILE_TYPE_CHAR           equ 2
WIN32_FIND_DATAW_SIZE    equ 250h
PATH_BUF_CHARS           equ 520
MAX_DIR_STACK_INIT       equ 256
FD_CFileName             equ 44

.data
written          dd 0
matchCount       dd 0
dirStackCount    dd 0
dirStackCap      dd MAX_DIR_STACK_INIT
targetIsWildcard dd 0
patternStarIndex dd 0

msgUsage         db "Usage: Asm1.exe <search_root> <name|pattern>", 13, 10, 0
msgBadRoot       db "Error: search root not found or inaccessible.", 13, 10, 0
msgBadPattern    db "Error: invalid pattern (no path wildcards; single * only).", 13, 10, 0
msgNoMatch       db "NO MATCH", 13, 10, 0

bsName           dw '\', 0
crlfW            dw 13, 10, 0

searchRoot       dw PATH_BUF_CHARS dup(0)
targetName       dw PATH_BUF_CHARS dup(0)
pathWork         dw PATH_BUF_CHARS dup(0)
pathCurrent      dw PATH_BUF_CHARS dup(0)
dirStackMem      dw MAX_DIR_STACK_INIT * PATH_BUF_CHARS dup(0)

.code

PrintStr PROC
    push    rbx
    sub     rsp, 28h
    mov     rbx, rcx
    mov     r8, rbx
ps_len:
    cmp     byte ptr [r8], 0
    je      ps_len_done
    inc     r8
    jmp     ps_len
ps_len_done:
    sub     r8, rbx
    mov     rcx, STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     rcx, rax
    mov     rdx, rbx
    mov     r8d, r8d
    lea     r9, written
    mov     qword ptr [rsp+20h], 0
    call    WriteFile
    add     rsp, 28h
    pop     rbx
    ret
PrintStr ENDP

PrintWide PROC
    push    rbx
    push    rsi
    sub     rsp, 28h
    mov     rsi, rcx
    mov     rcx, rsi
    call    WStrLenW
    mov     ebx, eax
    test    ebx, ebx
    jz      pw_done
    mov     rcx, STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     rcx, rax
    call    GetFileType
    cmp     eax, FILE_TYPE_CHAR
    jne     pw_write_file
    mov     rcx, STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     rcx, rax
    mov     rdx, rsi
    mov     r8d, ebx
    lea     r9, written
    mov     qword ptr [rsp+20h], 0
    call    WriteConsoleW
    jmp     pw_done
pw_write_file:
    mov     eax, ebx
    shl     eax, 1
    mov     r8d, eax
    mov     rcx, STD_OUTPUT_HANDLE
    call    GetStdHandle
    mov     rcx, rax
    mov     rdx, rsi
    lea     r9, written
    mov     qword ptr [rsp+20h], 0
    call    WriteFile
pw_done:
    add     rsp, 28h
    pop     rsi
    pop     rbx
    ret
PrintWide ENDP

PrintWideLine PROC
    push    rbx
    mov     rbx, rcx
    mov     rcx, rbx
    call    PrintWide
    lea     rcx, crlfW
    call    PrintWide
    pop     rbx
    ret
PrintWideLine ENDP

WStrLenW PROC
    xor     eax, eax
    test    rcx, rcx
    je      wslen_done
    mov     rdx, rcx
wslen_loop:
    cmp     word ptr [rdx], 0
    je      wslen_done
    inc     eax
    add     rdx, 2
    jmp     wslen_loop
wslen_done:
    ret
WStrLenW ENDP

WStrCopyW PROC
    push    rsi
    push    rdi
    mov     rdi, rcx
    mov     rsi, rdx
wsc_loop:
    mov     ax, [rsi]
    mov     [rdi], ax
    test    ax, ax
    je      wsc_done
    add     rsi, 2
    add     rdi, 2
    jmp     wsc_loop
wsc_done:
    pop     rdi
    pop     rsi
    ret
WStrCopyW ENDP

WStrCatW PROC
    push    rbx
    mov     rbx, rcx
    mov     rcx, rbx
    call    WStrLenW
    lea     rdi, [rbx + rax*2]
    mov     rsi, rdx
wscat_loop:
    mov     ax, [rsi]
    mov     [rdi], ax
    test    ax, ax
    je      wscat_done
    add     rsi, 2
    add     rdi, 2
    jmp     wscat_loop
wscat_done:
    pop     rbx
    ret
WStrCatW ENDP

; RCX = dst, RDX = dir, R8 = name  => dst = dir\name
PathJoinW PROC
    push    rbx
    push    rsi
    push    rdi
    push    r12
    mov     rbx, rcx
    mov     rsi, rdx
    mov     r12, r8
    mov     rcx, rbx
    mov     rdx, rsi
    call    WStrCopyW
    mov     rcx, rsi
    call    WStrLenW
    test    eax, eax
    jz      pj_name_only
    mov     edi, eax
    dec     edi
    cmp     word ptr [rsi + rdi*2], '\'
    je      pj_at_name
    mov     word ptr [rbx + rax*2], '\'
    inc     eax
pj_at_name:
    mov     rdi, rbx
    mov     rsi, r12
pj_name_loop:
    mov     cx, [rsi]
    mov     word ptr [rdi + rax*2], cx
    test    cx, cx
    je      pj_done
    add     rsi, 2
    inc     eax
    jmp     pj_name_loop
pj_name_only:
    mov     rcx, rbx
    mov     rdx, r12
    call    WStrCopyW
pj_done:
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
PathJoinW ENDP

EnsureStackRoom PROC
    mov     eax, dirStackCount
    cmp     eax, dirStackCap
    setae   al
    ret
EnsureStackRoom ENDP

DirStackPush PROC
    push    rbx
    push    rsi
    push    rdi
    mov     rsi, rcx
    call    EnsureStackRoom
    test    al, al
    jnz     dsp_done
    mov     eax, dirStackCount
    imul    eax, PATH_BUF_CHARS * 2
    lea     rdi, dirStackMem
    add     rdi, rax
    mov     rcx, rdi
    mov     rdx, rsi
    call    WStrCopyW
    inc     dword ptr dirStackCount
dsp_done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret
DirStackPush ENDP

DirStackPop PROC
    push    rbx
    push    rsi
    push    rdi
    xor     eax, eax
    cmp     dword ptr dirStackCount, 0
    je      dspop_done
    dec     dword ptr dirStackCount
    mov     eax, dirStackCount
    imul    eax, PATH_BUF_CHARS * 2
    lea     rsi, dirStackMem
    add     rsi, rax
    mov     rdi, rcx
    mov     rcx, rdi
    mov     rdx, rsi
    call    WStrCopyW
    mov     eax, 1
dspop_done:
    pop     rdi
    pop     rsi
    pop     rbx
    ret
DirStackPop ENDP

FreeDirStack PROC
    mov     dirStackCount, 0
    ret
FreeDirStack ENDP

ParseArgsW PROC
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    sub     rsp, 28h
    call    GetCommandLineW
    mov     rsi, rax
pa_skip_ws:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], ' '
    je      pa_ws1
    cmp     word ptr [rsi], 9
    je      pa_ws1
    jmp     pa_tok0
pa_ws1:
    add     rsi, 2
    jmp     pa_skip_ws
pa_tok0:
    cmp     word ptr [rsi], '"'
    je      pa_q0
pa_t0:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], ' '
    je      pa_after0
    cmp     word ptr [rsi], 9
    je      pa_after0
    add     rsi, 2
    jmp     pa_t0
pa_q0:
    add     rsi, 2
pa_q0l:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], '"'
    je      pa_q0e
    add     rsi, 2
    jmp     pa_q0l
pa_q0e:
    add     rsi, 2
pa_after0:
    cmp     word ptr [rsi], 0
    je      pa_fail
pa_skip1:
    cmp     word ptr [rsi], ' '
    je      pa_ws2
    cmp     word ptr [rsi], 9
    je      pa_ws2
    jmp     pa_read1
pa_ws2:
    add     rsi, 2
    cmp     word ptr [rsi], 0
    je      pa_fail
    jmp     pa_skip1
pa_read1:
    lea     rdi, searchRoot
    cmp     word ptr [rsi], '"'
    je      pa_q1
pa_t1:
    cmp     word ptr [rsi], 0
    je      pa_t1z
    cmp     word ptr [rsi], ' '
    je      pa_t1z
    cmp     word ptr [rsi], 9
    je      pa_t1z
    mov     ax, [rsi]
    mov     [rdi], ax
    add     rsi, 2
    add     rdi, 2
    jmp     pa_t1
pa_q1:
    add     rsi, 2
pa_q1l:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], '"'
    je      pa_q1e
    mov     ax, [rsi]
    mov     [rdi], ax
    add     rsi, 2
    add     rdi, 2
    jmp     pa_q1l
pa_q1e:
    add     rsi, 2
pa_t1z:
    mov     word ptr [rdi], 0
pa_skip2:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], ' '
    je      pa_ws3
    cmp     word ptr [rsi], 9
    je      pa_ws3
    jmp     pa_read2
pa_ws3:
    add     rsi, 2
    jmp     pa_skip2
pa_read2:
    lea     rdi, targetName
    cmp     word ptr [rsi], '"'
    je      pa_q2
pa_t2:
    cmp     word ptr [rsi], 0
    je      pa_t2z
    cmp     word ptr [rsi], ' '
    je      pa_t2z
    cmp     word ptr [rsi], 9
    je      pa_t2z
    mov     ax, [rsi]
    mov     [rdi], ax
    add     rsi, 2
    add     rdi, 2
    jmp     pa_t2
pa_q2:
    add     rsi, 2
pa_q2l:
    cmp     word ptr [rsi], 0
    je      pa_fail
    cmp     word ptr [rsi], '"'
    je      pa_q2e
    mov     ax, [rsi]
    mov     [rdi], ax
    add     rsi, 2
    add     rdi, 2
    jmp     pa_q2l
pa_q2e:
    add     rsi, 2
pa_t2z:
    mov     word ptr [rdi], 0
    lea     rcx, searchRoot
    call    WStrLenW
    test    eax, eax
    jz      pa_fail
    lea     rcx, targetName
    call    WStrLenW
    test    eax, eax
    jz      pa_fail
    mov     al, 1
    jmp     pa_exit
pa_fail:
    xor     al, al
pa_exit:
    add     rsp, 28h
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
ParseArgsW ENDP

NormalizeRoot PROC
    push    rbx
    sub     rsp, 28h
    lea     rcx, searchRoot
    call    WStrLenW
    test    eax, eax
    jz      nr_fail
    cmp     eax, 2
    jne     nr_strip
    lea     rcx, searchRoot
    cmp     word ptr [rcx+2], ':'
    jne     nr_strip
    lea     rcx, searchRoot
    lea     rdx, bsName
    call    WStrCatW
nr_strip:
nr_sloop:
    lea     rcx, searchRoot
    call    WStrLenW
    cmp     eax, 3
    jle     nr_check
    dec     eax
    mov     edx, eax
    lea     rcx, searchRoot
    cmp     word ptr [rcx + rdx*2], '\'
    jne     nr_check
    mov     word ptr [rcx + rdx*2], 0
    jmp     nr_sloop
nr_check:
    lea     rcx, searchRoot
    call    GetFileAttributesW
    cmp     eax, INVALID_FILE_ATTRIBUTES
    je      nr_fail
    test    eax, FILE_ATTRIBUTE_DIRECTORY
    jz      nr_fail
    mov     al, 1
    jmp     nr_done
nr_fail:
    xor     al, al
nr_done:
    add     rsp, 28h
    pop     rbx
    ret
NormalizeRoot ENDP

; Scan targetName; AL=1 ok, AL=0 invalid pattern
ClassifyPattern PROC
    push    rbx
    push    rsi
    xor     ebx, ebx
    lea     rsi, targetName
cp_loop:
    mov     ax, [rsi]
    test    ax, ax
    je      cp_done_scan
    cmp     ax, '\'
    je      cp_fail
    cmp     ax, '*'
    jne     cp_next
    inc     ebx
    cmp     ebx, 1
    jg      cp_fail
    mov     rax, rsi
    lea     rcx, targetName
    sub     rax, rcx
    shr     rax, 1
    mov     patternStarIndex, eax
cp_next:
    add     rsi, 2
    jmp     cp_loop
cp_done_scan:
    cmp     ebx, 0
    je      cp_exact
    mov     targetIsWildcard, 1
    mov     al, 1
    jmp     cp_exit
cp_exact:
    mov     targetIsWildcard, 0
    mov     al, 1
    jmp     cp_exit
cp_fail:
    xor     al, al
cp_exit:
    pop     rsi
    pop     rbx
    ret
ClassifyPattern ENDP

; RCX = file name, RDX = pattern (targetName); AL=1 match
MatchNamePatternW PROC
    push    rbx
    push    rsi
    push    rdi
    push    r12
    push    r13
    push    r14
    mov     r12, rcx
    mov     r13, rdx
    mov     rcx, r12
    call    WStrLenW
    mov     r14d, eax
    mov     eax, patternStarIndex
    mov     ebx, eax
    lea     rcx, [r13 + rax*2 + 2]
    call    WStrLenW
    mov     edi, eax
    mov     eax, ebx
    add     eax, edi
    cmp     r14d, eax
    jl      mnp_no
    test    ebx, ebx
    jz      mnp_suffix
    xor     eax, eax
mnp_prefix_loop:
    cmp     eax, ebx
    jge     mnp_suffix
    mov     cx, [r12 + rax*2]
    cmp     cx, [r13 + rax*2]
    jne     mnp_no
    inc     eax
    jmp     mnp_prefix_loop
mnp_suffix:
    test    edi, edi
    jz      mnp_yes
    mov     eax, r14d
    sub     eax, edi
    lea     rcx, [r12 + rax*2]
    lea     rdx, [r13 + rbx*2 + 2]
    sub     rsp, 28h
    call    lstrcmpW
    add     rsp, 28h
    test    eax, eax
    jnz     mnp_no
mnp_yes:
    mov     al, 1
    jmp     mnp_done
mnp_no:
    xor     al, al
mnp_done:
    pop     r14
    pop     r13
    pop     r12
    pop     rdi
    pop     rsi
    pop     rbx
    ret
MatchNamePatternW ENDP

; RCX = wide file name pointer; AL=1 if . or ..
ShouldSkipEntry PROC
    cmp     word ptr [rcx], '.'
    jne     sse_no
    cmp     word ptr [rcx+2], 0
    je      sse_yes
    cmp     word ptr [rcx+2], '.'
    jne     sse_no
    cmp     word ptr [rcx+4], 0
    je      sse_yes
sse_no:
    xor     al, al
    ret
sse_yes:
    mov     al, 1
    ret
ShouldSkipEntry ENDP

SearchAllIterative PROC
    push    rbx
    push    rsi
    push    rdi
    sub     rsp, 280h
    mov     dirStackCount, 0
    lea     rcx, searchRoot
    call    DirStackPush
sai_loop:
    lea     rcx, pathCurrent
    call    DirStackPop
    test    eax, eax
    jz      sai_done
    lea     rcx, pathWork
    lea     rdx, pathCurrent
    call    WStrCopyW
    lea     rcx, pathWork
    call    WStrLenW
    lea     rdi, pathWork
    test    eax, eax
    jz      sai_only_star
    dec     eax
    cmp     word ptr [rdi + rax*2], '\'
    je      sai_append_star
    inc     eax
    mov     word ptr [rdi + rax*2], '\'
    inc     eax
    jmp     sai_put_star
sai_append_star:
    inc     eax
sai_put_star:
    mov     word ptr [rdi + rax*2], '*'
    mov     word ptr [rdi + rax*2 + 2], 0
    jmp     sai_pattern_done
sai_only_star:
    mov     word ptr [rdi], '*'
    mov     word ptr [rdi + 2], 0
sai_pattern_done:
    lea     rdx, [rsp+30h]
    lea     rcx, pathWork
    call    FindFirstFileW
    cmp     rax, INVALID_HANDLE_VALUE
    je      sai_loop
    mov     rbx, rax
sai_entry:
    lea     rcx, [rsp+30h + FD_CFileName]
    call    ShouldSkipEntry
    test    al, al
    jnz     sai_next
    cmp     dword ptr targetIsWildcard, 0
    je      sai_exact_match
    mov     eax, dword ptr [rsp+30h]
    test    eax, FILE_ATTRIBUTE_DIRECTORY
    jnz     sai_after_match
    lea     rcx, [rsp+30h + FD_CFileName]
    lea     rdx, targetName
    call    MatchNamePatternW
    test    al, al
    jz      sai_after_match
    jmp     sai_on_match
sai_exact_match:
    lea     rcx, [rsp+30h + FD_CFileName]
    lea     rdx, targetName
    call    lstrcmpW
    test    eax, eax
    jnz     sai_after_match
sai_on_match:
    lea     rcx, pathWork
    lea     rdx, pathCurrent
    lea     r8, [rsp+30h + FD_CFileName]
    call    PathJoinW
    lea     rcx, pathWork
    call    PrintWideLine
    inc     dword ptr matchCount
sai_after_match:
    lea     rcx, [rsp+30h + FD_CFileName]
    call    ShouldSkipEntry
    test    al, al
    jnz     sai_next
    mov     eax, dword ptr [rsp+30h]
    test    eax, FILE_ATTRIBUTE_DIRECTORY
    jz      sai_next
    lea     rcx, pathWork
    lea     rdx, pathCurrent
    lea     r8, [rsp+30h + FD_CFileName]
    call    PathJoinW
    lea     rcx, pathWork
    call    DirStackPush

sai_next:
    mov     rcx, rbx
    lea     rdx, [rsp+30h]
    call    FindNextFileW
    test    eax, eax
    jnz     sai_entry
    mov     rcx, rbx
    call    FindClose
    jmp     sai_loop
sai_done:
    call    FreeDirStack
    add     rsp, 280h
    pop     rdi
    pop     rsi
    pop     rbx
    ret
SearchAllIterative ENDP

main PROC
    sub     rsp, 28h
    call    ParseArgsW
    test    al, al
    jnz     main_args_ok
    lea     rcx, msgUsage
    call    PrintStr
    mov     ecx, 1
    call    ExitProcess
main_args_ok:
    call    NormalizeRoot
    test    al, al
    jnz     main_root_ok
    lea     rcx, msgBadRoot
    call    PrintStr
    mov     ecx, 1
    call    ExitProcess
main_root_ok:
    call    ClassifyPattern
    test    al, al
    jnz     main_pattern_ok
    lea     rcx, msgBadPattern
    call    PrintStr
    mov     ecx, 1
    call    ExitProcess
main_pattern_ok:
    mov     matchCount, 0
    call    SearchAllIterative
    cmp     dword ptr matchCount, 0
    jne     main_exit_ok
    lea     rcx, msgNoMatch
    call    PrintStr
main_exit_ok:
    xor     ecx, ecx
    call    ExitProcess
main ENDP

END
