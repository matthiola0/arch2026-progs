#include "rubik.h"
#include "rubik_tables.h"

enum { MAX_DEPTH = 11 };

/* Host verification can count search events without changing target code. */
#ifndef RUBIK_EVENT
#define RUBIK_EVENT(event) ((void) 0)
#endif

static const uint16_t weights[6][7] = {
    {0, 720, 1440, 2160, 2880, 3600, 4320},
    {0, 120, 240, 360, 480, 600, 0},
    {0, 24, 48, 72, 96, 0, 0},
    {0, 6, 12, 18, 0, 0, 0},
    {0, 2, 4, 0, 0, 0, 0},
    {0, 1, 0, 0, 0, 0, 0},
};
static const char move_names[9][3] = {"R",  "R2", "R'", "B", "B2",
                                      "B'", "D",  "D2", "D'"};

typedef struct {
    uint16_t p, o, next_p, next_o;
    uint8_t face, turn, previous_face;
} frame_t;

static unsigned pattern_distance(unsigned p, unsigned o)
{
#if RB_STRONG
    unsigned s = rb_subset[p];
    return (rb_pdb[rb_ooffset[o] + (s >> 1)] >> ((s & 1u) << 2)) & 15u;
#else
    (void) p;
    return rb_odist[o];
#endif
}

/* Iterative deepening with an admissible maximum, same-face pruning, and
 * the permutation test first. This retains Homework 1's search structure.
 */
static unsigned solve(unsigned p, unsigned o, uint8_t moves[MAX_DEPTH])
{
    frame_t stack[MAX_DEPTH];
    if ((p | o) == 0)
        return 0;
    unsigned bound = rb_pdist[p], h = pattern_distance(p, o);
    if (h > bound)
        bound = h;
    for (; bound <= MAX_DEPTH; bound++) {
        RUBIK_EVENT(rounds);
        unsigned depth = 0, remaining = bound - 1;
        unsigned here_p = p, here_o = o, next_p, next_o;
        unsigned face = 0, turn, previous_face = 255;
        const uint16_t *p_row, *o_row;
    next_face:
        if (face == previous_face)
            face++;
        if (face == 3)
            goto backtrack;
        p_row = rb_perm[face];
        o_row = rb_orient[face];
        next_p = here_p;
        next_o = here_o;
        turn = 0;
    next_turn:
        if (turn == 3) {
            face++;
            goto next_face;
        }
        next_p = p_row[next_p];
        next_o = o_row[next_o];
        turn++;
        RUBIK_EVENT(candidates);
        if (rb_pdist[next_p] > remaining)
            goto next_turn;
        RUBIK_EVENT(permutation_passes);
        if (pattern_distance(next_p, next_o) > remaining)
            goto next_turn;
        RUBIK_EVENT(accepted);
        moves[depth] = (uint8_t) (face * 3u + turn - 1);
        if ((next_p | next_o) == 0)
            return depth + 1;
        stack[depth] = (frame_t) {here_p,
                                  here_o,
                                  next_p,
                                  next_o,
                                  (uint8_t) face,
                                  (uint8_t) turn,
                                  (uint8_t) previous_face};
        depth++;
        remaining--;
        here_p = next_p;
        here_o = next_o;
        previous_face = face;
        face = 0;
        goto next_face;
    backtrack:
        if (depth == 0)
            continue;
        depth--;
        remaining++;
        const frame_t *frame = &stack[depth];
        here_p = frame->p;
        here_o = frame->o;
        next_p = frame->next_p;
        next_o = frame->next_o;
        face = frame->face;
        turn = frame->turn;
        previous_face = frame->previous_face;
        p_row = rb_perm[face];
        o_row = rb_orient[face];
        goto next_turn;
    }
    return 0; /* Every valid cube has distance at most 11. */
}

int rubik_solve(const char *state, char *out, size_t cap)
{
    uint8_t cubies[7], moves[MAX_DEPTH];
    unsigned seen = 0, sum = 0, p = 0, o = 0;
    for (unsigned i = 0; i < 7; i++) {
        unsigned digit = (unsigned) ((unsigned char) state[i] - '1');
        if (digit >= 7 || ((seen >> digit) & 1u))
            return -1;
        seen |= 1u << digit;
        cubies[i] = (uint8_t) digit;
    }
    for (unsigned i = 0; i < 7; i++) {
        unsigned digit = (unsigned) ((unsigned char) state[7 + i] - '1');
        if (digit >= 3)
            return -1;
        sum += digit;
        if (i < 6)
            o = o * 3u + digit;
    }
    while (sum >= 3)
        sum -= 3;
    if (state[14] != '\0' || sum)
        return -1;
    for (unsigned i = 0; i < 6; i++) {
        unsigned smaller = 0;
        for (unsigned j = i + 1; j < 7; j++)
            smaller += cubies[j] < cubies[i];
        p += weights[i][smaller];
    }
    unsigned count = solve(p, o, moves);
    size_t bytes = 1;
    for (unsigned i = 0; i < count; i++)
        bytes += (i != 0) + 1u + (move_names[moves[i]][1] != '\0');
    if (bytes > cap) {
        if (cap)
            out[0] = '\0';
        return -2;
    }
    for (unsigned i = 0; i < count; i++) {
        if (i)
            *out++ = ' ';
        *out++ = move_names[moves[i]][0];
        if (move_names[moves[i]][1])
            *out++ = move_names[moves[i]][1];
    }
    *out = '\0';
    return (int) count;
}
