package com.example.zomato.dto;

import com.example.zomato.entity.Notification;

import java.util.Date;

/** What a notification looks like to the app: never the user it belongs to, whose record holds a password hash and reset tokens. */
public record NotificationResponse(int id, Integer userId, String message, String type, boolean isRead, Date timestamp) {

    public static NotificationResponse from(Notification n) {
        return new NotificationResponse(n.getId(), n.getUser() == null ? null : n.getUser().getUserId(), n.getMessage(), n.getType(), n.isRead(), n.getTimestamp());
    }
}
