#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <stdint.h>
#include <errno.h>
#include <stdbool.h>

typedef char ctrl_t;

#define CTRL_EMPTY 0
#define CTRL_DEL 1
#define CTRL_PRESENT -1

typedef intptr_t key_t;
typedef intptr_t val_t;

struct entry {
        ctrl_t meta;
        key_t key;
        val_t val;
};

typedef struct {
        struct entry *buf;
        // How many entries are currently occupied?
        size_t nr_occupied;
        size_t capacity;
        double load_factor;
        size_t nr_probes;
} table;

int table_init(table *, size_t, double);
struct entry *table_get_slot(table *, key_t);
int table_insert(table *, key_t, val_t);
val_t *table_get(table *, key_t);
void table_remove(table *, key_t);
void table_free(table *);
int table_realloc(table *, size_t);
double table_load(const table *);