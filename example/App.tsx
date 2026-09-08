import { useState } from 'react';
import { Modal, Pressable, ScrollView, StatusBar, StyleSheet, Text, View } from 'react-native';
import * as Updates from 'expo-updates';
import { openDrafts } from 'expo-drafts';

const pieces = [
  {
    id: 'quiet',
    category: 'A slower pace',
    title: 'Leave a little\nroom in the day.',
    description: 'An afternoon with nothing planned.',
    color: '#e7eccf',
    paragraphs: [
      'On Tuesday I missed a train and sat on a bench for twenty minutes. The station had a small garden I had walked past for three years. Someone had planted rosemary beside the tracks.',
      'I started leaving those twenty minutes in the day on purpose. Sometimes I spend them walking. Sometimes I do the dishes slowly. Most days nothing remarkable happens, which is part of the point.',
    ],
  },
  {
    id: 'objects',
    category: 'Everyday design',
    title: 'The things\nwe keep.',
    description: 'A chipped cup, a good pen, and familiar objects.',
    color: '#efdcd0',
    paragraphs: [
      'My favorite cup has a chipped handle. It came from a shop that closed years ago, and it holds exactly the amount of coffee I want. Replacing it would be easy. Finding another one that feels right would take longer.',
      'We often judge objects when they are new. I am more interested in what happens after a thousand uses. The best ones get easier to hold, easier to trust, and harder to give away.',
    ],
  },
  {
    id: 'walk',
    category: 'Outside, again',
    title: 'Take the\nlong way home.',
    description: 'A neighborhood at walking speed.',
    color: '#d7e4e5',
    paragraphs: [
      'The short route home takes eleven minutes. The long one goes past a bakery, an unusually large chestnut tree, and a house with a bright blue door. It takes twenty-three.',
      'I used to save those twelve minutes without knowing what I was saving them for. Now I take the long route when I can. Last week the bakery put a chair outside. I sat down.',
    ],
  },
  {
    id: 'notebook',
    category: 'Small practices',
    title: 'Start on\nthe second page.',
    description: 'Finally using the nice notebook.',
    color: '#e7deec',
    paragraphs: [
      'I have a shelf of notebooks with one carefully written page. The first page always seemed to demand a plan for the whole book. A shopping list felt like a poor start.',
      'A friend told me to leave the first page blank. On the second page I wrote down a phone number. On the third I drew a bad picture of a chair. The notebook is nearly full now.',
    ],
  },
];
type Piece = (typeof pieces)[number];
type Filter = 'All' | 'Saved' | 'Read';

