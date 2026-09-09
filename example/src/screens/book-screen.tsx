import { Button, FieldGroup, Host, Picker, Row, Slider, Spacer, Switch, Text } from '@expo/ui';
import { router, useLocalSearchParams } from 'expo-router';
import { Stack } from 'expo-router/stack';

import { useLibrary } from '@/data/library-context';
import { preview, type Book } from '@/data/preview';

export default function BookScreen() {
  const { id } = useLocalSearchParams<{ id: string }>();
  const { books, updateBook } = useLibrary();
  const book = books.find((item) => item.id === id);

  if (!book) {
    return (
      <>
        <Stack.Title>Book</Stack.Title>
        <Host style={{ flex: 1 }} seedColor={preview.tint}>
          <FieldGroup>
            <FieldGroup.Section>
              <Text>This book is no longer in your library.</Text>
              <Button
                label="Back to library"
                variant="text"
                onPress={() => router.replace('/library')}
              />
            </FieldGroup.Section>
          </FieldGroup>
        </Host>
      </>
    );
  }

  const changeStatus = (status: Book['status']) => {
    const progress =
      status === 'finished' ? 1 : status === 'later' ? 0 : book.progress === 1 ? 0 : book.progress;
    updateBook(book.id, { status, progress });
  };
  const changeProgress = (progress: number) => {
    updateBook(book.id, {
      progress,
      status: progress >= 1 ? 'finished' : progress > 0 ? 'reading' : 'later',
    });
  };

  return (
    <>
      <Stack.Title>{book.title}</Stack.Title>
      <Host style={{ flex: 1 }} seedColor={preview.tint}>
        <FieldGroup testID="book-form">
          <FieldGroup.Section title="About this book">
            <Text>{`By ${book.author}`}</Text>
            <Text>{book.blurb}</Text>
          </FieldGroup.Section>
          <FieldGroup.Section title="Reading">
            <Row alignment="center">
              <Text>Status</Text>
              <Spacer />
              <Picker<Book['status']>
                testID="book-status"
                selectedValue={book.status}
                onValueChange={changeStatus}>
                <Picker.Item label="Want to read" value="later" />
                <Picker.Item label="Reading" value="reading" />
                <Picker.Item label="Finished" value="finished" />
              </Picker>
            </Row>
            <Row alignment="center">
              <Text>Progress</Text>
              <Spacer />
              <Text>{`${Math.round(book.progress * 100)}%`}</Text>
            </Row>
            <Slider
              testID="book-progress"
              value={book.progress}
              min={0}
              max={1}
              step={0.01}
              onValueChange={changeProgress}
            />
          </FieldGroup.Section>
          <FieldGroup.Section title="Your library">
            <Switch
              testID="book-favorite"
              label="Favorite"
              value={book.favorite}
              onValueChange={(favorite) => updateBook(book.id, { favorite })}
            />
            <Button
              testID="book-mark-finished"
              label="Mark as finished"
              variant="text"
              disabled={book.status === 'finished'}
              onPress={() => changeStatus('finished')}
            />
          </FieldGroup.Section>
        </FieldGroup>
      </Host>
    </>
  );
}
