import { useApi } from './useApi'

// the games (App\Http\Controllers\Api\GameController, GameScoreController)
export function useGames() {
  const { isLoading, error, get, put } = useApi()

  function fetchGames() {
    return get('/games').then((response) => response.data)
  }

  function fetchGame(id) {
    return get(`/games/${id}`).then((response) => response.data)
  }

  return {
    isLoading,
    error,
    fetchGames,
    fetchGame,
    // the leaderboard of a game for the player: { scores, worlds_best, personal_best, personal_best_for_period, league,
    // leagues_scores }
    fetchScores: (id) => get(`/games/${id}/scores`).then((response) => response.data),
    // the best score of the player in each period of a game
    fetchPeriodRecords: (id) => get(`/games/${id}/period-records`).then((response) => response.data),
    // the record of each game
    fetchSiteRecords: () => get('/site-records').then((response) => response.data),
    // { is_favorite }
    setFavorite: (id, isFavorite) => put(`/games/${id}/favorite`, { is_favorite: isFavorite }).then((response) => response.data),
  }
}
