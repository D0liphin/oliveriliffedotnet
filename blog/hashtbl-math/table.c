#include "table.h"

static inline size_t hash(char *bytes, size_t sz)
{
        size_t h = 0;
        for (size_t i = 0; i < sz; ++i) {
                h ^= bytes[i] << (i % sizeof(size_t)) * 8;
        }
        return h;
}

int table_init(table *tbl, const size_t capacity, const double load_factor)
{
        tbl->buf = NULL;
        if (capacity > 0) {
                tbl->buf = (struct entry *)calloc(capacity, sizeof(struct entry));
                if (tbl->buf == NULL) {
                        return ENOMEM;
                }
        }
        tbl->nr_occupied = 0;
        tbl->capacity = capacity;
        tbl->load_factor = load_factor;
        tbl->nr_probes = 0;
        return 0;
}

struct entry *table_get_slot(table *tbl, key_t k)
{
        size_t h = hash(&k, sizeof(key_t));
        for (size_t i = h % tbl->capacity; true; i = (i + 1) % tbl->capacity) {
                tbl->nr_probes++;
                struct entry *e = &tbl->buf[i];
                if (e->meta == CTRL_EMPTY) {
                        return e;
                } else if (e->meta == CTRL_DEL) {
                        continue;
                } else if (e->key == k) {
                        return e;
                }
        }
}

int table_insert(table *tbl, key_t k, val_t v)
{
        if (tbl->capacity == 0 || table_load(tbl) >= tbl->load_factor) {
                int err = table_realloc(tbl, tbl->capacity ? tbl->capacity * 2 : 8);
                if (err) {
                        return err;
                }
        }
        struct entry *e = table_get_slot(tbl, k);
        if (e->meta == CTRL_EMPTY) {
                e->meta = CTRL_PRESENT;
                e->key = k;
                e->val = v;
                tbl->nr_occupied++;
        } else {
                e->val = v;
        }
        return 0;
}

val_t *table_get(table *tbl, key_t k)
{
        struct entry *e = table_get_slot(tbl, k);
        if (e->meta == CTRL_EMPTY) {
                return NULL;
        } else {
                return &e->val;
        }
}

void table_remove(table *tbl, key_t k)
{
        struct entry *e = table_get_slot(tbl, k);
        if (e->meta == CTRL_PRESENT) {
                e->meta = CTRL_DEL;
                tbl->nr_occupied--;
        }
}

void table_free(table *tbl)
{
        if (tbl->buf) {
                free(tbl->buf);
        }
        tbl->buf = NULL;
        tbl->capacity = 0;
        tbl->nr_occupied = 0;
}

int table_realloc(table *tbl, size_t new_capacity)
{
        table new_tbl;
        int err = table_init(&new_tbl, new_capacity, tbl->load_factor);
        if (err) {
                return err;
        }
        for (size_t i = 0; i < tbl->capacity; ++i) {
                struct entry e = tbl->buf[i];
                if (e.meta == CTRL_PRESENT) {
                        table_insert(&new_tbl, e.key, e.val);
                }
        }
        table_free(tbl);
        *tbl = new_tbl;
        return 0;
}

double table_load(const table *tbl)
{
        return (double)tbl->nr_occupied / (double)tbl->capacity;
}