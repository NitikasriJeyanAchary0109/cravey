package com.example.zomato.services;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/** The single owner of releasing drop slots: expired holds first, then waitlist upkeep. */
@Component
public class DropReservationScheduler {

    private static final Logger log = LoggerFactory.getLogger(DropReservationScheduler.class);

    private final DropService dropService;
    private final OrderService orderService;

    public DropReservationScheduler(DropService dropService, OrderService orderService) {
        this.dropService = dropService;
        this.orderService = orderService;
    }

    @Scheduled(fixedDelayString = "${drops.expiry-sweep-ms:15000}")
    public void sweep() {
        run("expire stale holds", dropService::expireStaleHolds);
        run("cancel orders left behind by lapsed holds", this::reconcileOrdersOfLapsedHolds);
        run("expire ended waitlists", dropService::expireEndedWaitlists);
        run("promote waitlists", dropService::promoteWaitlists);
    }

    /**
     * Backstop for the after-commit cancellation, which is in memory and not retried: any unpaid order whose
     * reservation already lapsed is cancelled here (and its PaymentIntent with it). Idempotent; an order whose
     * Stripe call failed stays open and is picked up again on the next sweep.
     */
    public int reconcileOrdersOfLapsedHolds() {
        int cancelled = 0;
        for (int orderId : orderService.findOrdersStrandedByLapsedHold()) {
            try {
                if (orderService.cancelOrderForLapsedHold(orderId)) cancelled++;
            } catch (Exception e) {
                log.warn("Drop sweep could not cancel order {} of a lapsed hold, will retry: {}", orderId, e.getMessage());
            }
        }
        return cancelled;
    }

    private void run(String what, java.util.function.IntSupplier task) {
        try {
            int n = task.getAsInt();
            if (n > 0) log.info("Drop sweep: {} -> {}", what, n);
        } catch (Exception e) {
            log.error("Drop sweep failed to {}: {}", what, e.getMessage(), e);
        }
    }
}
