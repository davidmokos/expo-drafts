import { useState } from 'react';
import { Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from 'react-native';
import * as Updates from 'expo-updates';
import { openDrafts } from 'expo-drafts';

const variant = process.env.EXPO_PUBLIC_DRAFT_VARIANT || 'base';
const themes = {
  base: {
    color: '#d4ef83',
    label: 'Embedded build',
    title: 'One build.\nEvery draft.',
    note: 'Your starting point, bundled into the native app.',
  },
  amber: {
    color: '#ffb56b',
    label: 'Amber workspace',
    title: 'A warmer\nworkspace.',
    note: 'This screen arrived over EAS Update. No Metro connection.',
  },
  ocean: {
    color: '#8bc5ff',
    label: 'Ocean workspace',
    title: 'Room to\nthink clearly.',
    note: 'A second agent, a different idea, the same native build.',
  },
  native: {
    color: '#bca5ff',
    label: 'Camera experiment',
    title: 'A new native\ncapability.',
    note: 'This draft requires another native runtime.',
  },
};
const theme = themes[variant as keyof typeof themes] || themes.base;

export default function App() {
  const [count, setCount] = useState(0);
  return (
    <View style={styles.root}>
      <StatusBar barStyle="light-content" />
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <View style={[styles.mark, { backgroundColor: theme.color }]}>
            <Text style={styles.markText}>d.</Text>
          </View>
          <Text style={styles.brand}>DRAFTS LAB</Text>
          <Text style={styles.lab}>EXPERIMENT 001</Text>
        </View>
        <View style={styles.badge}>
          <View style={[styles.dot, { backgroundColor: theme.color }]} />
          <Text style={[styles.badgeText, { color: theme.color }]} testID="draft-variant">
            {theme.label}
          </Text>
        </View>
        <Text style={styles.hero}>{theme.title}</Text>
        <Text style={styles.intro}>{theme.note}</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Browse drafts"
          onPress={openDrafts}
          style={[styles.primary, { backgroundColor: theme.color }]}>
          <Text style={styles.primaryText}>Browse drafts</Text>
          <Text style={styles.arrow}>↗</Text>
        </Pressable>
        <View style={styles.rule} />
        <Text style={styles.eyebrow}>TRY SOMETHING</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Increment counter"
          onPress={() => setCount(count + 1)}
          style={styles.counter}>
          <View>
            <Text style={styles.counterTitle}>Make yourself at home</Text>
            <Text style={styles.muted}>Tap to check this draft is interactive.</Text>
          </View>
          <Text style={[styles.count, { color: theme.color }]}>{count}</Text>
        </Pressable>
        <Text style={[styles.eyebrow, { marginTop: 30 }]}>RUNNING ON THIS DEVICE</Text>
        <View style={styles.details}>
          <Detail label="Source" value={Updates.isEmbeddedLaunch ? 'Native build' : 'EAS Update'} />
          <Detail label="Runtime" value={Updates.runtimeVersion || 'Unavailable in development'} />
          <Detail label="Update" value={Updates.updateId || 'Embedded'} />
        </View>
        <Text style={styles.footer}>
          Use the floating drafts button to switch drafts from anywhere in the app.
        </Text>
      </ScrollView>
    </View>
  );
}
function Detail({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.detail}>
      <Text style={styles.detailLabel}>{label}</Text>
      <Text selectable style={styles.detailValue}>
        {value}
      </Text>
    </View>
  );
}
const styles = StyleSheet.create({
  root: { flex: 1, backgroundColor: '#111312' },
  content: { paddingTop: 78, paddingHorizontal: 28, paddingBottom: 120 },
  header: { flexDirection: 'row', alignItems: 'center', marginBottom: 58, gap: 10 },
  mark: { width: 33, height: 33, borderRadius: 10, alignItems: 'center', justifyContent: 'center' },
  markText: { fontWeight: '800', fontSize: 25, color: '#111312', marginTop: -3 },
  brand: { color: '#f6f6ee', fontSize: 12, fontWeight: '700', letterSpacing: 1.6 },
  lab: { color: '#777e78', fontSize: 9, marginLeft: 'auto', letterSpacing: 1 },
  badge: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    gap: 8,
    alignItems: 'center',
    marginBottom: 23,
  },
  dot: { width: 6, height: 6, borderRadius: 3 },
  badgeText: { fontSize: 13, fontWeight: '600' },
  hero: { color: '#f4f5ee', fontSize: 53, lineHeight: 57, fontWeight: '600', letterSpacing: -2.8 },
  intro: { color: '#9ca59d', marginTop: 22, fontSize: 16, lineHeight: 24, maxWidth: 320 },
  primary: {
    marginTop: 30,
    padding: 18,
    borderRadius: 17,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  primaryText: { fontSize: 16, fontWeight: '700', color: '#172016' },
  arrow: { fontSize: 19, color: '#172016' },
  rule: { height: 1, backgroundColor: '#2c302c', marginVertical: 35 },
  eyebrow: {
    color: '#788278',
    fontSize: 10,
    letterSpacing: 1.8,
    fontWeight: '600',
    marginBottom: 16,
  },
  counter: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  counterTitle: { color: '#e6e9e2', fontSize: 17, fontWeight: '500', marginBottom: 7 },
  muted: { color: '#8c968d', fontSize: 12 },
  count: { fontSize: 33, fontWeight: '400', fontVariant: ['tabular-nums'] },
  details: {
    backgroundColor: '#1c201c',
    borderRadius: 17,
    paddingHorizontal: 17,
    paddingVertical: 5,
  },
  detail: { paddingVertical: 12, gap: 5 },
  detailLabel: { color: '#849084', fontSize: 11 },
  detailValue: { color: '#d4dcd2', fontFamily: 'Menlo', fontSize: 10 },
  footer: { color: '#788278', fontSize: 12, lineHeight: 19, marginTop: 22, maxWidth: 285 },
});
