# Initial hypothesis

I believe the 502 errors are not currently caused by active CPU, memory, or disk resource exhaustion because CPU idle remained above 94%, I/O wait remained near 0%, swap activity was absent, and blocked processes remained at 0. However, the unusually large KijaniKiosk log directory (1.6G) may indicate uncontrolled log growth that could contribute to intermittent degradation. My next step is to inspect service and nginx logs to determine whether application or routing failures explain the 502 responses.
