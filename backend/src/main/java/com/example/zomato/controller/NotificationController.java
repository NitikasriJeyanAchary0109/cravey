package com.example.zomato.controller;

import com.example.zomato.dto.NotificationResponse;
import com.example.zomato.entity.Notification;
import com.example.zomato.repository.UserRepository;
import com.example.zomato.security.OwnershipService;
import com.example.zomato.services.NotificationService;
import org.springframework.http.HttpStatus;
import org.springframework.security.access.prepost.PreAuthorize;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.server.ResponseStatusException;

import java.util.List;

/**
 * A person reads, marks and deletes only their own notifications; an admin may do any of it and is the only one who can create them
 * (the weekly digest and other system notices are created by the server itself). Responses never include the user record.
 */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {

    private final NotificationService service;
    private final UserRepository users;
    private final OwnershipService ownership;

    public NotificationController(NotificationService service, UserRepository users, OwnershipService ownership) {
        this.service = service;
        this.users = users;
        this.ownership = ownership;
    }

    @PreAuthorize("hasRole('ADMIN')")
    @PostMapping
    public NotificationResponse send(@RequestBody Notification notification) {
        return NotificationResponse.from(service.send(notification));
    }

    /** The caller's own notifications, newest first; the app does not need to know its user id. */
    @GetMapping("/mine")
    public List<NotificationResponse> mine(Authentication auth) {
        return service.getByUserId(userIdOf(auth)).stream().map(NotificationResponse::from).sorted(NEWEST_FIRST).toList();
    }

    @GetMapping("/mine/unread")
    public List<NotificationResponse> mineUnread(Authentication auth) {
        return service.getUnreadNotifications(userIdOf(auth)).stream().map(NotificationResponse::from).sorted(NEWEST_FIRST).toList();
    }

    @GetMapping("/{id}")
    public NotificationResponse getById(@PathVariable Integer id, Authentication auth) {
        return NotificationResponse.from(requireOwn(id, auth));
    }

    @GetMapping("/user/{userId}")
    public List<NotificationResponse> getByUser(@PathVariable Integer userId, Authentication auth) {
        requireSelfOrAdmin(userId, auth);
        return service.getByUserId(userId).stream().map(NotificationResponse::from).sorted(NEWEST_FIRST).toList();
    }

    @GetMapping("/user/{userId}/unread")
    public List<NotificationResponse> getUnread(@PathVariable Integer userId, Authentication auth) {
        requireSelfOrAdmin(userId, auth);
        return service.getUnreadNotifications(userId).stream().map(NotificationResponse::from).sorted(NEWEST_FIRST).toList();
    }

    @PutMapping("/{id}/read")
    public NotificationResponse markAsRead(@PathVariable Integer id, Authentication auth) {
        requireOwn(id, auth);
        return NotificationResponse.from(service.markAsRead(id));
    }

    @DeleteMapping("/{id}")
    public void delete(@PathVariable Integer id, Authentication auth) {
        requireOwn(id, auth);
        service.deleteNotification(id);
    }

    private static final java.util.Comparator<NotificationResponse> NEWEST_FIRST =
            java.util.Comparator.comparing(NotificationResponse::timestamp, java.util.Comparator.nullsLast(java.util.Comparator.reverseOrder()));

    private int userIdOf(Authentication auth) {
        return users.findFirstByEmailIgnoreCase(auth.getName()).orElseThrow(() -> new ResponseStatusException(HttpStatus.UNAUTHORIZED, "User not found")).getUserId();
    }

    private void requireSelfOrAdmin(int userId, Authentication auth) {
        if (ownership.isAdmin(auth)) return;
        if (userIdOf(auth) != userId) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "These are not your notifications.");
    }

    /** The notification, if it is the caller's (or the caller is an admin); 404 if it does not exist, 403 if it is someone else's. */
    private Notification requireOwn(int id, Authentication auth) {
        Notification n = service.getById(id);
        if (ownership.isAdmin(auth)) return n;
        String owner = n.getUser() == null ? null : n.getUser().getEmail();
        if (owner == null || !owner.equalsIgnoreCase(auth.getName())) throw new ResponseStatusException(HttpStatus.FORBIDDEN, "This is not your notification.");
        return n;
    }
}
