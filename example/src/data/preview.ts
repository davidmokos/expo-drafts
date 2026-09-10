export type Book = {
  id: string;
  title: string;
  author: string;
  blurb: string;
  status: 'later' | 'reading' | 'finished';
  progress: number;
  favorite: boolean;
};

export type Preview = {
  name: string;
  initialRoute: '/library' | '/focus' | '/studio';
  tint: string;
  libraryTitle: string;
  books: Book[];
  focusTitle: string;
  focusMinutes: number;
  breakMinutes: number;
  studioTitle: string;
  palette: string;
  colorHex: string;
};

export const preview: Preview = {
  name: 'Reading List',
  initialRoute: '/library',
  tint: '#34C759',
  libraryTitle: 'Reading List',
  books: [
    {
      id: 'atomic-habits',
      title: 'Atomic Habits',
      author: 'James Clear',
      blurb: 'Small routines that become easier to keep with each repetition.',
      status: 'reading',
      progress: 0.4,
      favorite: true,
    },
    {
      id: 'deep-work',
      title: 'Deep Work',
      author: 'Cal Newport',
      blurb: 'Making room for focused work in a day full of interruptions.',
      status: 'later',
      progress: 0,
      favorite: true,
    },
    {
      id: 'a-walk-in-the-woods',
      title: 'A Walk in the Woods',
      author: 'Bill Bryson',
      blurb: 'A long walk, unexpected company, and a reason to head outside.',
      status: 'finished',
      progress: 1,
      favorite: false,
    },
  ],
  focusTitle: 'Focus',
  focusMinutes: 25,
  breakMinutes: 5,
  studioTitle: 'Studio',
  palette: 'Ocean',
  colorHex: '#007AFF',
};
