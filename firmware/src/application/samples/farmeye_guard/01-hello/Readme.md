# Hello World


A simple Hello World example for WS63 embedded firmware.

## Build

```bash
python build.py wanglian_01_hello
```

## Output

```
===============================================
=                                             =
=           Hello World                       =
=                                             =
===============================================

System initializing...
[==============================>] 100%

Hello World!
```

## Technical Notes

- Uses `osal_kthread_create` for task creation
- Uses `osal_kthread_set_priority` for priority management
- Stack: startup task 0x1000 (4KB), main task 0x1200 (4.5KB)