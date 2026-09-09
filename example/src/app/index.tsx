import { Redirect } from 'expo-router';
import { preview } from '@/data/preview';

export default function Index() {
  return <Redirect href={preview.initialRoute} />;
}
