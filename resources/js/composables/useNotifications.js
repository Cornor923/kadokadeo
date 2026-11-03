import { formatScore } from '@/composables/helpers'

import { useApi } from './useApi'
import { usePaginatedList } from './usePaginatedList'

// the text and the link of a notification of the player (App\Http\Resources\UserNotificationResource), in the tab
// « Notifications » and in the toasts
export function notificationText(notification) {
  const actor = notification.actor?.display_name ?? 'Un joueur'
  const game = notification.run?.game?.name
  const ofGame = game ? ` de ${game}` : ''
  switch (notification.type) {
    case 'run_comment':
      return `${actor} a commenté votre replay${ofGame}.`
    case 'comment_reply':
      return `${actor} a répondu à votre commentaire sur le replay${ofGame}.`
    case 'comment_likes': {
      const others = notification.count - 1
      return others > 0
        ? `${actor} et ${others} autre${others > 1 ? 's' : ''} ont aimé votre commentaire sur le replay${ofGame}.`
        : `${actor} a aimé votre commentaire sur le replay${ofGame}.`
    }
    case 'clan_application':
      return `${actor} demande à rejoindre votre clan ${notification.clan?.name ?? ''}.`
    case 'clan_accepted':
      return `Vous avez été accepté dans le clan ${notification.clan?.name ?? ''} !`
    case 'clan_refused':
      return `Votre candidature au clan ${notification.clan?.name ?? ''} a été refusée : vos points Kado vous ont été rendus.`
    default:
      return 'Nouvelle notification.'
  }
}

export function notificationLink(notification) {
  switch (notification.type) {
    case 'run_comment':
    case 'comment_reply':
    case 'comment_likes':
      return notification.run ? { name: 'runs.show', params: { id: notification.run.id }, query: notification.comment ? { comment: notification.comment.id } : {} } : null
    case 'clan_application':
      return notification.clan ? { name: 'clans.manage', params: { id: notification.clan.id } } : null
    case 'clan_accepted':
    case 'clan_refused':
      return notification.clan ? { name: 'clans.show', params: { id: notification.clan.id } } : null
    default:
      return null
  }
}

// the toasts of the feats of the clan of the player (App\Events\ClanToast)
export function clanToast(event) {
  const player = event.player?.display_name
  const game = event.game?.name
  switch (event.kind) {
    case 'defense_repelled':
      return { title: 'Défense réussie !', text: `${player} a réussi la défense sur ${game} (${formatScore(event.score)})`, to: { name: 'clans.status', params: { id: event.clan_id } } }
    case 'step_completed':
      return { title: 'Étape réussie !', text: `${player} a réussi l'étape ${game} (${formatScore(event.score)})`, to: { name: 'clans.missions', params: { id: event.clan_id } } }
    case 'mission_available':
      return { title: 'Clan', text: 'Nouvelle mission disponible', to: { name: 'clans.missions', params: { id: event.clan_id } } }
    default:
      return null
  }
}

// the notifications of the player, page by page (App\Http\Controllers\Api\NotificationController); onPage: what comes
// with a page (its unread counts)
export function useNotificationList({ onPage = null } = {}) {
  return usePaginatedList('/notifications', { onPage })
}

// what the player does with their notifications: read them all, delete one or all
export function useNotificationActions() {
  const { isLoading, error, post, del } = useApi()

  return {
    isLoading,
    error,
    // their unread counts after
    markRead: () => post('/notifications/read').then((response) => response.data.data),
    remove: (id) => del(`/notifications/${id}`),
    removeAll: () => del('/notifications'),
  }
}
