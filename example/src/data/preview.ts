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
  name: 'PR Workflow',
  initialRoute: '/library',
  tint: '#AF52DE',
  libraryTitle: 'PR Library',
  books: [
    {
      id: 'creative-act',
      title: 'The Creative Act',
      author: 'Rick Rubin',
      blurb: 'Making space for curiosity, attention, and a creative practice.',
      status: 'reading',
      progress: 0.35,
      favorite: true,
    },
    {
      id: 'design-everyday',
      title: 'The Design of Everyday Things',
      author: 'Don Norman',
      blurb: 'A closer look at the objects we use and the choices behind them.',
      status: 'later',
      progress: 0,
      favorite: false,
    },
    {
      id: 'four-thousand',
      title: 'Four Thousand Weeks',
      author: 'Oliver Burkeman',
      blurb: 'Choosing what matters when there is never time for everything.',
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
