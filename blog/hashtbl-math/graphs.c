#include <stdio.h>
#include <string.h>
#include <table.h>

void clear_line()
{
#define B "\b\b\b\b\b\b\b\b\b\b"
#define B2 B B
#define B3 B2 B2
#define B4 B3 B3
#define B5 B4 B4
#define W "      "
#define W2 W W
#define W3 W2 W2
#define W4 W3 W3
#define W5 W4 W4
        printf(B5 W5 B5);
        fflush(stdout);
}

#define CAPACITY (1 << 20)

void output_probes_vs_load_factor()
{
        puts("(avg #probes),(table load factor)");

        for (double l = 0.01; l < 1; l += 0.01) {
                table tbl;
                table_init(&tbl, CAPACITY, l);

                int nr_insert = (int)((double)CAPACITY * l);
                for (int n = 0; n < nr_insert; ++n) {
                        table_insert(&tbl, rand(), 0);
                }
                printf("(%f,%f),", l, (double)tbl.nr_probes / (double)nr_insert);

                table_free(&tbl);
        }
}

#define CAPACITY 1000
#define STEPS 100

void output_probes_vs_load()
{
        puts("(avg #probes),(table load)");

        double probes_at[STEPS];
        for (size_t i = 0; i < STEPS; ++i) {
                probes_at[i] = 0.0;
        }

        for (int n = 0; n < 1000000; ++n) {
                if (n % (1 << 10) == 0) {
                        clear_line();
                        printf("%f%% complete", (double)n / 100000);
                        fflush(stdout);
                }
                table tbl;
                table_init(&tbl, CAPACITY, 0.99999999);

                int nr_insert = CAPACITY - 1;
                for (int n = 0; n < nr_insert; ++n) {
                        size_t l = (size_t)(table_load(&tbl) * STEPS + 0.5);
                        size_t old_nr_probes = tbl.nr_probes;
                        table_insert(&tbl, rand(), 0);
                        size_t nr_probes = tbl.nr_probes - old_nr_probes;
                        probes_at[l] =
                                (probes_at[l] * (double)n + (double)nr_probes) / ((double)n + 1);
                }

                table_free(&tbl);
        }

        for (size_t i = 0; i < STEPS; ++i) {
                printf("(%f,%f),", (double)i / (double)STEPS, probes_at[i]);
        }
        puts("");
}