/* Full host oracle and path verification; never linked into target code. */
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static unsigned rounds, candidates, permutation_passes, accepted;
#define RUBIK_EVENT(event) (event++)
#include "../src/rubik/rubik.c"

enum { NP = 5040, NO = 729, NS = NP * NO, KEEP = 64 };
static const unsigned char source[3][7] = {
    {1, 4, 2, 0, 3, 5, 6},
    {0, 1, 2, 4, 5, 6, 3},
    {0, 2, 5, 3, 1, 4, 6},
};
static const unsigned char twist[3][7] = {
    {1, 2, 0, 2, 1, 0, 0},
    {0, 0, 0, 1, 2, 1, 2},
    {0, 0, 0, 0, 0, 0, 0},
};
static const unsigned factorial[7] = {720, 120, 24, 6, 2, 1, 1};

static void unrank(unsigned p,
                   unsigned o,
                   unsigned char cp[7],
                   unsigned char co[7])
{
    unsigned char available[7] = {0, 1, 2, 3, 4, 5, 6};
    for (unsigned i = 0; i < 7; i++) {
        unsigned k = p / factorial[i];
        p %= factorial[i];
        cp[i] = available[k];
        for (unsigned j = k; j + 1 < 7 - i; j++)
            available[j] = available[j + 1];
    }
    unsigned sum = 0;
    for (unsigned i = 6; i-- > 0;) {
        co[i] = o % 3;
        sum += co[i];
        o /= 3;
    }
    co[6] = (3 - sum % 3) % 3;
}

static unsigned rank_p(const unsigned char cp[7])
{
    unsigned p = 0;
    for (unsigned i = 0; i < 7; i++) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < 7; j++)
            smaller += cp[j] < cp[i];
        p = p * (7 - i) + smaller;
    }
    return p;
}

static unsigned rank_o(const unsigned char co[7])
{
    unsigned o = 0;
    for (unsigned i = 0; i < 6; i++)
        o = o * 3 + co[i];
    return o;
}

static void turn(unsigned char cp[7], unsigned char co[7], unsigned face)
{
    unsigned char np[7], no[7];
    for (unsigned i = 0; i < 7; i++) {
        np[i] = cp[source[face][i]];
        no[i] = (co[source[face][i]] + twist[face][i]) % 3;
    }
    memcpy(cp, np, 7);
    memcpy(co, no, 7);
}

static void text(unsigned rank, char state[15])
{
    unsigned char cp[7], co[7];
    unrank(rank / NO, rank % NO, cp, co);
    for (unsigned i = 0; i < 7; i++) {
        state[i] = '1' + cp[i];
        state[i + 7] = '1' + co[i];
    }
    state[14] = 0;
}

static void verify_path(unsigned rank, const char *out, unsigned count)
{
    unsigned char cp[7], co[7];
    unrank(rank / NO, rank % NO, cp, co);
    unsigned n = 0;
    while (*out) {
        unsigned face = *out == 'R' ? 0 : *out == 'B' ? 1 : *out == 'D' ? 2 : 3;
        assert(face < 3);
        out++;
        unsigned turns = 1;
        if (*out == '2' || *out == '\'')
            turns = *out++ == '2' ? 2 : 3;
        for (unsigned t = 0; t < turns; t++)
            turn(cp, co, face);
        n++;
        if (*out) {
            assert(*out == ' ' && out[1] != 0);
            out++;
        }
    }
    assert(n == count && rank_p(cp) == 0 && rank_o(co) == 0);
}

struct expensive {
    unsigned rank, bound, candidates, permutation_passes, accepted, rounds;
};
static struct expensive top[KEEP];

static FILE *output(const char *name)
{
    char path[256];
    snprintf(path, sizeof path, "build/rubik/%s", name);
    FILE *f = fopen(path, "w");
    assert(f);
    return f;
}

