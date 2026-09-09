import {
  createContext,
  use,
  useCallback,
  useMemo,
  useState,
  type Dispatch,
  type ReactNode,
  type SetStateAction,
} from 'react';

import { preview, type Book } from '@/data/preview';

type LibraryState = {
  books: Book[];
  updateBook: (id: string, changes: Partial<Book>) => void;
  showFinished: boolean;
  setShowFinished: Dispatch<SetStateAction<boolean>>;
  favoritesOnly: boolean;
  setFavoritesOnly: Dispatch<SetStateAction<boolean>>;
};

const LibraryContext = createContext<LibraryState | null>(null);

export function LibraryProvider({ children }: { children: ReactNode }) {
  const [books, setBooks] = useState<Book[]>(() => preview.books.map((book) => ({ ...book })));
  const [showFinished, setShowFinished] = useState(true);
  const [favoritesOnly, setFavoritesOnly] = useState(false);

  const updateBook = useCallback((id: string, changes: Partial<Book>) => {
    setBooks((current) =>
      current.map((book) => {
        if (book.id !== id) return book;
        const progress =
          changes.progress !== undefined && Number.isFinite(changes.progress)
            ? Math.min(1, Math.max(0, changes.progress))
            : book.progress;
        return { ...book, ...changes, id: book.id, progress };
      })
    );
  }, []);

  const value = useMemo(
    () => ({
      books,
      updateBook,
      showFinished,
      setShowFinished,
      favoritesOnly,
      setFavoritesOnly,
    }),
    [books, updateBook, showFinished, favoritesOnly]
  );

  return <LibraryContext value={value}>{children}</LibraryContext>;
}

export function useLibrary() {
  const value = use(LibraryContext);
  if (!value) throw new Error('useLibrary must be used inside LibraryProvider.');
  return value;
}
