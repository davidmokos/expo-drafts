import { Stack } from 'expo-router/stack';
import { preview } from '@/data/preview';

export default function TabStack() {
  return (
    <Stack screenOptions={{ headerLargeTitle: true }}>
      <Stack.Screen name="index" options={{ title: preview.libraryTitle }} />
      <Stack.Screen name="[id]" options={{ headerLargeTitle: false }} />
    </Stack>
  );
}
