#include "build/rubik/rubik_probe_states.h"
#include "print.h"
#include "src/rubik/rubik.h"
#include "tperf.h"

int main(void)
{
    char out[64];
    int failed = 0;
    for (unsigned i = 0; i < sizeof probe_states / sizeof probe_states[0];
         i++) {
        int c, a;
        uint64_t nc, na;
        PERF_CALL(nc, c = rubik_solve(probe_states[i], out, sizeof out));
        bm_printf(
            "@@probe state=%s impl=c length=%d instructions=%llu moves=%s\n",
            probe_states[i], c, nc, out);
        PERF_CALL(na, a = rubik_solve_asm(probe_states[i], out, sizeof out));
        bm_printf(
            "@@probe state=%s impl=asm length=%d instructions=%llu moves=%s\n",
            probe_states[i], a, na, out);
        if (a != c || a != probe_distance[i] || na > RUBIK_INSN_BUDGET ||
            nc > RUBIK_C_INSN_BUDGET)
            failed++;
    }
    bm_printf("@@probe failures=%d\n", failed);
    return failed != 0;
}
