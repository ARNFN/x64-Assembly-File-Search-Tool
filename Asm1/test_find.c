#include <stdio.h>
#include <stddef.h>
#include <windows.h>
int main(void) {
    printf("off=%zu size=%zu\n", offsetof(WIN32_FIND_DATAW,cFileName), sizeof(WIN32_FIND_DATAW));
    WIN32_FIND_DATAW fd;
    HANDLE h = FindFirstFileW(L"C:\\Users\\ACCES\\source\\repos\\Asm1\\Asm1\\test_data\\*", &fd);
    if (h == INVALID_HANDLE_VALUE) {
        printf("fail err=%lu\n", GetLastError());
        return 1;
    }
    do {
        wprintf(L"name=%s attr=%lu\n", fd.cFileName, fd.dwFileAttributes);
    } while (FindNextFileW(h, &fd));
    FindClose(h);
    return 0;
}