int main(void)
{
    setvbuf(stdout, NULL, _IOLBF, 0);
    for (unsigned p = 0; p < NP; p++) {
        unsigned char cp[7], co[7];
        for (unsigned face = 0; face < 3; face++) {
            unrank(p, 0, cp, co);
            turn(cp, co, face);
            assert(rb_perm[face][p] == rank_p(cp));
        }
    }
    for (unsigned o = 0; o < NO; o++) {
        unsigned char cp[7], co[7];
        for (unsigned face = 0; face < 3; face++) {
            unrank(0, o, cp, co);
            turn(cp, co, face);
            assert(rb_orient[face][o] == rank_o(co));
        }
    }
    puts("All transition entries match the independent cubie model.");
    unsigned char *distance = malloc(NS);
    unsigned *queue = malloc(NS * sizeof *queue);
    assert(distance && queue);
    memset(distance, 255, NS);
    distance[0] = 0;
    queue[0] = 0;
    unsigned head = 0, tail = 1;
    while (head < tail) {
        unsigned here = queue[head++], p = here / NO, o = here % NO;
        for (unsigned face = 0; face < 3; face++) {
            unsigned np = p, no = o;
            for (unsigned t = 0; t < 3; t++) {
                np = rb_perm[face][np];
                no = rb_orient[face][no];
                unsigned there = np * NO + no;
                if (distance[there] == 255) {
                    distance[there] = distance[here] + 1;
                    queue[tail++] = there;
                }
            }
        }
    }
    assert(tail == NS);
    free(queue);
    unsigned histogram[12] = {0};
    for (unsigned rank = 0; rank < NS; rank++) {
        assert(distance[rank] <= 11);
        histogram[distance[rank]]++;
        unsigned p = rank / NO, o = rank % NO;
        assert(rb_pdist[p] <= distance[rank]);
        assert(pattern_distance(p, o) <= distance[rank]);
    }
    assert(histogram[11] == 2644);
    puts("BFS: 3674160 states, diameter 11, 2644 states at distance 11.");
    puts("Both heuristics are admissible over every legal state.");
    FILE *d11 = output("states_d11.txt");
    FILE *header = output("all_d11_probe.h");
    fputs("static const char probe_states[][15] = {\n", header);
    for (unsigned rank = 0; rank < NS; rank++) {
        if (distance[rank] == 11) {
            char state[15];
            text(rank, state);
            fprintf(d11, "%s\n", state);
            fprintf(header, "    \"%s\",\n", state);
        }
    }
    fclose(d11);
    fputs("};\nstatic const unsigned char probe_distance[] = {\n", header);
    for (unsigned i = 0; i < 2644; i++)
        fputs("11,", header);
    fputs("\n};\n", header);
    fclose(header);
    clock_t begin = clock();
    for (unsigned rank = 0; rank < NS; rank++) {
        char state[15], out[64];
        text(rank, state);
        rounds = candidates = permutation_passes = accepted = 0;
        int length = rubik_solve(state, out, sizeof out);
        assert(length == distance[rank]);
        verify_path(rank, out, length);
        /* Conservative assembly block counts, detailed in the record. */
        unsigned bound = 11 * candidates + 14 * permutation_passes +
                         90 * accepted + 100 * rounds + 2048;
        assert(bound < RUBIK_INSN_BUDGET);
        if (bound > top[KEEP - 1].bound) {
            unsigned i = KEEP - 1;
            while (i && bound > top[i - 1].bound) {
                top[i] = top[i - 1];
                i--;
            }
            top[i] = (struct expensive) {
                rank, bound, candidates, permutation_passes, accepted, rounds};
        }
        if ((rank + 1) % 250000 == 0)
            printf("Verified %u states in %.2f CPU seconds.\n", rank + 1,
                   (double) (clock() - begin) / CLOCKS_PER_SEC);
    }
    FILE *costs = output("worst_states.csv");
    header = output("worst_probe.h");
    fputs(
        "state,distance,conservative_bound,candidates,permutation_passes,"
        "accepted,rounds\n",
        costs);
    fputs("static const char probe_states[][15] = {\n", header);
    for (unsigned i = 0; i < KEEP; i++) {
        char state[15];
        text(top[i].rank, state);
        fprintf(costs, "%s,%u,%u,%u,%u,%u,%u\n", state, distance[top[i].rank],
                top[i].bound, top[i].candidates, top[i].permutation_passes,
                top[i].accepted, top[i].rounds);
        fprintf(header, "    \"%s\",\n", state);
    }
    fputs("};\nstatic const unsigned char probe_distance[] = {\n", header);
    for (unsigned i = 0; i < KEEP; i++)
        fprintf(header, "%u,", distance[top[i].rank]);
    fputs("\n};\n", header);
    fclose(header);
    fclose(costs);
    printf("PASS: exact shortest length and cubie replay for all %u states.\n",
           (unsigned) NS);
    printf("Largest conservative assembly bound: %u, budget %u.\n",
           top[0].bound, RUBIK_INSN_BUDGET);
    printf("Total search verification CPU seconds: %.2f\n",
           (double) (clock() - begin) / CLOCKS_PER_SEC);
    free(distance);
    return 0;
}
