import { DarkTheme, DefaultTheme, ThemeProvider } from 'expo-router/react-navigation';
import { Stack } from 'expo-router/stack';
import { useColorScheme } from 'react-native';

import { LibraryProvider } from '@/data/library-context';

export default function RootLayout() {
  const appearance = useColorScheme();
  return (
    <ThemeProvider value={appearance === 'dark' ? DarkTheme : DefaultTheme}>
      <LibraryProvider>
        <Stack screenOptions={{ headerShown: false }}>
          <Stack.Screen name="index" />
          <Stack.Screen name="(tabs)" />
        </Stack>
      </LibraryProvider>
    </ThemeProvider>
  );
}
