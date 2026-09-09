import { Stack } from 'expo-router/stack';

export default function TabStack() {
  return (
    <Stack screenOptions={{ headerLargeTitle: true }}>
      <Stack.Screen name="index" options={{ title: 'Settings' }} />
      <Stack.Screen name="build" options={{ title: 'Build Details', headerLargeTitle: false }} />
    </Stack>
  );
}