export default function App() {
  const [filter, setFilter] = useState<Filter>('All');
  const [saved, setSaved] = useState<string[]>(['quiet', 'walk']);
  const [read, setRead] = useState<string[]>([]);
  const [opened, setOpened] = useState<Piece | null>(null);
  const toggleSaved = (id: string) =>
    setSaved((items) =>
      items.includes(id) ? items.filter((item) => item !== id) : [...items, id]
    );
  const toggleRead = (id: string) =>
    setRead((items) => (items.includes(id) ? items.filter((item) => item !== id) : [...items, id]));
  const visiblePieces = pieces.filter(
    (piece) =>
      filter === 'All' || (filter === 'Saved' ? saved.includes(piece.id) : read.includes(piece.id))
  );
  return (
    <View style={styles.root}>
      <StatusBar barStyle="dark-content" />
      <ScrollView contentContainerStyle={styles.content}>
        <View style={styles.header}>
          <Text style={styles.wordmark}>margin.</Text>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel="Browse drafts"
            onPress={openDrafts}
            style={styles.browse}>
            <Text style={styles.browseText}>Browse drafts ↗</Text>
          </Pressable>
        </View>
        <View style={styles.kickerRow}>
          <View style={styles.dot} />
          <Text style={styles.kicker} testID="draft-variant">
            READING LIST
          </Text>
        </View>
        <Text style={styles.hero}>Good words.{'\n'}For later.</Text>
        <Text style={styles.intro}>
          A small collection for a quieter moment.{'\n'}Save a piece. Come back when you have time.
        </Text>
        <View style={styles.progressRow}>
          <Text style={styles.progressLabel}>
            {read.length} of {pieces.length} pieces read
          </Text>
          <View style={styles.progressTrack}>
            <View
              style={[styles.progressFill, { width: `${(read.length / pieces.length) * 100}%` }]}
            />
          </View>
        </View>
        <View style={styles.filters} accessibilityRole="tablist">
          {(['All', 'Saved', 'Read'] as const).map((item) => {
            const count =
              item === 'All' ? pieces.length : item === 'Saved' ? saved.length : read.length;
            return (
              <Pressable
                key={item}
                accessibilityRole="tab"
                accessibilityState={{ selected: filter === item }}
                accessibilityLabel={`${item}, ${count} pieces`}
                onPress={() => setFilter(item)}
                style={[styles.filter, filter === item && styles.filterSelected]}>
                <Text style={[styles.filterText, filter === item && styles.filterTextSelected]}>
                  {item}
                </Text>
                <Text style={[styles.filterCount, filter === item && styles.filterTextSelected]}>
                  {count}
                </Text>
              </Pressable>
            );
          })}
        </View>
        {visiblePieces.map((piece) => {
          const isSaved = saved.includes(piece.id);
          const isRead = read.includes(piece.id);
          return (
            <View key={piece.id} style={[styles.card, { backgroundColor: piece.color }]}>
              <View style={styles.cardTop}>
                <Text style={styles.category}>{piece.category.toUpperCase()}</Text>
                <Pressable
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: isSaved }}
                  accessibilityLabel={`${isSaved ? 'Unsave' : 'Save'} ${piece.title.replace('\n', ' ')}`}
                  onPress={() => toggleSaved(piece.id)}
                  style={[styles.saveButton, isSaved && styles.savedButton]}>
                  <Text style={[styles.saveText, isSaved && styles.savedText]}>
                    {isSaved ? '✓ Saved' : '+ Save'}
                  </Text>
                </Pressable>
              </View>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel={`Read ${piece.title.replace('\n', ' ')}`}
                onPress={() => setOpened(piece)}>
                <Text style={styles.pieceTitle}>{piece.title}</Text>
                <Text style={styles.description}>{piece.description}</Text>
              </Pressable>
              <View style={styles.cardBottom}>
                <Text style={styles.readTime}>FIELD NOTE · 1 MIN</Text>
                <Pressable
                  accessibilityRole="checkbox"
                  accessibilityState={{ checked: isRead }}
                  accessibilityLabel={`Mark ${piece.title.replace('\n', ' ')} as ${isRead ? 'unread' : 'read'}`}
                  onPress={() => toggleRead(piece.id)}
                  style={styles.readButton}>
                  <Text style={styles.readText}>{isRead ? '✓ Finished' : 'Mark as read'}</Text>
                </Pressable>
              </View>
            </View>
          );
        })}
        {visiblePieces.length === 0 && (
          <View style={styles.empty}>
            <Text style={styles.emptyTitle}>
              {filter === 'Saved' ? 'Keep something for later.' : 'Your first page awaits.'}
            </Text>
            <Text style={styles.emptyText}>
              {filter === 'Saved'
                ? 'Tap Save on any piece to find it here.'
                : 'Mark a piece as read and it will appear here.'}
            </Text>
            <Pressable
              accessibilityRole="button"
              onPress={() => setFilter('All')}
              style={styles.emptyButton}>
              <Text style={styles.browseText}>See all pieces →</Text>
            </Pressable>
          </View>
        )}
        <Text style={styles.deviceHeading}>RUNNING ON THIS DEVICE</Text>
        <View style={styles.details}>
          <Detail label="Source" value={Updates.isEmbeddedLaunch ? 'Native build' : 'EAS Update'} />
          <Detail label="Runtime" value={Updates.runtimeVersion || 'Unavailable in development'} />
          <Detail label="Update" value={Updates.updateId || 'Embedded'} />
        </View>
        <Text style={styles.footer}>
          Reading progress stays in this session. The floating drafts button can take you to another
          experiment.
        </Text>
      </ScrollView>
      <Modal
        visible={opened !== null}
        animationType="slide"
        presentationStyle="pageSheet"
        onRequestClose={() => setOpened(null)}>
        {opened && (
          <View style={styles.reader}>
            <View style={styles.readerHeader}>
              <Text style={styles.wordmark}>margin.</Text>
              <Pressable
                accessibilityRole="button"
                accessibilityLabel="Close article"
                onPress={() => setOpened(null)}
                style={styles.browse}>
                <Text style={styles.browseText}>Close ✕</Text>
              </Pressable>
            </View>
            <ScrollView contentContainerStyle={styles.readerContent}>
              <Text style={styles.category}>{opened.category.toUpperCase()}</Text>
              <Text style={styles.readerTitle}>{opened.title}</Text>
              {opened.paragraphs.map((paragraph) => (
                <Text key={paragraph} style={styles.paragraph}>
                  {paragraph}
                </Text>
              ))}
              <Text style={styles.endMark}>●</Text>
              <Pressable
                accessibilityRole="button"
                onPress={() => {
                  setRead((items) => (items.includes(opened.id) ? items : [...items, opened.id]));
                  setOpened(null);
                }}
                style={styles.finishButton}>
                <Text style={styles.finishText}>Finished reading ✓</Text>
              </Pressable>
            </ScrollView>
          </View>
        )}
      </Modal>
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
  root: { flex: 1, backgroundColor: '#f6f3eb' },
  content: { paddingTop: 74, paddingHorizontal: 24, paddingBottom: 116 },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 46,
  },
  wordmark: {
    color: '#2a322b',
    fontFamily: 'Georgia',
    fontSize: 29,
    letterSpacing: -1.4,
    fontWeight: '700',
  },
  browse: {
    minHeight: 44,
    paddingHorizontal: 14,
    justifyContent: 'center',
    borderWidth: 1,
    borderColor: '#c8cdc1',
    borderRadius: 24,
  },
  browseText: { color: '#3e4b3c', fontSize: 12, fontWeight: '600' },
  kickerRow: { flexDirection: 'row', alignItems: 'center', gap: 8, marginBottom: 16 },
  dot: { width: 6, height: 6, borderRadius: 3, backgroundColor: '#63794e' },
  kicker: { fontSize: 10, color: '#63704e', letterSpacing: 2, fontWeight: '600' },
  hero: {
    fontFamily: 'Georgia',
    fontSize: 53,
    lineHeight: 59,
    color: '#283429',
    letterSpacing: -2,
  },
  intro: { fontSize: 14, color: '#727768', lineHeight: 22, marginTop: 20 },
  progressRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 16,
    marginTop: 27,
    marginBottom: 28,
  },
  progressLabel: { fontSize: 11, color: '#6a765f' },
  progressTrack: {
    width: 87,
    height: 4,
    borderRadius: 2,
    backgroundColor: '#dce0d2',
    overflow: 'hidden',
  },
  progressFill: { height: 4, backgroundColor: '#667c50', borderRadius: 2 },
  filters: {
    flexDirection: 'row',
    gap: 5,
    marginBottom: 19,
    borderTopWidth: 1,
    borderColor: '#dedfd4',
    paddingTop: 20,
  },
  filter: {
    minHeight: 44,
    paddingHorizontal: 16,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 9,
    borderRadius: 24,
  },
  filterSelected: { backgroundColor: '#2e4032' },
  filterText: { fontSize: 13, color: '#677160', fontWeight: '600' },
  filterCount: { fontSize: 11, color: '#839076', fontVariant: ['tabular-nums'] },
  filterTextSelected: { color: '#f6f7ee' },
  card: { borderRadius: 20, padding: 20, marginBottom: 15 },
  cardTop: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', gap: 8 },
  category: { color: '#596249', fontSize: 9, letterSpacing: 1.25, fontWeight: '700' },
  saveButton: {
    minHeight: 44,
    paddingHorizontal: 12,
    borderRadius: 24,
    justifyContent: 'center',
    backgroundColor: '#ffffff55',
  },
  savedButton: { backgroundColor: '#3f533b' },
  saveText: { fontSize: 11, fontWeight: '600', color: '#40523b' },
  savedText: { color: '#f4f5ea' },
  pieceTitle: {
    fontFamily: 'Georgia',
    fontSize: 33,
    lineHeight: 38,
    letterSpacing: -0.8,
    color: '#303a2f',
    marginTop: 13,
  },
  description: { color: '#66705e', fontSize: 12, lineHeight: 19, marginTop: 11, maxWidth: 255 },
  cardBottom: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginTop: 17,
    borderTopWidth: 1,
    borderColor: '#46544020',
    paddingTop: 8,
  },
  readTime: { color: '#77806d', fontSize: 8, letterSpacing: 0.8 },
  readButton: { minHeight: 44, justifyContent: 'center', paddingHorizontal: 7 },
  readText: { color: '#435d3c', fontSize: 11, fontWeight: '600' },
  empty: {
    borderWidth: 1,
    borderStyle: 'dashed',
    borderColor: '#c9cebc',
    borderRadius: 20,
    padding: 25,
    minHeight: 185,
  },
  emptyTitle: { fontFamily: 'Georgia', fontSize: 25, lineHeight: 30, color: '#364532' },
  emptyText: { fontSize: 13, color: '#707964', lineHeight: 21, marginTop: 10 },
  emptyButton: { alignSelf: 'flex-start', minHeight: 44, justifyContent: 'center', marginTop: 12 },
  deviceHeading: {
    fontSize: 9,
    letterSpacing: 1.5,
    color: '#89907d',
    fontWeight: '600',
    marginTop: 35,
    marginBottom: 14,
  },
  details: {
    backgroundColor: '#ebece2',
    borderRadius: 16,
    paddingHorizontal: 16,
    paddingVertical: 6,
  },
  detail: { paddingVertical: 10, gap: 4 },
  detailLabel: { color: '#818a75', fontSize: 10 },
  detailValue: { color: '#56624a', fontSize: 9, fontFamily: 'Menlo' },
  footer: { color: '#8b937f', fontSize: 11, lineHeight: 18, marginTop: 18, maxWidth: 290 },
  reader: { flex: 1, backgroundColor: '#f6f3eb' },
  readerHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingHorizontal: 24,
    paddingTop: 25,
    paddingBottom: 24,
    borderBottomWidth: 1,
    borderColor: '#e0e3d7',
  },
  readerContent: { paddingHorizontal: 28, paddingTop: 35, paddingBottom: 100 },
  readerTitle: {
    fontFamily: 'Georgia',
    fontSize: 44,
    lineHeight: 49,
    color: '#2c3b2c',
    marginTop: 22,
    marginBottom: 30,
    letterSpacing: -1.5,
  },
  paragraph: {
    color: '#59634e',
    fontFamily: 'Georgia',
    fontSize: 18,
    lineHeight: 31,
    marginBottom: 24,
  },
  endMark: { fontSize: 10, color: '#748064', marginBottom: 34 },
  finishButton: {
    minHeight: 54,
    borderRadius: 18,
    backgroundColor: '#314932',
    alignItems: 'center',
    justifyContent: 'center',
  },
  finishText: { fontSize: 14, color: '#f5f7e9', fontWeight: '600' },
});
