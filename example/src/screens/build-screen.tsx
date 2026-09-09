import { FieldGroup, Host, Row, Spacer, Text } from '@expo/ui';
import { font, textSelection } from '@expo/ui/swift-ui/modifiers';
import * as Updates from 'expo-updates';

import { preview } from '@/data/preview';

export default function BuildScreen() {
  return (
    <Host style={{ flex: 1 }} seedColor={preview.tint}>
      <FieldGroup testID="build-details-form">
        <FieldGroup.Section title="Running">
          <Row alignment="center">
            <Text>Preview</Text>
            <Spacer />
            <Text>{preview.name}</Text>
          </Row>
          <Row alignment="center" testID="bundle-source">
            <Text>Source</Text>
            <Spacer />
            <Text>{Updates.isEmbeddedLaunch ? 'Bundled in this build' : 'EAS Update'}</Text>
          </Row>
        </FieldGroup.Section>
        <FieldGroup.Section title="Update ID">
          <Text
            modifiers={[font({ textStyle: 'footnote', design: 'monospaced' }), textSelection(true)]}
            testID="bundle-id">
            {Updates.updateId ?? 'Unavailable'}
          </Text>
        </FieldGroup.Section>
        <FieldGroup.Section title="Native runtime">
          <Text
            modifiers={[font({ textStyle: 'footnote', design: 'monospaced' }), textSelection(true)]}
            testID="native-runtime">
            {Updates.runtimeVersion ?? 'Unavailable'}
          </Text>
          <FieldGroup.SectionFooter>
            <Text>Drafts can run on this build when their native runtime matches.</Text>
          </FieldGroup.SectionFooter>
        </FieldGroup.Section>
      </FieldGroup>
    </Host>
  );
}
