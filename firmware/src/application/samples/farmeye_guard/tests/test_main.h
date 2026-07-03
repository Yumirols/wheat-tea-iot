#ifndef __TEST_MAIN_H__
#define __TEST_MAIN_H__

#include "common_def.h"

#define TEST_PASS 0
#define TEST_FAIL -1

#define TEST_DELAY_MS 3000

typedef int (*test_func_t)(void);

typedef struct {
    const char *name;
    test_func_t func;
} test_case_t;

void test_runner(const test_case_t *cases, int count);

#endif
