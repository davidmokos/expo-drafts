import { useEffect, useState } from 'react';
import { Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from 'react-native';
import * as Updates from 'expo-updates';
import { openDrafts } from 'expo-drafts';

const durations = [5, 15, 25];
const intentions = ['Make something', 'Read a little', 'Clear my head'];

export default function App() {
  const [duration, setDuration] = useState(15);
  const [remaining, setRemaining] = useState(15 * 60);
  const [endsAt, setEndsAt] = useState<number | null>(null);
  const [completed, setCompleted] = useState(false);
  const [intention, setIntention] = useState(intentions[0]);
  const running = endsAt !== null;

  useEffect(() => {
    if (endsAt === null) return;
    const tick = () => {
      const seconds = Math.max(0, Math.ceil((endsAt - Date.now()) / 1000));
      setRemaining(seconds);
      if (seconds === 0) {
        setEndsAt(null);
        setCompleted(true);
      }
    };
    tick();
    const timer = setInterval(tick, 250);
    return () => clearInterval(timer);
  }, [endsAt]);

  function selectDuration(minutes: number) {
    setDuration(minutes);
    setRemaining(minutes * 60);
    setEndsAt(null);
    setCompleted(false);
  }

  function toggleTimer() {
    if (endsAt !== null) {
      setRemaining(Math.max(0, Math.ceil((endsAt - Date.now()) / 1000)));
      setEndsAt(null);
    } else {
      const seconds = remaining || duration * 60;
      setRemaining(seconds);
      setCompleted(false);
      setEndsAt(Date.now() + seconds * 1000);
    }
  }

  const minutes = String(Math.floor(remaining / 60)).padStart(2, '0');
  const seconds = String(remaining % 60).padStart(2, '0');
  const elapsed = 1 - remaining / (duration * 60);

  return (
    <ScrollView
      style={styles.root}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}>
      <StatusBar barStyle="dark-content" />
      <View style={styles.header}>
        <View style={styles.logo}>
          <Text style={styles.logoText}>d.</Text>
        </View>
        <Text style={styles.brand}>DRAFTS LAB</Text>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Browse drafts"
          onPress={openDrafts}
          style={styles.browse}>
          <Text style={styles.browseText}>Switch draft ↗</Text>
        </Pressable>
      </View>
      <Text style={styles.eyebrow} testID="draft-variant">
        FOCUS TIMER / EXPERIMENT 01
      </Text>
      <Text style={styles.title}>One thing.{'\n'}For a little while.</Text>
      <Text style={styles.intro}>Put a small pocket of time aside. Everything else can wait.</Text>

      <View style={styles.timerCard}>
        <View style={styles.timerHeading}>
          <Text style={styles.cardEyebrow}>YOUR FOCUS SESSION</Text>
          <View style={[styles.indicator, running && { backgroundColor: '#ec7048' }]} />
        </View>
        <Text
          style={styles.timer}
          accessibilityLabel={`${Number(minutes)} minutes and ${Number(seconds)} seconds remaining`}
          testID="focus-time">
          {minutes}
          <Text style={styles.colon}>:</Text>
          {seconds}
        </Text>
        <Text style={styles.timerStatus} accessibilityLiveRegion="polite">
          {completed
            ? 'Nicely done. Take a breath.'
            : running
              ? intention
              : remaining < duration * 60
                ? 'Paused. Pick it up when you are ready.'
                : 'Ready whenever you are.'}
        </Text>
        <View style={styles.track}>
          <View
            style={[styles.progress, { width: `${Math.max(0, Math.min(1, elapsed)) * 100}%` }]}
          />
        </View>
        <View style={styles.durations}>
          {durations.map((value) => (
            <Pressable
              key={value}
              accessibilityRole="button"
              accessibilityState={{ selected: duration === value }}
              accessibilityLabel={`${value} minute session`}
              onPress={() => selectDuration(value)}
              style={[styles.duration, duration === value && styles.durationSelected]}>
              <Text
                style={[styles.durationText, duration === value && styles.durationTextSelected]}>
                {value} min
              </Text>
            </Pressable>
          ))}
        </View>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={running ? 'Pause focus timer' : 'Start focus timer'}
          onPress={toggleTimer}
          style={({ pressed }) => [styles.primary, pressed && { opacity: 0.82 }]}>
          <Text style={styles.primaryText}>
            {running
              ? 'Pause session'
              : completed
                ? 'Start another session'
                : remaining < duration * 60
                  ? 'Resume session'
                  : 'Start focusing'}
          </Text>
          <Text style={styles.primaryText}>{running ? 'Ⅱ' : '→'}</Text>
        </Pressable>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel="Reset focus timer"
          onPress={() => selectDuration(duration)}
          style={styles.reset}>
          <Text style={styles.resetText}>Reset timer</Text>
        </Pressable>
      </View>

      <Text style={[styles.eyebrow, { marginTop: 32 }]}>WHAT IS THIS TIME FOR?</Text>
      <View style={styles.intentions}>
        {intentions.map((value, index) => (
          <Pressable
            key={value}
            accessibilityRole="button"
            accessibilityState={{ selected: intention === value }}
            onPress={() => setIntention(value)}
            style={styles.intention}>
            <Text style={styles.intentionNumber}>0{index + 1}</Text>
            <Text style={styles.intentionText}>{value}</Text>
            <View style={[styles.radio, intention === value && styles.radioSelected]}>
              {intention === value && <View style={styles.radioDot} />}
            </View>
          </Pressable>
        ))}
      </View>
      <Text style={styles.smallNote}>
        The timer keeps its place if you leave the app. Switching drafts starts a fresh session.
      </Text>
      <Text style={[styles.eyebrow, { marginTop: 32 }]}>RUNNING ON THIS DEVICE</Text>
      <View style={styles.details}>
        <Detail label="Source" value={Updates.isEmbeddedLaunch ? 'Native build' : 'EAS Update'} />
        <Detail label="Runtime" value={Updates.runtimeVersion || 'Unavailable in development'} />
        <Detail label="Update" value={Updates.updateId || 'Embedded'} />
      </View>
    </ScrollView>
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
  root: { flex: 1, backgroundColor: '#f4f0e8' },
  content: { paddingTop: 22, paddingHorizontal: 25, paddingBottom: 100 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 9, marginBottom: 43 },
  logo: {
    backgroundColor: '#272c25',
    width: 31,
    height: 31,
    borderRadius: 9,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoText: { color: '#f6f2e9', fontSize: 24, fontWeight: '800', marginTop: -3 },
  brand: { fontSize: 10, letterSpacing: 1.5, color: '#343a30', fontWeight: '700' },
  browse: { marginLeft: 'auto', paddingVertical: 10, paddingLeft: 12 },
  browseText: { fontSize: 12, fontWeight: '600', color: '#59604f' },
  eyebrow: {
    color: '#7d806f',
    fontSize: 10,
    fontWeight: '600',
    letterSpacing: 1.7,
    marginBottom: 15,
  },
  title: { color: '#282e26', fontSize: 43, lineHeight: 47, fontWeight: '600', letterSpacing: -1.7 },
  intro: {
    color: '#7b7c70',
    fontSize: 15,
    lineHeight: 23,
    maxWidth: 310,
    marginTop: 16,
    marginBottom: 28,
  },
  timerCard: {
    backgroundColor: '#fffdf7',
    borderRadius: 25,
    borderCurve: 'continuous',
    padding: 23,
    borderWidth: 1,
    borderColor: '#e5e0d4',
  },
  timerHeading: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  cardEyebrow: { color: '#8c8d7d', fontSize: 10, letterSpacing: 1.4 },
  indicator: { width: 7, height: 7, borderRadius: 4, backgroundColor: '#d7d9ca' },
  timer: {
    color: '#2a3027',
    fontSize: 76,
    fontWeight: '400',
    letterSpacing: -4,
    fontVariant: ['tabular-nums'],
    textAlign: 'center',
    marginTop: 29,
  },
  colon: { color: '#bac0ad' },
  timerStatus: { color: '#868977', fontSize: 12, textAlign: 'center', marginTop: 8, minHeight: 18 },
  track: {
    height: 4,
    borderRadius: 2,
    backgroundColor: '#eceee3',
    marginTop: 28,
    overflow: 'hidden',
  },
  progress: { height: '100%', backgroundColor: '#e8764f', borderRadius: 2 },
  durations: { flexDirection: 'row', gap: 8, marginTop: 23 },
  duration: {
    flex: 1,
    paddingVertical: 12,
    borderRadius: 11,
    backgroundColor: '#f4f3ed',
    alignItems: 'center',
  },
  durationSelected: { backgroundColor: '#e7ecdc' },
  durationText: { color: '#8a8e7d', fontSize: 13, fontWeight: '500' },
  durationTextSelected: { color: '#48583d' },
  primary: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    backgroundColor: '#df704b',
    paddingVertical: 18,
    paddingHorizontal: 20,
    borderRadius: 13,
    marginTop: 20,
  },
  primaryText: { color: '#fffaf2', fontSize: 15, fontWeight: '600' },
  reset: { minHeight: 44, alignItems: 'center', justifyContent: 'center', marginTop: 7 },
  resetText: { fontSize: 12, color: '#90927f' },
  intentions: { borderTopWidth: 1, borderColor: '#deded0' },
  intention: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    paddingVertical: 18,
    borderBottomWidth: 1,
    borderColor: '#deded0',
  },
  intentionNumber: { color: '#a1a28f', fontSize: 11, fontFamily: 'Menlo' },
  intentionText: { color: '#535b48', fontSize: 15 },
  radio: {
    width: 20,
    height: 20,
    borderRadius: 10,
    borderWidth: 1,
    borderColor: '#c9cdbd',
    marginLeft: 'auto',
    alignItems: 'center',
    justifyContent: 'center',
  },
  radioSelected: { borderColor: '#6d8056' },
  radioDot: { width: 10, height: 10, borderRadius: 5, backgroundColor: '#6d8056' },
  smallNote: { color: '#8d9080', fontSize: 11, lineHeight: 18, marginTop: 16 },
  details: {
    backgroundColor: '#eae9df',
    borderRadius: 15,
    paddingHorizontal: 16,
    paddingVertical: 3,
  },
  detail: { paddingVertical: 11, gap: 5 },
  detailLabel: { color: '#8a8e7d', fontSize: 10 },
  detailValue: { color: '#666f5b', fontFamily: 'Menlo', fontSize: 10 },
});
