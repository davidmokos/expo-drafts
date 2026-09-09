import { FieldGroup, Host, Icon, ListItem, Row, Spacer, Switch, Text } from '@expo/ui';
import { openDrafts } from 'expo-drafts';
import { router } from 'expo-router';
import { Alert } from 'react-native';

import { useLibrary } from '@/data/library-context';
import { preview } from '@/data/preview';

export default function SettingsScreen() {
  const { showFinished, setShowFinished, favoritesOnly, setFavoritesOnly } = useLibrary();

  function browseDrafts() {
    openDrafts().catch((error: unknown) => {
      Alert.alert(
        'Could not open drafts',
        error instanceof Error ? error.message : 'Please try again.'
      );
    });
  }

  return (
    <Host style={{ flex: 1 }} seedColor={preview.tint}>
      <FieldGroup testID="settings-form">
        <FieldGroup.Section title="Preview">
          <Row alignment="center" spacing={12} testID="preview-name">
            <Icon name="app.dashed" />
            <Text>Current preview</Text>
            <Spacer />
            <Text>{preview.name}</Text>
          </Row>
          <ListItem
            onPress={browseDrafts}
            leading={<Icon name="square.stack.3d.up" />}
            trailing={<Icon name="chevron.right" />}
            testID="browse-drafts">
            <Text>Browse drafts</Text>
          </ListItem>
          <ListItem
            onPress={() => router.push('/settings/build')}
            leading={<Icon name="info.circle" />}
            trailing={<Icon name="chevron.right" />}
            testID="build-details">
            <Text>Build details</Text>
          </ListItem>
        </FieldGroup.Section>
        <FieldGroup.Section title="Library">
          <Switch
            label="Show finished books"
            value={showFinished}
            onValueChange={setShowFinished}
            testID="show-finished"
          />
          <Switch
            label="Favorites only"
            value={favoritesOnly}
            onValueChange={setFavoritesOnly}
            testID="favorites-only"
          />
          <FieldGroup.SectionFooter>
            <Text>These filters apply to your Library tab.</Text>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
      </FieldGroup>
    </Host>
  );
}
