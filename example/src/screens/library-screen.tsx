import { FieldGroup, Host, Icon, ListItem, Row, Text } from '@expo/ui';
import { router } from 'expo-router';
import { Stack } from 'expo-router/stack';

import { useLibrary } from '@/data/library-context';
import { preview, type Book } from '@/data/preview';

const sections = [
  { status: 'reading', title: 'Reading', icon: 'book.fill' },
  { status: 'later', title: 'Want to read', icon: 'bookmark' },
  { status: 'finished', title: 'Finished', icon: 'checkmark.circle' },
] as const;

function BookRow({ book, icon }: { book: Book; icon: (typeof sections)[number]['icon'] }) {
  return (
    <ListItem
      testID={`library-book-${book.id}`}
      onPress={() => router.push({ pathname: '/library/[id]', params: { id: book.id } })}
      leading={<Icon name={icon} size={20} />}
      supportingText={`${book.author}${book.favorite ? ' · Favorite' : ''}`}
      trailing={
        <Row alignment="center" spacing={8}>
          {book.status === 'reading' && <Text>{`${Math.round(book.progress * 100)}%`}</Text>}
          {book.favorite && <Icon name="star.fill" size={14} />}
          <Icon name="chevron.right" size={12} />
        </Row>
      }>
      {book.title}
    </ListItem>
  );
}

export default function LibraryScreen() {
  const { books, showFinished, favoritesOnly } = useLibrary();
  const visibleBooks = books.filter(
    (book) => (showFinished || book.status !== 'finished') && (!favoritesOnly || book.favorite)
  );

  return (
    <>
      <Stack.Title large>{preview.libraryTitle}</Stack.Title>
      <Host style={{ flex: 1 }} seedColor={preview.tint}>
        <FieldGroup testID="library-form">
          {sections.map(({ status, title, icon }) => {
            const sectionBooks = visibleBooks.filter((book) => book.status === status);
            if (sectionBooks.length === 0) return null;
            return (
              <FieldGroup.Section key={status} title={title}>
                {sectionBooks.map((book) => (
                  <BookRow key={book.id} book={book} icon={icon} />
                ))}
              </FieldGroup.Section>
            );
          })}
          {visibleBooks.length === 0 && (
            <FieldGroup.Section title="Your library">
              <Text>{favoritesOnly ? 'No favorites in this view.' : 'No books in this view.'}</Text>
              <FieldGroup.SectionFooter>
                <Text>Change your Library filters in Settings to see more books.</Text>
              </FieldGroup.SectionFooter>
            </FieldGroup.Section>
          )}
        </FieldGroup>
      </Host>
    </>
  );
}
