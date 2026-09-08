import { useState } from 'react';
import { Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from 'react-native';
import * as Updates from 'expo-updates';
import { openDrafts } from 'expo-drafts';

const palettes = [
  {
    name: 'Moonflower',
    mood: 'Quietly unexpected',
    colors: ['#C3B2EE', '#F0DFCD', '#443A5C', '#D7DD9A'],
    ink: '#443A5C',
    paper: '#F0DFCD',
  },
  {
    name: 'Apricot hour',
    mood: 'A little more sunshine',
    colors: ['#F4A881', '#F5EDDA', '#8C534A', '#CFD8B4'],
    ink: '#8C534A',
    paper: '#F5EDDA',
  },
  {
    name: 'Deep water',
    mood: 'Clear a little space',
    colors: ['#79BBC2', '#DDE8E0', '#254A59', '#DEBE87'],
    ink: '#254A59',
    paper: '#DDE8E0',
  },
];

export default function App() {
  const [paletteIndex, setPaletteIndex] = useState(0);
  const [swatchIndex, setSwatchIndex] = useState(0);
  const [saved, setSaved] = useState<number[]>([]);
  const palette = palettes[paletteIndex];
  const selected = palette.colors[swatchIndex];
  const isSaved = saved.includes(paletteIndex);

  function choosePalette(index: number) {
    setPaletteIndex(index);
    setSwatchIndex(0);
  }

  function toggleSaved() {
    setSaved((current) =>
      current.includes(paletteIndex)
        ? current.filter((value) => value !== paletteIndex)
        : [...current, paletteIndex]
    );
  }

  return (
    <ScrollView
      style={styles.root}
      contentInsetAdjustmentBehavior="automatic"
      contentContainerStyle={styles.content}>
      <StatusBar barStyle="light-content" />
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
      <View style={styles.headingLine}>
        <Text style={styles.eyebrow} testID="draft-variant">
          COLOR STUDIO / EXPERIMENT 03
        </Text>
        <Text style={styles.collectionCount}>{saved.length} saved</Text>
      </View>
      <Text style={styles.title}>Play with{'\n'}possibility.</Text>
      <Text style={styles.intro}>Three palettes, plenty of room to make them your own.</Text>

      <View style={[styles.canvas, { backgroundColor: palette.paper }]}>
        <View style={styles.canvasHeader}>
          <Text style={[styles.canvasNumber, { color: palette.ink }]}>
            STUDY 0{paletteIndex + 1}
          </Text>
          <Text style={[styles.canvasNumber, { color: palette.ink }]}>↗</Text>
        </View>
        <View
          style={styles.artwork}
          accessible
          accessibilityLabel={`${palette.name} abstract color composition`}>
          <View style={[styles.largeShape, { backgroundColor: palette.ink }]} />
          <View style={[styles.smallShape, { backgroundColor: selected }]} />
          <View style={[styles.lineShape, { borderColor: palette.ink }]} />
        </View>
        <View style={styles.canvasFooter}>
          <View>
            <Text style={[styles.paletteName, { color: palette.ink }]}>{palette.name}</Text>
            <Text style={[styles.paletteMood, { color: palette.ink }]}>{palette.mood}</Text>
          </View>
          <Text style={[styles.paletteNumber, { color: palette.ink }]}>0{paletteIndex + 1}</Text>
        </View>
      </View>
      <View style={styles.swatchHeader}>
        <Text style={styles.sectionLabel}>TAP A COLOR TO TRY IT</Text>
        <Text selectable style={styles.selectedHex}>
          {selected}
        </Text>
      </View>
      <View style={styles.swatches}>
        {palette.colors.map((color, index) => (
          <Pressable
            key={color}
            accessibilityRole="button"
            accessibilityLabel={`Select ${color}`}
            accessibilityState={{ selected: swatchIndex === index }}
            onPress={() => setSwatchIndex(index)}
            style={[styles.swatchFrame, swatchIndex === index && { borderColor: '#f2eee8' }]}>
            <View style={[styles.swatch, { backgroundColor: color }]} />
          </Pressable>
        ))}
      </View>
      <Pressable
        accessibilityRole="button"
        accessibilityLabel={
          isSaved ? `Remove ${palette.name} from saved palettes` : `Save ${palette.name} palette`
        }
        accessibilityState={{ selected: isSaved }}
        onPress={toggleSaved}
        style={({ pressed }) => [
          styles.saveButton,
          isSaved && styles.savedButton,
          pressed && { opacity: 0.8 },
        ]}>
        <Text style={[styles.saveText, isSaved && styles.savedText]}>
          {isSaved ? 'Saved to your collection' : 'Save this palette'}
        </Text>
        <Text style={[styles.saveIcon, isSaved && styles.savedText]}>{isSaved ? '✓' : '+'}</Text>
      </Pressable>

      <Text style={[styles.sectionLabel, { marginTop: 34, marginBottom: 15 }]}>
        EXPLORE THE COLLECTION
      </Text>
      {palettes.map((item, index) => (
        <Pressable
          key={item.name}
          accessibilityRole="button"
          accessibilityLabel={`Choose ${item.name} palette`}
          accessibilityState={{ selected: paletteIndex === index }}
          onPress={() => choosePalette(index)}
          style={[styles.paletteRow, paletteIndex === index && styles.paletteRowActive]}>
          <View style={styles.miniColors}>
            {item.colors.slice(0, 3).map((color, colorIndex) => (
              <View
                key={color}
                style={[
                  styles.miniColor,
                  { backgroundColor: color, marginLeft: colorIndex === 0 ? 0 : -10 },
                ]}
              />
            ))}
          </View>
          <View style={styles.rowText}>
            <Text style={styles.rowName}>{item.name}</Text>
            <Text style={styles.rowMood}>{item.mood}</Text>
          </View>
          <Text style={styles.rowArrow}>{paletteIndex === index ? '●' : '↗'}</Text>
        </Pressable>
      ))}
      <Text style={styles.note}>
        Your collection stays here while you explore this draft. The floating button opens another
        experiment.
      </Text>
      <Text style={[styles.sectionLabel, { marginTop: 30, marginBottom: 14 }]}>
        RUNNING ON THIS DEVICE
      </Text>
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
  root: { flex: 1, backgroundColor: '#1b1921' },
  content: { paddingTop: 22, paddingHorizontal: 24, paddingBottom: 100 },
  header: { flexDirection: 'row', alignItems: 'center', gap: 9, marginBottom: 43 },
  logo: {
    width: 31,
    height: 31,
    borderRadius: 9,
    backgroundColor: '#c3b2ee',
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoText: { color: '#30273f', fontSize: 24, fontWeight: '800', marginTop: -3 },
  brand: { color: '#e5dff0', fontSize: 10, fontWeight: '700', letterSpacing: 1.5 },
  browse: { marginLeft: 'auto', paddingVertical: 10, paddingLeft: 12 },
  browseText: { color: '#b8adcd', fontSize: 12, fontWeight: '600' },
  headingLine: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: 17,
  },
  eyebrow: { color: '#a695bd', fontSize: 9, letterSpacing: 1.3, fontWeight: '500' },
  collectionCount: { color: '#9f91b3', fontSize: 10 },
  title: { color: '#f1eaf6', fontSize: 49, lineHeight: 52, letterSpacing: -2, fontWeight: '500' },
  intro: {
    color: '#9c91aa',
    fontSize: 15,
    lineHeight: 23,
    maxWidth: 290,
    marginTop: 17,
    marginBottom: 27,
  },
  canvas: { borderRadius: 22, borderCurve: 'continuous', padding: 21, overflow: 'hidden' },
  canvasHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  canvasNumber: { fontFamily: 'Menlo', fontSize: 10, letterSpacing: 1.5 },
  artwork: { height: 173, alignItems: 'center', justifyContent: 'center', marginVertical: 12 },
  largeShape: {
    position: 'absolute',
    width: 133,
    height: 143,
    borderTopLeftRadius: 70,
    borderTopRightRadius: 70,
    borderBottomRightRadius: 20,
    borderBottomLeftRadius: 20,
    transform: [{ rotate: '-15deg' }],
    marginLeft: -47,
  },
  smallShape: {
    position: 'absolute',
    width: 115,
    height: 115,
    borderRadius: 58,
    marginLeft: 70,
    marginTop: 25,
  },
  lineShape: {
    position: 'absolute',
    width: 161,
    height: 75,
    borderRadius: 50,
    borderWidth: 1,
    transform: [{ rotate: '-32deg' }],
    marginLeft: 49,
    marginTop: -9,
  },
  canvasFooter: {
    flexDirection: 'row',
    alignItems: 'flex-end',
    justifyContent: 'space-between',
    marginTop: 8,
  },
  paletteName: { fontSize: 24, letterSpacing: -0.5, fontWeight: '600' },
  paletteMood: { fontSize: 11, marginTop: 5, opacity: 0.7 },
  paletteNumber: { fontSize: 33, fontWeight: '300', opacity: 0.4 },
  swatchHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 23,
    marginBottom: 13,
  },
  sectionLabel: { color: '#9786ac', fontSize: 9, letterSpacing: 1.45, fontWeight: '500' },
  selectedHex: { color: '#c8bbd7', fontFamily: 'Menlo', fontSize: 11 },
  swatches: { flexDirection: 'row', gap: 9 },
  swatchFrame: {
    flex: 1,
    padding: 4,
    borderRadius: 13,
    borderWidth: 1,
    borderColor: 'transparent',
  },
  swatch: { height: 49, borderRadius: 9 },
  saveButton: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#c3b2ee',
    paddingHorizontal: 18,
    paddingVertical: 17,
    marginTop: 19,
    borderRadius: 13,
  },
  savedButton: { backgroundColor: '#342e40' },
  saveText: { color: '#30273f', fontSize: 14, fontWeight: '600' },
  saveIcon: { color: '#30273f', fontSize: 21 },
  savedText: { color: '#cabbdf' },
  paletteRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: 15,
    borderRadius: 15,
    marginBottom: 9,
    borderWidth: 1,
    borderColor: '#302a38',
  },
  paletteRowActive: { backgroundColor: '#26212e', borderColor: '#5e4e72' },
  miniColors: { flexDirection: 'row', alignItems: 'center', paddingRight: 15 },
  miniColor: { width: 24, height: 33, borderRadius: 7, borderWidth: 1, borderColor: '#1b1921' },
  rowText: { flex: 1 },
  rowName: { color: '#e0d6ea', fontSize: 14, fontWeight: '500' },
  rowMood: { color: '#8f819f', fontSize: 10, marginTop: 5 },
  rowArrow: { color: '#a797bb', fontSize: 14, marginLeft: 8 },
  note: { color: '#8f809f', fontSize: 11, lineHeight: 18, marginTop: 13, maxWidth: 300 },
  details: {
    backgroundColor: '#25212d',
    borderRadius: 14,
    paddingHorizontal: 16,
    paddingVertical: 3,
  },
  detail: { paddingVertical: 11, gap: 5 },
  detailLabel: { color: '#94849f', fontSize: 10 },
  detailValue: { color: '#b6a7c4', fontFamily: 'Menlo', fontSize: 10 },
});
