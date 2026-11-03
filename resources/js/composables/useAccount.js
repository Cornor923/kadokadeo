import { useApi } from './useApi'

// the account of the player: the themes of the site, bought with Kado points (App\Http\Controllers\Api\ThemeController),
// and their preferences (App\Enums\UserPreference)
export function useAccount() {
  const { isLoading, error, get, post, put } = useApi()

  return {
    isLoading,
    error,
    fetchThemes: () => get('/themes').then((response) => response.data.data),
    buyTheme: (key) => post(`/themes/${key}/buy`),
    chooseTheme: (key) => put('/user/theme', { theme: key }),
    // their preferences after
    savePreferences: (preferences) => put('/user/preferences', preferences).then((response) => response.data.data),
  }
}
