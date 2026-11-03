<?php

namespace App\Enums;

// what a notification of a player is about (App\Services\NotificationService, user_notifications.type)
enum NotificationType: string
{
    // a comment on a replay of the player
    case RUN_COMMENT = 'run_comment';
    // an answer to a comment of the player
    case COMMENT_REPLY = 'comment_reply';
    // the likes of a comment of the player, in one notification (count, the last one who liked it)
    case COMMENT_LIKES = 'comment_likes';
    // an application to his clan, for its leader and its right hands (gone once someone answered it)
    case CLAN_APPLICATION = 'clan_application';
    // his application accepted
    case CLAN_ACCEPTED = 'clan_accepted';
    // his application refused by the leader or a right hand (his Kado points given back)
    case CLAN_REFUSED = 'clan_refused';
}
