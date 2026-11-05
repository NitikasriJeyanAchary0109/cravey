package com.example.zomato.services;

import com.example.zomato.entity.Notification;

import java.util.List;

public interface NotificationService {

    Notification send(Notification notification);

    Notification getById(Integer id);

    List<Notification> getByUserId(Integer userId);

    List<Notification> getUnreadNotifications(Integer userId);

    Notification markAsRead(Integer id);

    /** Marks every unread notification of one user as read; returns how many changed. */
    int markAllAsRead(Integer userId);

    void deleteNotification(Integer id);
}